//
// DocumentModelTests.swift — the window's source-of-truth logic (load state, summary, navigation).
//
// DocumentModel is @MainActor, so the test class is too. It's @available(macOS 14) to match the
// @Observable type; the test host (macOS 26) satisfies that.
//

import XCTest
@testable import GedReaderCore
import GedcomKit

@available(macOS 14, iOS 17, *)
@MainActor
final class DocumentModelTests: XCTestCase {

    private let validGedcom = """
    0 HEAD
    1 GEDC
    2 VERS 5.5.1
    0 @I1@ INDI
    1 NAME John /Crox/
    0 @I2@ INDI
    1 NAME Jane /Doe/
    0 @F1@ FAM
    1 HUSB @I1@
    1 WIFE @I2@
    0 TRLR
    """

    /// Tracer: loading valid GEDCOM bytes moves to .loaded and exposes the document + summary.
    func testLoadValidDataBecomesLoadedWithSummary() {
        let model = DocumentModel()
        if case .idle = model.state {} else { XCTFail("should start idle") }

        model.load(data: Data(validGedcom.utf8))

        guard case .loaded = model.state else { return XCTFail("expected .loaded, got \(model.state)") }
        XCTAssertEqual(model.document?.individuals.count, 2)
        XCTAssertEqual(model.summary, "2 people · 1 families")
    }

    /// A non-GEDCOM file (no records parsed) becomes .failed rather than an empty loaded document.
    func testLoadGarbageBecomesFailed() {
        let model = DocumentModel()
        model.load(data: Data("this is not a gedcom file at all".utf8))
        guard case .failed = model.state else { return XCTFail("expected .failed, got \(model.state)") }
        XCTAssertNil(model.document)
    }

    /// Navigation drives the focus through the history, and Set Home captures the current focus.
    func testNavigationFocusAndSetHome() {
        let model = DocumentModel()
        model.load(data: Data(validGedcom.utf8))

        XCTAssertNil(model.focus)
        model.navigate(to: Xref("@I1@"))
        model.navigate(to: Xref("@I2@"))
        XCTAssertEqual(model.focus, Xref("@I2@"))

        model.setHomeToFocus()
        XCTAssertEqual(model.homePerson, Xref("@I2@"))

        model.goBack()
        XCTAssertEqual(model.focus, Xref("@I1@"))
        XCTAssertEqual(model.homePerson, Xref("@I2@"), "Set Home is independent of back/forward.")
    }

    /// Go Home navigates to the set home person; the section defaults to People.
    func testGoHomeNavigatesToHomePerson() {
        let model = DocumentModel()
        model.load(data: Data(validGedcom.utf8))
        XCTAssertEqual(model.currentSection, .people)

        model.navigate(to: Xref("@I1@"))
        model.setHomeToFocus()
        model.navigate(to: Xref("@I2@"))
        XCTAssertEqual(model.focus, Xref("@I2@"))

        model.goHome()
        XCTAssertEqual(model.focus, Xref("@I1@"))
    }

    /// Loading the real family.ged through the model yields the expected counts and summary.
    func testLoadsRealFamilyFileSummary() throws {
        let model = DocumentModel()
        model.load(data: try Data(contentsOf: Self.realFamilyURL()))
        XCTAssertEqual(model.summary, "2,000 people · 594 families")
    }

    /// Locate the engine's bundled family.ged on disk via this test file's path (the GedReaderCore
    /// test target doesn't bundle the fixture; we read the engine's copy directly — see Package.swift).
    private static func realFamilyURL() throws -> URL {
        // <root>/Tests/GedReaderCoreTests/DocumentModelTests.swift -> up 3 -> <root>
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Tests/GedcomKitTests/Fixtures/family.ged")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("family.ged fixture not found at \(url.path)")
        }
        return url
    }
}
