//
// QualityGroupingTests.swift — grouping/ordering quality issues for the Quality section.
//

import XCTest
@testable import GedReaderCore
import GedcomKit

final class QualityGroupingTests: XCTestCase {

    private func issue(_ category: Issue.Category, _ severity: Diagnostic.Severity) -> Issue {
        Issue(category: category, severity: severity, message: "", individuals: [Xref("@I1@")])
    }

    /// Groups collapse by category, count per group, ordered errors → warnings → info.
    func testGroupsByCategoryOrderedBySeverity() {
        let issues = [
            issue(.missingBirthDate, .info),
            issue(.deathBeforeBirth, .error),
            issue(.parentTooYoung, .warning),
            issue(.missingBirthDate, .info),
            issue(.deathBeforeBirth, .error),
        ]
        let groups = QualityGrouping.groups(issues)

        XCTAssertEqual(groups.map(\.category), [.deathBeforeBirth, .parentTooYoung, .missingBirthDate])
        XCTAssertEqual(groups.first?.count, 2)            // two deathBeforeBirth
        XCTAssertEqual(groups.first?.severity, .error)
        XCTAssertEqual(groups.last?.count, 2)             // two missingBirthDate
    }

    func testEmptyIssuesProduceNoGroups() {
        XCTAssertTrue(QualityGrouping.groups([]).isEmpty)
    }
}
