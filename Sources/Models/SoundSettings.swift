import Foundation
import Combine

class SoundSettings: ObservableObject {
    static let shared = SoundSettings()

    private let defaults = UserDefaults.standard
    private let enabledKey = "pb_enabled"
    private let volumeKey = "pb_volume"
    private let lowBatteryThresholdKey = "pb_low_battery_threshold"
    private let maxChargeThresholdKey = "pb_max_charge_threshold"
    private let elevenLabsAPIKeyKey = "pb_elevenlabs_api_key"
    private let elevenLabsVoiceIDKey = "pb_elevenlabs_voice_id"

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: enabledKey) }
    }

    @Published var volume: Float {
        didSet { defaults.set(volume, forKey: volumeKey) }
    }

    @Published var lowBatteryThreshold: Int {
        didSet { defaults.set(lowBatteryThreshold, forKey: lowBatteryThresholdKey) }
    }

    @Published var maxChargeThreshold: Int {
        didSet { defaults.set(maxChargeThreshold, forKey: maxChargeThresholdKey) }
    }

    @Published var elevenLabsAPIKey: String {
        didSet { defaults.set(elevenLabsAPIKey, forKey: elevenLabsAPIKeyKey) }
    }

    @Published var elevenLabsVoiceID: String {
        didSet { defaults.set(elevenLabsVoiceID, forKey: elevenLabsVoiceIDKey) }
    }

    private init() {
        self.isEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        self.volume = defaults.object(forKey: volumeKey) as? Float ?? 0.7
        self.lowBatteryThreshold = defaults.object(forKey: lowBatteryThresholdKey) as? Int ?? 20
        self.maxChargeThreshold = defaults.object(forKey: maxChargeThresholdKey) as? Int ?? 100
        self.elevenLabsAPIKey = defaults.string(forKey: elevenLabsAPIKeyKey) ?? ""
        self.elevenLabsVoiceID = defaults.string(forKey: elevenLabsVoiceIDKey) ?? "EXAVITQu4vr4xnSDxMaL"
    }

    // MARK: - Per-event sound file paths

    func soundFilePath(for event: SoundEvent) -> String {
        let key = "pb_sound_\(event.rawValue)"
        return defaults.string(forKey: key) ?? event.defaultSystemSound
    }

    func setSoundFilePath(_ path: String?, for event: SoundEvent) {
        let key = "pb_sound_\(event.rawValue)"
        if let path = path {
            defaults.set(path, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        objectWillChange.send()
    }

    func isEventEnabled(_ event: SoundEvent) -> Bool {
        let key = "pb_event_enabled_\(event.rawValue)"
        return defaults.object(forKey: key) as? Bool ?? true
    }

    func setEventEnabled(_ enabled: Bool, for event: SoundEvent) {
        let key = "pb_event_enabled_\(event.rawValue)"
        defaults.set(enabled, forKey: key)
        objectWillChange.send()
    }

    // MARK: - Per-event custom voice text

    func customVoiceText(for event: SoundEvent) -> String {
        let key = "pb_custom_text_\(event.rawValue)"
        return defaults.string(forKey: key) ?? ""
    }

    func setCustomVoiceText(_ text: String, for event: SoundEvent) {
        let key = "pb_custom_text_\(event.rawValue)"
        defaults.set(text, forKey: key)
        objectWillChange.send()
    }

    /// Directory for storing generated AI voice sounds
    var aiVoiceSoundsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacMistress/AIVoice")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func resetToDefaults() {
        for event in SoundEvent.allCases {
            setSoundFilePath(nil, for: event)
            setEventEnabled(true, for: event)
        }
        volume = 0.7
        lowBatteryThreshold = 20
        maxChargeThreshold = 100
        isEnabled = true
    }
}
