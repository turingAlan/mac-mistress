import Foundation

class ElevenLabsService {
    static let shared = ElevenLabsService()
    private let settings = SoundSettings.shared
    private let baseURL = "https://api.elevenlabs.io/v1/text-to-speech"

    enum GenerationError: LocalizedError {
        case noAPIKey
        case emptyText
        case networkError(String)
        case invalidResponse(Int)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "ElevenLabs API key is not set"
            case .emptyText: return "Text cannot be empty"
            case .networkError(let msg): return "Network error: \(msg)"
            case .invalidResponse(let code): return "API returned status \(code)"
            }
        }
    }

    /// Generate speech for a sound event and save to disk
    func generateSound(for event: SoundEvent, text: String, completion: @escaping (Result<String, Error>) -> Void) {
        let apiKey = settings.elevenLabsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            completion(.failure(GenerationError.noAPIKey))
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            completion(.failure(GenerationError.emptyText))
            return
        }

        let voiceID = settings.elevenLabsVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveVoiceID = voiceID.isEmpty ? "EXAVITQu4vr4xnSDxMaL" : voiceID

        let urlString = "\(baseURL)/\(effectiveVoiceID)"
        guard let url = URL(string: urlString) else {
            completion(.failure(GenerationError.networkError("Invalid URL")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": trimmedText,
            "model_id": "eleven_v3",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(GenerationError.networkError(error.localizedDescription)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(GenerationError.networkError("No response")))
                }
                return
            }

            guard httpResponse.statusCode == 200, let data = data else {
                let errorMsg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown"
                NSLog("MacMistress: ElevenLabs API error (\(httpResponse.statusCode)): \(errorMsg)")
                DispatchQueue.main.async {
                    completion(.failure(GenerationError.invalidResponse(httpResponse.statusCode)))
                }
                return
            }

            guard let self = self else { return }

            // Save the audio file
            let fileName = self.fileName(for: event)
            let filePath = self.settings.aiVoiceSoundsDirectory.appendingPathComponent(fileName)

            do {
                try data.write(to: filePath)
                NSLog("MacMistress: Generated AI voice for \(event.rawValue) at \(filePath.path)")
                DispatchQueue.main.async {
                    // Set this as the sound for the event
                    self.settings.setSoundFilePath(filePath.path, for: event)
                    completion(.success(filePath.path))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }

        task.resume()
    }

    private func fileName(for event: SoundEvent) -> String {
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
        return "\(base).mp3"
    }
}
