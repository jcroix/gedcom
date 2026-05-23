//
// RootView.swift — the window's top-level view: drives the open → parse → show lifecycle (A0).
//
// It renders one of four states from the DocumentModel: idle (welcome + Open), loading (progress),
// loaded (for now, the summary line — the 3-column shell arrives in A1), and failed (error + retry).
// File opening uses an NSOpenPanel (we're a windowed app, not a DocumentGroup); parsing runs
// off-main inside model.loadFile, so the UI stays responsive and shows progress.
//

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import GedReaderCore

struct RootView: View {
    @State private var model = DocumentModel()

    var body: some View {
        Group {
            switch model.state {
            case .idle:
                welcomeView
            case .loading:
                ProgressView("Parsing…").controlSize(.large)
            case .loaded:
                ShellView(model: model)    // 3-column browse UI (A1+)
            case .failed(let message):
                failureView(message)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        // Publish this window's model so app-level menu commands act on the focused window.
        .focusedSceneValue(\.documentModel, model)
        // The File ▸ Open menu command broadcasts; the visible window responds by opening a panel.
        .onReceive(NotificationCenter.default.publisher(for: .openGedcomRequested)) { _ in
            presentOpenPanel()
        }
        // Headless smoke-test hook: if GEDREADER_AUTOLOAD names a file, open it on launch. Lets a
        // script verify the UI renders a real file without crashing (no effect in normal use).
        .task {
            if let path = ProcessInfo.processInfo.environment["GEDREADER_AUTOLOAD"] {
                await model.loadFile(at: URL(fileURLWithPath: path))
            }
        }
    }

    // MARK: States

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tree").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("GedReader").font(.largeTitle.bold())
            Text("Open a GEDCOM file to explore people, families, and relationships.")
                .foregroundStyle(.secondary)
            Button("Open GEDCOM…") { presentOpenPanel() }
                .keyboardShortcut("o", modifiers: .command)
                .controlSize(.large)
        }
        .padding(40)
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(.orange)
            Text("Couldn’t open that file").font(.title2)
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Try another file…") { presentOpenPanel() }
        }
        .padding(40)
    }

    // MARK: Opening

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // Filter to .ged when the system knows that type; otherwise allow any file.
        if let ged = UTType(filenameExtension: "ged") {
            panel.allowedContentTypes = [ged]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.loadFile(at: url) }
    }
}
