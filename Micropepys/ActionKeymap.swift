import SwiftUI

enum UserAction {
    case undo
    case toggleVoiceUpdate
}

enum ActionKeymap {
    static func keyboardShortcut(for action: UserAction) -> KeyboardShortcut {
        switch action {
        case .undo:
            return KeyboardShortcut("z", modifiers: .command)
        case .toggleVoiceUpdate:
            return KeyboardShortcut("v", modifiers: [.command, .shift])
        }
    }
}
