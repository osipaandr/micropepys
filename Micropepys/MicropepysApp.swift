//
//  MicropepysApp.swift
//  Micropepys
//
//  Created by Andrey Osipenko on 06.11.25.
//

import SwiftUI
import MicropepysCore

@main
struct MicropepysApp: App {
    @StateObject private var checklistManager: ChecklistManager
    @StateObject private var voiceFlowController: VoiceFlowController
    @StateObject private var voiceSettings: VoiceSettings

    init() {
        let checklistManager = ChecklistManager()
        let voiceSettings = VoiceSettings()
        _checklistManager = StateObject(wrappedValue: checklistManager)
        _voiceSettings = StateObject(wrappedValue: voiceSettings)
        _voiceFlowController = StateObject(
            wrappedValue: VoiceFlowController(
                checklistManager: checklistManager,
                voiceSettings: voiceSettings
            )
        )
    }

    var body: some Scene {
        Window("Checklist", id: "main-window") {
            ChecklistWidgetView()
                .environmentObject(checklistManager)
                .environmentObject(voiceSettings)
                .environmentObject(voiceFlowController)
                .overlayStyleWindow()
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    checklistManager.undo()
                }
                .keyboardShortcut(ActionKeymap.keyboardShortcut(for: .undo))
            }

            CommandMenu("Voice") {
                Button(voiceFlowController.actionTitle) {
                    Task {
                        await voiceFlowController.toggleRecording()
                    }
                }
                .keyboardShortcut(ActionKeymap.keyboardShortcut(for: .toggleVoiceUpdate))
                .disabled(voiceFlowController.isSending)

                Button("Cancel Voice Recording") {
                    voiceFlowController.cancelRecording()
                }
                .disabled(!voiceFlowController.isRecording || voiceFlowController.isSending)
            }
        }

        Settings {
            VoicePreferencesView()
                .environmentObject(voiceSettings)
        }
    }
}
