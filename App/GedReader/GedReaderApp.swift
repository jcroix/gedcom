//
// GedReaderApp.swift — the @main entry point and window scene.
//
// GedReader is a WINDOWED app (one GEDCOM file per window), not a DocumentGroup — v1 is read-only
// and we want off-main parsing with a progress indicator, neither of which DocumentGroup suits.
// Each window owns one DocumentModel (the source of truth, from GedReaderCore). This file stays
// tiny: scene + menu commands. All real behavior is in RootView and the model.
//

import SwiftUI

@main
struct GedReaderApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .commands {
            GedReaderCommands()
        }
    }
}

/// A lightweight signal from the menu command to the focused window's RootView to present the open
/// panel. (Menu commands are app-level and can't directly reach a specific window's model, so we
/// broadcast and let the active RootView respond. This is replaced by proper focused-scene wiring
/// when multi-window handling lands in a later milestone.)
extension Notification.Name {
    static let openGedcomRequested = Notification.Name("GedReader.openGedcomRequested")
}
