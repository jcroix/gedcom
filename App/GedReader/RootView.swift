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
import GedcomKit

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
        // Headless smoke-test hook (no effect in normal use): GEDREADER_AUTOLOAD opens a file on
        // launch; optional GEDREADER_AUTOHOME (an xref) sets the chart root; GEDREADER_AUTOSECTION
        // jumps to a section. Lets a script verify each section renders a real file without crashing.
        .task {
            let env = ProcessInfo.processInfo.environment
            guard let path = env["GEDREADER_AUTOLOAD"] else { return }
            await model.loadFile(at: URL(fileURLWithPath: path))
            if let home = env["GEDREADER_AUTOHOME"] {
                model.navigate(to: Xref(home))
                model.setHomeToFocus()
            }
            if let raw = env["GEDREADER_AUTOSECTION"], let section = SidebarSection(rawValue: raw) {
                model.currentSection = section
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
