import Foundation
import Speech
import AVFoundation

// On-device-friendly dictation for the Talk-to-Log composer: streams the mic through
// SFSpeechRecognizer and publishes a live transcript. The view mirrors `transcript` into the
// input field while `isListening`. Permission is requested lazily on first use.
@Observable
@MainActor
final class DictationRecognizer {
    enum Status { case idle, listening, denied, unavailable }

    private(set) var status: Status = .idle
    private(set) var transcript: String = ""

    var isListening: Bool { status == .listening }

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() async {
        if isListening { stop() } else { await start() }
    }

    func start() async {
        guard recognizer?.isAvailable == true else { status = .unavailable; return }
        guard await Self.requestSpeechAuth(), await Self.requestMicAuth() else {
            status = .denied
            return
        }
        transcript = ""
        do {
            try startEngine()
            status = .listening
        } catch {
            stop()
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if status == .listening { status = .idle }
    }

    private func startEngine() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let input = audioEngine.inputNode
        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in self.transcript = result.bestTranscription.formattedString }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in self.stop() }
            }
        }

        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private static func requestSpeechAuth() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    private static func requestMicAuth() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }
}
