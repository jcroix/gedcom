//
// GedReaderApp.swift — the @main entry point, window scene, menu commands, and Settings (A0, A9).
//
// GedReader is a WINDOWED app (one GEDCOM file per window), not a DocumentGroup — v1 is read-only
// and we want off-main parsing with a progress indicator. The default WindowGroup provides multi-
// window "New Window" (⌘N); File ▸ Open / Open Recent are added by GedReaderCommands. One shared
// RecentsStore backs Open Recent; a Settings scene exposes preferences (⌘,).
//

import SwiftUI

@main
struct GedReaderApp: App {
    @State private var recents = RecentsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(recents)
        }
        .commands {
            GedReaderCommands(recents: recents)
        }

        Settings {
            SettingsView()
        }
    }
}

/// Lightweight signals from menu commands to the focused window's RootView.
extension Notification.Name {
    /// Show the open panel.
    static let openGedcomRequested = Notification.Name("GedReader.openGedcomRequested")
    /// Open a specific file path (from Open Recent); path is the notification object.
    static let openGedcomPath = Notification.Name("GedReader.openGedcomPath")
    /// Focus the People search field (best-effort ⌘F).
    static let focusSearchRequested = Notification.Name("GedReader.focusSearchRequested")
}
