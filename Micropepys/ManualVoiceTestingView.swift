#if DEBUG
import SwiftUI
import MicropepysCore

struct ManualVoiceTestingView: View {
    @ObservedObject var harness: ManualVoiceTestHarness
    let manager: ChecklistManager

    var body: some View {
        DisclosureGroup("Manual Voice Testing") {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Backend URL", text: $harness.backendBaseURLText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            harness.persistBackendBaseURL()
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fixture directory")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(harness.fixturesDirectoryPath)
                            .font(.caption.monospaced())
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    if harness.fixtures.isEmpty {
                        Text("Drop `.wav` files into the fixture directory, then press Refresh.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Fixture", selection: $harness.selectedFixtureID) {
                            ForEach(harness.fixtures) { fixture in
                                Text(fixture.displayName).tag(fixture.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack(spacing: 8) {
                        Button("Refresh") {
                            harness.refreshFixtures()
                        }

                        Button("Choose Folder…") {
                            harness.chooseFixturesDirectory()
                        }

                        Button("Send") {
                            Task {
                                await harness.sendSelectedFixture(using: manager)
                            }
                        }
                        .disabled(harness.isRunning || harness.fixtures.isEmpty)

                        Button("Apply Last Response") {
                            harness.applyLatestResponse(using: manager)
                        }
                        .disabled(harness.isRunning)

                        Button("Send and Apply") {
                            Task {
                                await harness.sendAndApplySelectedFixture(using: manager)
                            }
                        }
                        .disabled(harness.isRunning || harness.fixtures.isEmpty)

                        Button("Undo Voice Apply") {
                            manager.undo()
                        }
                    }

                    Divider()

                    LabeledContent("Status", value: harness.statusMessage)

                    if harness.requiresFixtureDirectoryAccess {
                        Text("Grant access to the fixtures folder with `Choose Folder…`.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let lastFixtureName = harness.lastFixtureName {
                        LabeledContent("Last fixture", value: lastFixtureName)
                    }

                    if let transcript = harness.lastTranscript {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transcript")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(transcript)
                                .textSelection(.enabled)
                        }
                    }

                    if let confidence = harness.lastConfidence {
                        LabeledContent("Confidence", value: String(format: "%.2f", confidence))
                    }

                    if let transactionID = harness.lastTransactionID {
                        LabeledContent("Transaction ID", value: transactionID)
                    }

                    if !harness.lastRawOperations.isEmpty {
                        operationBlock(title: "Backend operations", lines: harness.lastRawOperations)
                    }

                    if !harness.lastAppliedOperations.isEmpty {
                        operationBlock(title: "Applied checklist operations", lines: harness.lastAppliedOperations)
                    }

                    if !harness.lastWarnings.isEmpty {
                        operationBlock(title: "Mapping warnings", lines: harness.lastWarnings)
                    }

                    if let lastErrorMessage = harness.lastErrorMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last error")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                            Text(lastErrorMessage)
                                .font(.caption.monospaced())
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            .frame(maxHeight: 280)
        }
    }

    @ViewBuilder
    private func operationBlock(title: String, lines: [String]) -> some View {
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
#endif
