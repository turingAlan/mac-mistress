import AVFoundation
import Foundation

class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?
    private let settings = SoundSettings.shared
    private var playbackSemaphore: DispatchSemaphore?

    private override init() {
        super.init()
    }

    func play(event: SoundEvent) {
        guard settings.isEnabled, settings.isEventEnabled(event) else { return }

        let path = settings.soundFilePath(for: event)
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: url.path) else {
            NSLog("MacMistress: Sound file not found at \(path)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = settings.volume
            audioPlayer?.play()
            NSLog("MacMistress: Playing \(event.rawValue) from \(url.lastPathComponent)")
        } catch {
            NSLog("MacMistress: Failed to play sound — \(error.localizedDescription)")
        }
    }

    /// Play sound after a delay — used for wake events where audio needs time to init
    func playDelayed(event: SoundEvent, delay: TimeInterval = 1.5) {
        NSLog("MacMistress: Scheduling \(event.rawValue) with \(delay)s delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.play(event: event)
        }
    }

    /// Preview a sound file without checking event enabled state
    func preview(path: String, volume: Float) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.play()
        } catch {
            NSLog("MacMistress: Failed to preview sound — \(error.localizedDescription)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playbackSemaphore?.signal()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        NSLog("MacMistress: Audio decode error — \(error?.localizedDescription ?? "unknown")")
        playbackSemaphore?.signal()
    }
}
