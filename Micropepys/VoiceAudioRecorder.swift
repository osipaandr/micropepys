import AVFoundation
import Foundation

enum VoiceAudioRecorderError: LocalizedError {
    case permissionDenied
    case failedToStart
    case notRecording
    case emptyRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is not available."
        case .failedToStart:
            return "Could not start microphone recording."
        case .notRecording:
            return "No active microphone recording was found."
        case .emptyRecording:
            return "Recorded audio was empty."
        }
    }
}

@MainActor
final class VoiceAudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func requestPermissionIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func startRecording() throws {
        guard !isRecording else { return }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("micropepys-voice-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw VoiceAudioRecorderError.failedToStart
        }

        self.recorder = recorder
        self.recordingURL = outputURL
    }

    func stopRecording() throws -> Data {
        guard isRecording, let recorder, let recordingURL else {
            throw VoiceAudioRecorderError.notRecording
        }

        recorder.stop()
        self.recorder = nil
        self.recordingURL = nil

        let audioData = try Data(contentsOf: recordingURL)
        try? FileManager.default.removeItem(at: recordingURL)

        guard !audioData.isEmpty else {
            throw VoiceAudioRecorderError.emptyRecording
        }

        return audioData
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil

        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }
}
