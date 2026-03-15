import SwiftUI

struct VoiceUpdateControlsView: View {
    @EnvironmentObject private var voiceFlowController: VoiceFlowController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Task {
                        await voiceFlowController.toggleRecording()
                    }
                } label: {
                    Label(
                        voiceFlowController.actionTitle,
                        systemImage: voiceFlowController.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                    )
                }
                .keyboardShortcut(ActionKeymap.keyboardShortcut(for: .toggleVoiceUpdate))
                .disabled(voiceFlowController.isSending)

                if voiceFlowController.isRecording {
                    Button("Cancel") {
                        voiceFlowController.cancelRecording()
                    }
                    .disabled(voiceFlowController.isSending)
                }
            }

            LabeledContent("Voice status", value: voiceFlowController.statusMessage)

            if let transcript = voiceFlowController.lastTranscript {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last transcript")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(transcript)
                        .textSelection(.enabled)
                }
            }

            if let confidence = voiceFlowController.lastConfidence {
                LabeledContent("Confidence", value: String(format: "%.2f", confidence))
            }

            if let transactionID = voiceFlowController.lastTransactionID {
                LabeledContent("Transaction ID", value: transactionID)
            }

            if !voiceFlowController.lastAppliedOperations.isEmpty {
                detailBlock(title: "Applied voice operations", lines: voiceFlowController.lastAppliedOperations)
            }

            if !voiceFlowController.lastWarnings.isEmpty {
                detailBlock(title: "Voice warnings", lines: voiceFlowController.lastWarnings)
            }

            if let lastErrorMessage = voiceFlowController.lastErrorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last voice error")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func detailBlock(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
    }
}
