//
// RootView.swift — the window's top-level view: open → parse → show, plus state restoration (A0, A9).
//
// Renders the DocumentModel's state (idle / loading / loaded shell / failed). Opening uses an
// NSOpenPanel; parsing runs off-main in model.loadFile. On a successful open it records the file in
// Open Recent and remembers it (plus the section and home person) in @SceneStorage so a relaunch
// reopens the same file/section/home. Menu commands reach this window via broadcast notifications.
//

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import GedReaderCore
import GedcomKit

struct RootView: View {
    @State private var model = DocumentModel()
    @Environment(RecentsStore.self) private var recents

    // Per-scene restoration: remembered across relaunch by SwiftUI's state restoration.
    @SceneStorage("lastFilePath") private var lastFilePath = ""
    @SceneStorage("lastSection") private var lastSectionRaw = SidebarSection.people.rawValue
    @SceneStorage("lastHome") private var lastHome = ""

    var body: some View {
        Group {
            switch model.state {
            case .idle:    welcomeView
            case .loading: ProgressView("Parsing…").controlSize(.large)
            case .loaded:  ShellView(model: model)
            case .failed(let message): failureView(message)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .focusedSceneValue(\.documentModel, model)
        .onReceive(NotificationCenter.default.publisher(for: .openGedcomRequested)) { _ in presentOpenPanel() }
        .onReceive(NotificationCenter.default.publisher(for: .openGedcomPath)) { note in
            if let path = note.object as? String { open(URL(fileURLWithPath: path), restore: false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearchRequested)) { _ in
            model.currentSection = .people     // best-effort: surface the search field
        }
        // Persist section / home so they're restored next launch.
        .onChange(of: model.currentSection) { _, new in lastSectionRaw = new.rawValue }
        .onChange(of: model.homePerson) { _, new in lastHome = new?.value ?? "" }
        .task { await launch() }
    }

    // MARK: Launch (autoload hook or state restoration)

    private func launch() async {
        // Headless smoke-test hook (no effect in normal use): GEDREADER_AUTOLOAD opens a file;
        // optional GEDREADER_AUTOHOME (xref) sets the chart root; GEDREADER_AUTOSECTION jumps section.
        let env = ProcessInfo.processInfo.environment
        if let path = env["GEDREADER_AUTOLOAD"] {
            await loadAndRecord(URL(fileURLWithPath: path))
            if let home = env["GEDREADER_AUTOHOME"] { model.navigate(to: Xref(home)); model.setHomeToFocus() }
            if let raw = env["GEDREADER_AUTOSECTION"], let s = SidebarSection(rawValue: raw) { model.currentSection = s }
            // Offscreen render hook: write a chart PNG and exit (so Claude can SEE its own output
            // headlessly via SwiftUI ImageRenderer — no screen-recording/display needed).
            if let png = env["GEDREADER_RENDER_PNG"] { ChartRenderer.renderAndExit(model: model, env: env, to: png) }
            return
        }
        // Otherwise restore the last opened file (and its section/home) if it still exists.
        if case .idle = model.state, !lastFilePath.isEmpty,
           FileManager.default.fileExists(atPath: lastFilePath) {
            open(URL(fileURLWithPath: lastFilePath), restore: true)
        }
    }

    // MARK: Opening

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let ged = UTType(filenameExtension: "ged") { panel.allowedContentTypes = [ged] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url, restore: false)
    }

    /// Open `url`. When `restore` is true, also reapply the remembered section/home (used on launch).
    private func open(_ url: URL, restore: Bool) {
        Task {
            await loadAndRecord(url)
            guard case .loaded = model.state else { return }
            if restore {
                if let section = SidebarSection(rawValue: lastSectionRaw) { model.currentSection = section }
                if !lastHome.isEmpty { model.navigate(to: Xref(lastHome)); model.setHomeToFocus() }
            } else {
                model.currentSection = .people     // a freshly opened file starts at People
            }
        }
    }

    private func loadAndRecord(_ url: URL) async {
        await model.loadFile(at: url)
        if case .loaded = model.state {
            recents.record(url.path)
            lastFilePath = url.path
        }
    }

    // MARK: Idle / failure views

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
}
