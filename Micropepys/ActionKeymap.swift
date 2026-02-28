import SwiftUI

enum UserAction {
    case undo
}

enum ActionKeymap {
    static func keyboardShortcut(for action: UserAction) -> KeyboardShortcut {
        switch action {
        case .undo:
            return KeyboardShortcut("z", modifiers: .command)
        }
    }
}
