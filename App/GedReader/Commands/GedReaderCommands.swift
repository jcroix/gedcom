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
    let recents: RecentsStore

    var body: some Commands {
        // Keep the default "New Window" (⌘N) and add Open / Open Recent after it.
        CommandGroup(after: .newItem) {
            Button("Open…") { NotificationCenter.default.post(name: .openGedcomRequested, object: nil) }
                .keyboardShortcut("o", modifiers: .command)

            Menu("Open Recent") {
                ForEach(recents.recents.paths, id: \.self) { path in
                    Button((path as NSString).lastPathComponent) {
                        NotificationCenter.default.post(name: .openGedcomPath, object: path)
                    }
                }
                if !recents.recents.paths.isEmpty {
                    Divider()
                    Button("Clear Menu") { recents.clear() }
                }
            }
            .disabled(recents.recents.paths.isEmpty)
        }

        // Find (best-effort ⌘F): focuses the People search field.
        CommandGroup(after: .textEditing) {
            Button("Find Person…") { NotificationCenter.default.post(name: .focusSearchRequested, object: nil) }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(model == nil)
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
