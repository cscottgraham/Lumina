import Foundation
import AVFoundation
import Observation

/// AVAudioRecorder wrapper: records AAC/m4a straight to a temp file (never in
/// memory), publishes metering levels for the live waveform, and hands the
/// file URL to MediaImportService on stop.
@MainActor
@Observable
final class AudioRecorderService {
    private(set) var isRecording = false
    private(set) var duration: TimeInterval = 0
    /// Rolling normalized levels (0…1), newest last — drives LiveWaveformView.
    private(set) var levels: [CGFloat] = []
    private(set) var fileURL: URL?
    var errorText: String?

    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?
    private let maxLevelSamples = 48

    func start() async {
        errorText = nil
        guard await AVAudioApplication.requestRecordPermission() else {
            errorText = "Microphone access is off — enable it in Settings."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = URL.temporaryDirectory.appending(path: "rec-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.record()

            recorder = rec
            fileURL = url
            isRecording = true
            duration = 0
            levels = Array(repeating: 0.05, count: maxLevelSamples)
            startMetering()
        } catch {
            errorText = "Couldn't start recording: \(error.localizedDescription)"
        }
    }

    /// Stops and returns the recorded file's URL (nil if nothing usable).
    @discardableResult
    func stop() -> URL? {
        meterTask?.cancel(); meterTask = nil
        recorder?.stop(); recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return duration > 0.4 ? fileURL : nil
    }

    func discard() {
        _ = stop()
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
    }

    private func startMetering() {
        meterTask = Task { [weak self] in
            while let self, self.isRecording, !Task.isCancelled {
                if let rec = self.recorder {
                    rec.updateMeters()
                    self.duration = rec.currentTime
                    // dBFS (-160…0) → 0…1 with a gentle floor for visual life.
                    let db = rec.averagePower(forChannel: 0)
                    let normalized = CGFloat(max(0, min(1, pow(10, db / 20) * 1.6)))
                    self.levels.append(max(0.05, normalized))
                    if self.levels.count > self.maxLevelSamples { self.levels.removeFirst() }
                }
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }
}
