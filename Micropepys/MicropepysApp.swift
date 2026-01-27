//
//  MicropepysApp.swift
//  Micropepys
//
//  Created by Andrey Osipenko on 06.11.25.
//

import SwiftUI

@main
struct MicropepysApp: App {
    var body: some Scene {
        Window("Checklist", id: "main-window") {
            ChecklistWidgetView()
                .overlayStyleWindow()
        }
    }
}
