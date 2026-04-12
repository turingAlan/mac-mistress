import Cocoa
import IOKit.ps
import IOKit.pwr_mgt

class SystemEventMonitor {
    private let soundManager: SoundManager
    private var powerSourceTimer: Timer?
    private var wasCharging = false
    private var wasFull = false
    private var wasLowBattery = false
    private var screenLockObservers: [NSObjectProtocol] = []
    private var powerObservers: [NSObjectProtocol] = []
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var lastWakeTime: Date = .distantPast

    init(soundManager: SoundManager) {
        self.soundManager = soundManager
    }

    func startMonitoring() {
        disableDefaultChargingSound()
        monitorPowerSource()
        monitorLidState()
        monitorScreenLock()
        monitorSystemPower()

        // Play startup sound
        soundManager.play(event: .startup)
    }

    func stopMonitoring() {
        powerSourceTimer?.invalidate()
        powerSourceTimer = nil

        // Remove IOKit power source callback
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSourceRunLoopSource = nil
        }

        for observer in screenLockObservers + powerObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        screenLockObservers.removeAll()
        powerObservers.removeAll()
    }

    // MARK: - Disable default macOS charging chime

    private func disableDefaultChargingSound() {
        // Disable the built-in PowerChime (the "bong" when you plug in charger)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.apple.PowerChime", "ChimeOnAllHardware", "-bool", "false"]
        try? process.run()
        process.waitUntilExit()

        let process2 = Process()
        process2.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process2.arguments = ["write", "com.apple.PowerChime", "ChimeOnNoHardware", "-bool", "true"]
        try? process2.run()
        process2.waitUntilExit()

        // Kill PowerChime process so it picks up the new setting
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killProcess.arguments = ["PowerChime"]
        try? killProcess.run()
        killProcess.waitUntilExit()

        NSLog("MacMistress: Default macOS charging chime disabled")
    }

    // MARK: - Power/Charging monitoring (instant via IOKit callback + fast poll fallback)

    private func monitorPowerSource() {
        // Initialize current state
        let info = getBatteryInfo()
        wasCharging = info.isCharging
        wasFull = info.percentage >= SoundSettings.shared.maxChargeThreshold
        wasLowBattery = info.percentage <= SoundSettings.shared.lowBatteryThreshold

        // Use IOKit power source notification for instant detection
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let monitor = Unmanaged<SystemEventMonitor>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.checkPowerSource()
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSourceRunLoopSource = source
            NSLog("MacMistress: Registered instant power source callback")
        }

        // Also keep a 30s fallback poll for battery level changes (low/full)
        powerSourceTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkPowerSource()
        }
    }

    private func checkPowerSource() {
        let info = getBatteryInfo()
        let lowThreshold = SoundSettings.shared.lowBatteryThreshold
        let maxThreshold = SoundSettings.shared.maxChargeThreshold

        // Charging start
        if info.isCharging && !wasCharging {
            soundManager.play(event: .chargingStart)
        }

        // Discharging (charger unplugged)
        if !info.isCharging && wasCharging {
            soundManager.play(event: .discharging)
        }

        // Full charge (triggered at max charge threshold)
        if info.percentage >= maxThreshold && !wasFull {
            soundManager.play(event: .fullCharge)
        }

        // Low battery
        if info.percentage <= lowThreshold && !wasLowBattery && !info.isCharging {
            soundManager.play(event: .lowBattery)
        }

        wasCharging = info.isCharging
        wasFull = info.percentage >= maxThreshold
        wasLowBattery = info.percentage <= lowThreshold
    }

    private func getBatteryInfo() -> (isCharging: Bool, percentage: Int) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first as CFTypeRef)?.takeUnretainedValue() as? [String: Any] else {
            return (false, 100)
        }

        let isCharging = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let percentage = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
        return (isCharging, percentage)
    }

    // MARK: - Lid open/close monitoring (via sleep/wake + display notifications)

    private func monitorLidState() {
        let wsnc = NSWorkspace.shared.notificationCenter

        // didWake = lid opening (or manual wake)
        // Must delay playback to let audio hardware reinitialize after sleep
        let wakeObs = wsnc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            NSLog("MacMistress: System woke up (lid open)")
            self?.lastWakeTime = Date()
            self?.soundManager.playDelayed(event: .lidOpen, delay: 0.5)
        }

        // screensDidWake as backup — fires when display powers on
        let screenWakeObs = wsnc.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { _ in
            NSLog("MacMistress: Screens did wake")
        }

        powerObservers.append(contentsOf: [wakeObs, screenWakeObs])
    }

    // MARK: - Screen lock/unlock monitoring

    private func monitorScreenLock() {
        let dnc = DistributedNotificationCenter.default()

        let lockObs = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.soundManager.play(event: .lockScreen)
        }

        let unlockObs = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Skip unlock sound if it's triggered by lid open (within 5s of wake)
            if Date().timeIntervalSince(self.lastWakeTime) < 5.0 {
                NSLog("MacMistress: Suppressing unlock sound (lid open already played)")
                return
            }
            self.soundManager.play(event: .unlockScreen)
        }

        screenLockObservers = [lockObs, unlockObs]
    }

    // MARK: - System power events (shutdown, restart)

    private func monitorSystemPower() {
        let wsnc = NSWorkspace.shared.notificationCenter

        let shutdownObs = wsnc.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.soundManager.play(event: .shutdown)
        }

        powerObservers.append(shutdownObs)
    }
}
