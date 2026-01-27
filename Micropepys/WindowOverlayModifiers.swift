//
//  WindowOverlayModifiers.swift
//  Micropepys
//
//  Created by Andrey Osipenko on 07.11.25.
//

import SwiftUI

private struct OverlayWindowConfigurator: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WindowAccessor { window in
                guard let window = window else { return }
                // Убираем заголовок и рамку
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isOpaque = false
                window.backgroundColor = .clear

                // Делаем окно «поверх всех»
                window.level = .floating

                // Опционально: отключить тень окна, если хотите более «плоский» вид
                // window.hasShadow = false

                // Разрешить клики «сквозь» окно (если хотите полностью пассивный overlay)
                // window.ignoresMouseEvents = true
            })
    }
}

// Вспомогательный NSView, чтобы получить NSWindow из иерархии SwiftUI
private struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

extension View {
    func overlayStyleWindow() -> some View {
        self.modifier(OverlayWindowConfigurator())
    }
}
