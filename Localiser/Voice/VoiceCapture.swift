import AVFoundation
import Foundation
import Observation
import Speech

/// Listens while the microphone button is held and writes down what was said, on the phone.
/// Uses the on-device speech transcriber; the audio goes straight to it and is never kept.
@MainActor @Observable final class VoiceCapture {
    enum Phase: Equatable { case idle, preparing, listening, finishing }

    private(set) var phase: Phase = .idle
    /// What has been heard so far. Final once `stop()` returns.
    private(set) var transcript = ""
    var message: String?

    /// Voice memos need a parser for the language. English only for now.
    nonisolated static func isAvailable(for locale: Locale = .current) -> Bool {
        WidgetButtons.voiceWorks(for: locale)
    }

    /// A stand-in transcript for UI tests: `--voice-transcript "the drill's in the garage"`.
    static var standInTranscript: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--voice-transcript"), index + 1 < arguments.count { return arguments[index + 1] }
        #endif
        return nil
    }

    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var reading: Task<Void, Never>?
    private var finalText = ""

    func start() async {
        guard phase == .idle else { return }
        message = nil; transcript = ""; finalText = ""
        if let standIn = Self.standInTranscript { transcript = standIn; return }
        phase = .preparing
        do {
            guard await AVAudioApplication.requestRecordPermission() else {
                throw VoiceError.noMicrophone
            }
            let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) ?? Locale(identifier: "en-US")
            let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
            try await install(transcriber)
            let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer

            reading = Task.detached { [weak self] in
                do {
                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                        await MainActor.run {
                            guard let self else { return }
                            if result.isFinal { self.finalText += (self.finalText.isEmpty ? "" : " ") + text; self.transcript = self.finalText }
                            else { self.transcript = self.finalText + (self.finalText.isEmpty ? "" : " ") + text }
                        }
                    }
                } catch {}
            }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            input = continuation
            let node = engine.inputNode
            let natural = node.outputFormat(forBus: 0)
            let target = format ?? natural
            let converter = target == natural ? nil : AVAudioConverter(from: natural, to: target)
            Self.installTap(on: node, format: natural, converter: converter, target: target, continuation: continuation)
            engine.prepare()
            try engine.start()
            try await analyzer.start(inputSequence: stream)
            phase = .listening
        } catch {
            message = (error as? VoiceError)?.text ?? "Listening didn't start. \(error.localizedDescription)"
            teardown()
            phase = .idle
        }
    }

    /// Stops listening and returns everything heard.
    @discardableResult func stop() async -> String {
        if Self.standInTranscript != nil { phase = .idle; return transcript }
        guard phase == .listening else { teardown(); phase = .idle; return transcript }
        phase = .finishing
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        input?.finish()
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await reading?.value
        teardown()
        phase = .idle
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func teardown() {
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        input?.finish(); input = nil
        reading?.cancel(); reading = nil
        analyzer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The speech model downloads once, the first time. Without a connection then, say so plainly.
    private func install(_ transcriber: SpeechTranscriber) async throws {
        guard SpeechTranscriber.isAvailable else { throw VoiceError.unsupported }
        switch await AssetInventory.status(forModules: [transcriber]) {
        case .installed: return
        case .unsupported: throw VoiceError.unsupported
        case .supported, .downloading:
            fallthrough
        @unknown default:
            do {
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) { try await request.downloadAndInstall() }
            } catch { throw VoiceError.needsDownload }
        }
    }

    /// Core Audio calls the tap on its own real-time thread, so the closure must not belong to the main actor.
    nonisolated private static func installTap(on node: AVAudioInputNode, format: AVAudioFormat, converter: AVAudioConverter?, target: AVAudioFormat, continuation: AsyncStream<AnalyzerInput>.Continuation) {
        node.installTap(onBus: 0, bufferSize: 4096, format: format) { @Sendable buffer, _ in
            guard let converted = convert(buffer, with: converter, to: target) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }
    }

    nonisolated private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter?, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        nonisolated(unsafe) var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true; status.pointee = .haveData; return buffer
        }
        return error == nil ? output : nil
    }

    enum VoiceError: Error {
        case noMicrophone, unsupported, needsDownload
        var text: String {
            switch self {
            case .noMicrophone: "Hereabouts needs the microphone to hear you. Turn it on in Settings, or type instead."
            case .unsupported: "Voice memos don't work on this iPhone. Type instead."
            case .needsDownload: "The speech model needs to download once. Connect to the internet and try again, or type instead."
            }
        }
    }
}
