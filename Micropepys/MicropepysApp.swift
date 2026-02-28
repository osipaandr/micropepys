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
    @StateObject private var checklistManager = ChecklistManager()

    var body: some Scene {
        Window("Checklist", id: "main-window") {
            ChecklistWidgetView()
                .environmentObject(checklistManager)
                .overlayStyleWindow()
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    checklistManager.undo()
                }
                .keyboardShortcut(ActionKeymap.keyboardShortcut(for: .undo))
            }
        }
    }
}
