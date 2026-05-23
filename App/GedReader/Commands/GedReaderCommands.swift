//
// GedReaderCommands.swift — the app's menu bar commands (A3 nav, A9 polish).
//
// Menu commands are app-level, but they act on the FOCUSED window's DocumentModel. We reach it via
// a focused-scene value: RootView publishes its model with .focusedSceneValue, and these commands
// read it with @FocusedValue. When no window is focused the model is nil and the items disable.
//
// Provides: File ▸ Open (⌘O), a Go menu (Back ⌘[, Forward ⌘], Set/Go Home), and View ▸ section
// jumps (⌘1–⌘5). Search focus (⌘F) is added with the search milestone.
//

import SwiftUI
import GedReaderCore

/// Focused-scene plumbing so menu commands can reach the active window's model.
struct DocumentModelFocusedValueKey: FocusedValueKey {
    typealias Value = DocumentModel
}
extension FocusedValues {
    var documentModel: DocumentModel? {
        get { self[DocumentModelFocusedValueKey.self] }
        set { self[DocumentModelFocusedValueKey.self] = newValue }
    }
}

struct GedReaderCommands: Commands {
    @FocusedValue(\.documentModel) private var model: DocumentModel?

    var body: some Commands {
        // Replace "New" with "Open…" — v1 has nothing to create, only files to open.
        CommandGroup(replacing: .newItem) {
            Button("Open…") { NotificationCenter.default.post(name: .openGedcomRequested, object: nil) }
                .keyboardShortcut("o", modifiers: .command)
        }

        // Browser-style navigation.
        CommandMenu("Go") {
            Button("Back") { model?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!(model?.canGoBack ?? false))
            Button("Forward") { model?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!(model?.canGoForward ?? false))
            Divider()
            Button("Set Home") { model?.setHomeToFocus() }
                .keyboardShortcut("h", modifiers: .command)
                .disabled(model?.focus == nil)
            Button("Go Home") { model?.goHome() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(model?.homePerson == nil)
        }

        // Section jumps ⌘1–⌘5, placed after the sidebar toggle in the View menu.
        CommandGroup(after: .sidebar) {
            Divider()
            sectionJump("People", .people, "1")
            sectionJump("Families", .families, "2")
            sectionJump("Charts", .charts, "3")
            sectionJump("Relationships", .relationships, "4")
            sectionJump("Quality", .quality, "5")
        }
    }

    private func sectionJump(_ title: String, _ section: SidebarSection, _ key: KeyEquivalent) -> some View {
        Button(title) { model?.currentSection = section }
            .keyboardShortcut(key, modifiers: .command)
            .disabled(model == nil)
    }
}
