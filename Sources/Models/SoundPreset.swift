import Foundation

enum SoundPreset: String, CaseIterable, Identifiable {
    case system = "System Default"
    case sexy = "Sexy"
    case sensual = "Sensual"
    case sensualHindi = "Sensual Hindi"
    case shonenAnime = "Shonen Anime"
    case kawaiiAnime = "Kawaii Anime"
    case fun = "Fun"
    case aiVoice = "AI Voice"
    case custom = "Custom"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .system: return "macOS default system sounds"
        case .sexy: return "Sultry, flirty voice (English)"
        case .sensual: return "Intimate, warm voice (English)"
        case .sensualHindi: return "Sensual voice (Hindi)"
        case .shonenAnime: return "Epic battle cries (Japanese)"
        case .kawaiiAnime: return "Cute anime sounds (Japanese)"
        case .fun: return "Quirky, goofy voice effects"
        case .aiVoice: return "Generate with ElevenLabs AI"
        case .custom: return "Your own custom sounds"
        }
    }

    var icon: String {
        switch self {
        case .system: return "laptopcomputer"
        case .sexy: return "heart.fill"
        case .sensual: return "flame.fill"
        case .sensualHindi: return "heart.text.square.fill"
        case .shonenAnime: return "bolt.fill"
        case .kawaiiAnime: return "star.fill"
        case .fun: return "face.smiling.fill"
        case .aiVoice: return "waveform.and.mic"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// Folder name inside Resources/Presets/
    var folderName: String? {
        switch self {
        case .system, .custom, .aiVoice: return nil
        case .sexy: return "Sexy"
        case .sensual: return "Sensual"
        case .sensualHindi: return "SensualHindi"
        case .shonenAnime: return "ShonenAnime"
        case .kawaiiAnime: return "KawaiiAnime"
        case .fun: return "Fun"
        }
    }

    /// Maps SoundEvent to the filename inside the preset folder (checks mp3 first, then aiff)
    func fileNames(for event: SoundEvent) -> [String] {
        let base: String
        switch event {
        case .chargingStart: base = "charging_start"
        case .discharging: base = "discharging"
        case .fullCharge: base = "full_charge"
        case .lowBattery: base = "low_battery"
        case .lidOpen: base = "lid_open"
        case .lockScreen: base = "lock_screen"
        case .unlockScreen: base = "unlock_screen"
        case .startup: base = "startup"
        case .shutdown: base = "shutdown"
        case .restart: base = "restart"
        }
        return ["\(base).mp3", "\(base).aiff"]
    }

    /// Full path to a preset's sound file for a given event
    func soundPath(for event: SoundEvent) -> String? {
        guard let folder = folderName else { return nil }

        let candidates = fileNames(for: event)

        // Check bundled resources first
        for name in candidates {
            if let bundlePath = Bundle.main.path(forResource: name,
                                                  ofType: nil,
                                                  inDirectory: "Resources/Presets/\(folder)") {
                return bundlePath
            }
        }

        // Fallback: check relative to executable (for swift run)
        let execURL = Bundle.main.executableURL?.deletingLastPathComponent()

        for name in candidates {
            let devPaths = [
                execURL?.appendingPathComponent("MacMistress_MacMistress.bundle/Contents/Resources/Resources/Presets/\(folder)/\(name)"),
                URL(fileURLWithPath: #filePath)
                    .deletingLastPathComponent() // Models/
                    .deletingLastPathComponent() // Sources/
                    .appendingPathComponent("Resources/Presets/\(folder)/\(name)")
            ]

            for path in devPaths.compactMap({ $0 }) {
                if FileManager.default.fileExists(atPath: path.path) {
                    return path.path
                }
            }
        }

        return nil
    }
}

// MARK: - Preset Manager

class PresetManager {
    static let shared = PresetManager()
    private let settings = SoundSettings.shared
    private let presetKey = "pb_active_preset"

    var activePreset: SoundPreset {
        get {
            let raw = UserDefaults.standard.string(forKey: presetKey) ?? SoundPreset.system.rawValue
            return SoundPreset(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: presetKey)
            applyPreset(newValue)
        }
    }

    func applyPreset(_ preset: SoundPreset) {
        switch preset {
        case .system:
            // Reset all to system defaults
            for event in SoundEvent.allCases {
                settings.setSoundFilePath(nil, for: event)
            }

        case .custom:
            // Don't change anything — user manages manually
            break

        case .aiVoice:
            // Apply any previously generated AI voice sounds
            let aiDir = settings.aiVoiceSoundsDirectory
            for event in SoundEvent.allCases {
                let base: String
                switch event {
                case .chargingStart: base = "charging_start"
                case .discharging: base = "discharging"
                case .fullCharge: base = "full_charge"
                case .lowBattery: base = "low_battery"
                case .lidOpen: base = "lid_open"
                case .lockScreen: base = "lock_screen"
                case .unlockScreen: base = "unlock_screen"
                case .startup: base = "startup"
                case .shutdown: base = "shutdown"
                case .restart: base = "restart"
                }
                let path = aiDir.appendingPathComponent("\(base).mp3").path
                if FileManager.default.fileExists(atPath: path) {
                    settings.setSoundFilePath(path, for: event)
                }
            }

        default:
            // Apply preset sounds
            for event in SoundEvent.allCases {
                if let path = preset.soundPath(for: event) {
                    settings.setSoundFilePath(path, for: event)
                }
            }
        }

        settings.objectWillChange.send()
    }
}
