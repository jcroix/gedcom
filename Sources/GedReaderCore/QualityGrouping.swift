//
// QualityGrouping.swift — organize quality issues for the Quality UI (A6).
//
// The Quality section groups issues by category (each category has a fixed severity), shows a count
// per group, and orders groups by severity so the most serious problems (errors) surface first, then
// warnings, then info. This grouping is the testable part; the SwiftUI view just renders the groups
// and, on click, navigates to the issue's involved person.
//
// STUB (TDD red phase): returns nothing until the test drives it.
//

import GedcomKit

/// Issues of one category, with their shared severity, for display as a collapsible group.
public struct IssueGroup: Identifiable, Sendable, Equatable {
    public let category: Issue.Category
    public let severity: Diagnostic.Severity
    public let issues: [Issue]
    public var count: Int { issues.count }
    public var id: Issue.Category { category }
}

public enum QualityGrouping {

    /// Group issues by category and order the groups by severity (errors, then warnings, then info),
    /// breaking ties by category name so the order is stable.
    public static func groups(_ issues: [Issue]) -> [IssueGroup] {
        // Bucket by category (preserving each issue's order within its bucket).
        var byCategory: [Issue.Category: [Issue]] = [:]
        for issue in issues { byCategory[issue.category, default: []].append(issue) }

        return byCategory.map { category, categoryIssues in
            // Every issue in a category shares a severity (rules have fixed severity); use the first.
            IssueGroup(category: category, severity: categoryIssues[0].severity, issues: categoryIssues)
        }
        .sorted { a, b in
            let (ra, rb) = (rank(a.severity), rank(b.severity))
            return ra != rb ? ra < rb : a.category.rawValue < b.category.rawValue
        }
    }

    /// Severity ordering for display: lower sorts first (errors at the top).
    static func rank(_ severity: Diagnostic.Severity) -> Int {
        switch severity {
        case .error: return 0
        case .warning: return 1
        case .info: return 2
        }
    }
}

extension Issue.Category {
    /// Human-readable title for the Quality UI (lives in the logic layer to keep the engine UI-free).
    public var displayTitle: String {
        switch self {
        case .childBeforeParent: return "Child born before parent"
        case .deathBeforeBirth: return "Death before birth"
        case .parentTooYoung: return "Parent too young"
        case .parentTooOld: return "Parent too old"
        case .implausibleLifespan: return "Implausible lifespan"
        case .eventAfterDeath: return "Event after death"
        case .missingBirthDate: return "Missing birth date"
        case .brokenReference: return "Broken reference"
        case .possibleDuplicate: return "Possible duplicate"
        }
    }
}
