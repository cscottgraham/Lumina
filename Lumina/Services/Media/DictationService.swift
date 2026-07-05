import Foundation
import Speech
import AVFoundation
import Observation

/// Live voice dictation (Speech framework): AVAudioEngine tap → streaming
/// SFSpeechRecognizer transcription, with audio levels for the waveform UI.
/// Also transcribes finished audio FILES (post-recording) so voice memos get
/// searchable, chat-visible transcripts.
@MainActor
@Observable
final class DictationService {
    private(set) var isDictating = false
    /// The live partial/final transcript of the CURRENT session.
    private(set) var transcript = ""
    /// Rolling normalized levels for LiveWaveformView.
    private(set) var levels: [CGFloat] = []
    var errorText: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-CA"))
        ?? SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let maxLevelSamples = 48

    // MARK: Live dictation

    func start() async {
        errorText = nil
        transcript = ""

        guard await Self.requestSpeechAuthorization() else {
            errorText = "Speech recognition access is off — enable it in Settings."
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            errorText = "Microphone access is off — enable it in Settings."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorText = "Speech recognition isn't available right now."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                request.append(buffer)
                let level = Self.rmsLevel(of: buffer)
                Task { @MainActor [weak self] in self?.pushLevel(level) }
            }

            engine.prepare()
            try engine.start()
            isDictating = true
            levels = Array(repeating: 0.05, count: maxLevelSamples)

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil, self.isDictating {
                        // Recognition ended (timeout/cancel) — stop cleanly.
                        self.stop()
                    }
                }
            }
        } catch {
            errorText = "Couldn't start dictation: \(error.localizedDescription)"
            stop()
        }
    }

    /// Stops the session; `transcript` holds the final text.
    func stop() {
        guard isDictating || engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isDictating = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func pushLevel(_ level: CGFloat) {
        guard isDictating else { return }
        levels.append(max(0.05, min(1, level)))
        if levels.count > maxLevelSamples { levels.removeFirst() }
    }

    // MARK: File transcription (post-recording voice memos)

    /// Best-effort transcription of a finished audio file. Returns "" on any
    /// failure — callers treat the transcript as optional enrichment.
    static func transcribeFile(at url: URL) async -> String {
        guard await requestSpeechAuthorization(),
              let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else { return "" }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return await withCheckedContinuation { continuation in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let result, result.isFinal {
                    finished = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if error != nil {
                    finished = true
                    continuation.resume(returning: "")
                }
            }
        }
    }

    // MARK: Helpers

    static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    nonisolated private static func rmsLevel(of buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n))
        return CGFloat(min(1, rms * 12))   // scale into a lively 0…1
    }
}
