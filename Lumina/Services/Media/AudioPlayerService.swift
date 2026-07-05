import Foundation
import AVFoundation
import Observation

/// AVAudioPlayer wrapper for the audio viewer + inline playback: play/pause,
/// scrubbing, observable progress.
@MainActor
@Observable
final class AudioPlayerService {
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var errorText: String?

    private var player: AVAudioPlayer?
    private var tickTask: Task<Void, Never>?

    func load(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            player = p
            duration = p.duration
            currentTime = 0
        } catch {
            errorText = "Couldn't load audio: \(error.localizedDescription)"
        }
    }

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        guard let player else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        isPlaying = true
        tick()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        tickTask?.cancel()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = max(0, min(time, duration))
        currentTime = player.currentTime
    }

    func stop() {
        pause()
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func tick() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while let self, self.isPlaying, !Task.isCancelled {
                if let p = self.player {
                    self.currentTime = p.currentTime
                    if !p.isPlaying {           // reached the end
                        self.isPlaying = false
                        self.currentTime = 0
                    }
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
