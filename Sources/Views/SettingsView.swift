import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var settings = SoundSettings.shared
    @State private var selectedPreset: SoundPreset = PresetManager.shared.activePreset
    @State private var hoveredEvent: SoundEvent?

    // Group events by category for better organization
    private var batteryEvents: [SoundEvent] { [.chargingStart, .discharging, .fullCharge, .lowBattery] }
    private var systemEvents: [SoundEvent] { [.lidOpen, .lockScreen, .unlockScreen] }
    private var lifecycleEvents: [SoundEvent] { [.startup, .shutdown, .restart] }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Preset selector
                    presetSection

                    // AI Voice configuration (shown when AI Voice preset is selected)
                    if selectedPreset == .aiVoice {
                        aiVoiceSection
                    }
                    
                    // Sound events grouped by category
                    eventSection(title: "Battery", icon: "battery.100.bolt", events: batteryEvents)
                    eventSection(title: "System", icon: "desktopcomputer", events: systemEvents)
                    eventSection(title: "Lifecycle", icon: "power", events: lifecycleEvents)
                }
                .padding(20)
            }

            Divider()

            // Footer controls
            footerView
        }
        .frame(width: 620, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Mac Mistress")
                        .font(.title3.bold())
                    Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                }
                Text("Custom sounds for macOS events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.9)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Presets

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sound Presets", systemImage: "waveform.circle.fill")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SoundPreset.allCases) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: selectedPreset == preset,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPreset = preset
                                    PresetManager.shared.activePreset = preset
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Event Sections

    @State private var generatingEvents: Set<SoundEvent> = []
    @State private var generationErrors: [SoundEvent: String] = [:]
    @State private var generationSuccess: Set<SoundEvent> = []

    // MARK: - AI Voice Section

    private var aiVoiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ElevenLabs Configuration", systemImage: "waveform.and.mic")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                // API Key
                HStack(spacing: 8) {
                    Text("API Key")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 65, alignment: .trailing)
                    SecureField("Enter your ElevenLabs API key", text: $settings.elevenLabsAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                // Voice ID
                HStack(spacing: 8) {
                    Text("Voice ID")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 65, alignment: .trailing)
                    TextField("ElevenLabs Voice ID (default: Sarah)", text: $settings.elevenLabsVoiceID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.5)))

            // Per-event text input
            Label("Custom Voice Text per Event", systemImage: "text.bubble")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
                .padding(.top, 4)

            VStack(spacing: 6) {
                ForEach(SoundEvent.allCases) { event in
                    AIVoiceEventRow(
                        event: event,
                        isGenerating: generatingEvents.contains(event),
                        errorMessage: generationErrors[event],
                        isSuccess: generationSuccess.contains(event),
                        onGenerate: { text in
                            generateVoice(for: event, text: text)
                        }
                    )
                }
            }

            // Generate All button
            HStack {
                Spacer()
                Button(action: generateAllVoices) {
                    HStack(spacing: 6) {
                        if !generatingEvents.isEmpty {
                            ProgressIndicator()
                        }
                        Text(generatingEvents.isEmpty ? "Generate All" : "Generating...")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!generatingEvents.isEmpty || settings.elevenLabsAPIKey.isEmpty)
            }
        }
    }

    private func generateVoice(for event: SoundEvent, text: String) {
        generatingEvents.insert(event)
        generationErrors.removeValue(forKey: event)
        generationSuccess.remove(event)
        settings.setCustomVoiceText(text, for: event)

        ElevenLabsService.shared.generateSound(for: event, text: text) { result in
            generatingEvents.remove(event)
            switch result {
            case .success:
                generationSuccess.insert(event)
            case .failure(let error):
                generationErrors[event] = error.localizedDescription
            }
        }
    }

    private func generateAllVoices() {
        for event in SoundEvent.allCases {
            let text = settings.customVoiceText(for: event)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                generateVoice(for: event, text: text)
            }
        }
    }

    // MARK: - Original Event Sections

    private func eventSection(title: String, icon: String, events: [SoundEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)

            VStack(spacing: 1) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    SoundEventRow(
                        event: event,
                        isHovered: hoveredEvent == event,
                        isFirst: index == 0,
                        isLast: index == events.count - 1
                    )
                    .onHover { hovering in
                        hoveredEvent = hovering ? event : nil
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $settings.volume, in: 0...1, step: 0.05)
                    .frame(width: 120)
                Text("\(Int(settings.volume * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }

            Divider().frame(height: 20)

            HStack(spacing: 6) {
                Image(systemName: "battery.25")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Low")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $settings.lowBatteryThreshold) {
                    ForEach([5, 10, 15, 20, 25, 30], id: \.self) { val in
                        Text("\(val)%").tag(val)
                    }
                }
                .labelsHidden()
                .frame(width: 65)
            }

            Divider().frame(height: 20)

            HStack(spacing: 6) {
                Image(systemName: "battery.100.bolt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Max")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $settings.maxChargeThreshold) {
                    ForEach([70, 75, 80, 85, 90, 95, 100], id: \.self) { val in
                        Text("\(val)%").tag(val)
                    }
                }
                .labelsHidden()
                .frame(width: 65)
            }

            Spacer()

            Button(action: {
                selectedPreset = .system
                PresetManager.shared.activePreset = .system
                settings.resetToDefaults()
            }) {
                Label("Reset All", systemImage: "arrow.counterclockwise")
                    .font(.caption)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .foregroundColor(.red.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Sound Event Row

struct SoundEventRow: View {
    let event: SoundEvent
    let isHovered: Bool
    let isFirst: Bool
    let isLast: Bool
    @ObservedObject private var settings = SoundSettings.shared
    @State private var isEnabled: Bool = true
    @State private var isPlaying: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Event icon
            Image(systemName: event.icon)
                .font(.system(size: 14))
                .foregroundColor(isEnabled ? .accentColor : .secondary)
                .frame(width: 24)

            // Toggle
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
                .onChange(of: isEnabled) { newValue in
                    settings.setEventEnabled(newValue, for: event)
                }

            // Labels
            VStack(alignment: .leading, spacing: 1) {
                Text(event.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                Text(event.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Current sound file
            Text(currentFileName)
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.6))
                .lineLimit(1)
                .frame(maxWidth: 100, alignment: .trailing)

            // Action buttons
            HStack(spacing: 4) {
                actionButton(icon: "folder", help: "Choose sound") {
                    chooseSoundFile()
                }
                actionButton(icon: isPlaying ? "stop.fill" : "play.fill", help: "Preview") {
                    previewSound()
                }
                actionButton(icon: "arrow.counterclockwise", help: "Reset") {
                    resetSound()
                }
            }
            .opacity(isHovered ? 1 : 0.4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color(nsColor: .controlBackgroundColor).opacity(0.8) : Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .onAppear {
            isEnabled = settings.isEventEnabled(event)
        }
    }

    private func actionButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var currentFileName: String {
        let path = settings.soundFilePath(for: event)
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func chooseSoundFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose Sound for \(event.rawValue)"
        panel.allowedContentTypes = [
            UTType.audio,
            UTType.aiff,
            UTType.mp3,
            UTType.wav,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "caf") ?? .audio
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(bookmark, forKey: "pb_bookmark_\(event.rawValue)")
            }
            settings.setSoundFilePath(url.path, for: event)
        }
    }

    private func previewSound() {
        let path = settings.soundFilePath(for: event)
        SoundManager.shared.preview(path: path, volume: settings.volume)
    }

    private func resetSound() {
        settings.setSoundFilePath(nil, for: event)
    }
}

// MARK: - Event Icons Extension

extension SoundEvent {
    var icon: String {
        switch self {
        case .chargingStart: return "bolt.fill"
        case .discharging: return "bolt.slash.fill"
        case .fullCharge: return "battery.100"
        case .lowBattery: return "battery.25"
        case .lidOpen: return "laptopcomputer"
        case .lockScreen: return "lock.fill"
        case .unlockScreen: return "lock.open.fill"
        case .startup: return "power"
        case .shutdown: return "power.circle"
        case .restart: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Preset Card

struct PresetCard: View {
    let preset: SoundPreset
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 5) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .white : .accentColor)
                Text(preset.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 6)
            .frame(minWidth: 80, minHeight: 64, maxHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : (isHovered ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .controlBackgroundColor).opacity(0.6)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - AI Voice Event Row

struct AIVoiceEventRow: View {
    let event: SoundEvent
    let isGenerating: Bool
    let errorMessage: String?
    let isSuccess: Bool
    let onGenerate: (String) -> Void

    @ObservedObject private var settings = SoundSettings.shared
    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: event.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .frame(width: 18)

                Text(event.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 90, alignment: .leading)

                TextField("Enter text for this sound...", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .onAppear {
                        text = settings.customVoiceText(for: event)
                    }

                // Status indicator
                if isGenerating {
                    ProgressIndicator()
                        .frame(width: 14, height: 14)
                } else if isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                } else if errorMessage != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .help(errorMessage ?? "")
                }

                Button(action: { onGenerate(text) }) {
                    Image(systemName: "waveform.badge.plus")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Generate AI voice")

                // Preview button
                Button(action: {
                    let path = settings.soundFilePath(for: event)
                    SoundManager.shared.preview(path: path, volume: settings.volume)
                }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Preview sound")
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .padding(.leading, 26)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor).opacity(0.4)))
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSProgressIndicator {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.startAnimation(nil)
        return indicator
    }
    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {}
}
