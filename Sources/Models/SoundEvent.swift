import Foundation

/// All sound event types the app can handle
enum SoundEvent: String, CaseIterable, Identifiable, Codable {
    case chargingStart = "Charging Start"
    case discharging = "Discharging"
    case fullCharge = "Full Charge"
    case lowBattery = "Low Battery"
    case lidOpen = "Lid Open"
    case lockScreen = "Lock Screen"
    case unlockScreen = "Unlock Screen"
    case startup = "Startup"
    case shutdown = "Shutdown"
    case restart = "Restart"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .chargingStart: return "Plays when charger is plugged in"
        case .discharging: return "Plays when charger is unplugged"
        case .fullCharge: return "Plays when battery reaches 100%"
        case .lowBattery: return "Plays when battery drops below threshold"
        case .lidOpen: return "Plays when lid is opened / wake from sleep"
        case .lockScreen: return "Plays when screen is locked"
        case .unlockScreen: return "Plays when screen is unlocked"
        case .startup: return "Plays when app starts"
        case .shutdown: return "Plays when system shuts down"
        case .restart: return "Plays when system restarts"
        }
    }

    var defaultSystemSound: String {
        switch self {
        case .chargingStart: return "/System/Library/Sounds/Funk.aiff"
        case .discharging: return "/System/Library/Sounds/Bottle.aiff"
        case .fullCharge: return "/System/Library/Sounds/Glass.aiff"
        case .lowBattery: return "/System/Library/Sounds/Basso.aiff"
        case .lidOpen: return "/System/Library/Sounds/Pop.aiff"
        case .lockScreen: return "/System/Library/Sounds/Purr.aiff"
        case .unlockScreen: return "/System/Library/Sounds/Hero.aiff"
        case .startup: return "/System/Library/Sounds/Blow.aiff"
        case .shutdown: return "/System/Library/Sounds/Sosumi.aiff"
        case .restart: return "/System/Library/Sounds/Submarine.aiff"
        }
    }
}
