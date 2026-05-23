//
// RelationshipPhrasingTests.swift — sentence wording for relationship results.
//

import XCTest
@testable import GedReaderCore

final class RelationshipPhrasingTests: XCTestCase {

    func testNormalRelationshipReadsAsSentence() {
        XCTAssertEqual(RelationshipPhrasing.sentence(subject: "Henry", base: "John", label: "son"),
                       "Henry is the son of John.")
    }

    func testNotRelatedHasFriendlyWording() {
        XCTAssertEqual(RelationshipPhrasing.sentence(subject: "Henry", base: "Jane", label: "no known connection"),
                       "Henry and Jane are not related.")
    }

    func testSamePersonHasFriendlyWording() {
        XCTAssertEqual(RelationshipPhrasing.sentence(subject: "John", base: "John", label: "same person"),
                       "John and John are the same person.")
    }
}
