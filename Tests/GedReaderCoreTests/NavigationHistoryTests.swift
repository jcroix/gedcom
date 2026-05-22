//
// NavigationHistoryTests.swift — browser-style back/forward behavior.
//

import XCTest
@testable import GedReaderCore

final class NavigationHistoryTests: XCTestCase {

    /// Tracer: a fresh history is empty; the first navigation sets current with no back/forward.
    func testFirstNavigationSetsCurrent() {
        var history = NavigationHistory<String>()
        XCTAssertNil(history.current)
        XCTAssertFalse(history.canGoBack)

        history.navigate(to: "A")
        XCTAssertEqual(history.current, "A")
        XCTAssertFalse(history.canGoBack)
        XCTAssertFalse(history.canGoForward)
    }

    /// Back and forward shuttle through visited items, like a browser.
    func testBackAndForwardRetraceExactly() {
        var history = NavigationHistory<String>()
        history.navigate(to: "A")
        history.navigate(to: "B")
        history.navigate(to: "C")     // A -> B -> C

        history.goBack()
        XCTAssertEqual(history.current, "B")
        XCTAssertTrue(history.canGoForward)
        history.goBack()
        XCTAssertEqual(history.current, "A")
        XCTAssertFalse(history.canGoBack)

        history.goForward()
        XCTAssertEqual(history.current, "B")
        history.goForward()
        XCTAssertEqual(history.current, "C")
        XCTAssertFalse(history.canGoForward)
    }

    /// Navigating to a new item after going back discards the forward history (browser semantics).
    func testNewNavigationClearsForward() {
        var history = NavigationHistory<String>()
        history.navigate(to: "A")
        history.navigate(to: "B")
        history.goBack()              // current A, forward = [B]
        XCTAssertTrue(history.canGoForward)

        history.navigate(to: "X")     // new branch
        XCTAssertEqual(history.current, "X")
        XCTAssertFalse(history.canGoForward, "A new navigation must discard the forward stack.")
        history.goBack()
        XCTAssertEqual(history.current, "A")
    }

    /// Re-selecting the already-focused item doesn't create a duplicate history entry.
    func testNavigatingToCurrentIsNoOp() {
        var history = NavigationHistory<String>()
        history.navigate(to: "A")
        history.navigate(to: "A")
        XCTAssertFalse(history.canGoBack, "Re-selecting the current item should not push history.")
    }
}
