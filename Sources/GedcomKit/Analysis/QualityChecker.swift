//
// QualityChecker.swift — runs a list of pure data-quality rules over a document.
//
// Each rule is a small, independent function (GedcomDocument [+ index]) -> [Issue]. They COMPOSE:
// `issues(for:index:)` simply runs them all and concatenates. Keeping rules separate means each
// can be tested in isolation (fire only on its own synthetic trigger) and new rules drop in
// without touching the others.
//
// Date reasoning uses GedcomDate.sortKey (a decimal year), so approximate dates still participate
// sensibly. The age/lifespan thresholds are HEURISTICS for surfacing things worth a human's
// review — they are intentionally lenient (false positives are cheaper than missed errors here)
// and centralized as named constants so they're easy to tune.
//
// STUB (TDD red phase): `issues` returns nothing; rules are filled in one test at a time.
//

/// Runs all data-quality rules. Stateless caseless enum.
public enum QualityChecker {

    // MARK: Heuristic thresholds (years). Tunable; chosen to flag the implausible, not the rare.
    static let minParentAgeYears = 13.0
    static let maxParentAgeYears = 65.0
    static let maxLifespanYears = 120.0

    /// Tags that legitimately occur AT or AFTER death, so they don't count as "event after death".
    static let postmortemEventTags: Set<String> = ["DEAT", "BURI", "CREM", "PROB", "WILL"]

    /// Run every rule and return all issues found, in a stable rule-by-rule order. Individuals are
    /// visited in file order within each rule, so the overall output is deterministic.
    public static func issues(for document: GedcomDocument, index: RelationshipIndex) -> [Issue] {
        var all: [Issue] = []
        all += deathBeforeBirth(document)
        all += childBeforeParent(document, index)
        all += parentAge(document, index)            // emits parentTooYoung / parentTooOld
        all += implausibleLifespan(document)
        all += eventAfterDeath(document)
        all += missingBirthDate(document)
        all += brokenReference(document)
        all += possibleDuplicates(document)
        return all
    }

    // MARK: - Rules (each pure; each fires only on its own condition)

    /// deathBeforeBirth: an individual whose death sorts before their birth.
    static func deathBeforeBirth(_ document: GedcomDocument) -> [Issue] {
        document.allIndividuals.compactMap { person in
            guard let birth = person.birth?.date?.sortKey,
                  let death = person.death?.date?.sortKey, death < birth else { return nil }
            return Issue(category: .deathBeforeBirth, severity: .error,
                         message: "\(person.displayName): death (\(person.death?.date?.raw ?? "?")) is before birth (\(person.birth?.date?.raw ?? "?")).",
                         individuals: [person.id], sourceLineRange: person.node.sourceLineRange)
        }
    }

    /// childBeforeParent: a child whose birth sorts before a parent's birth.
    static func childBeforeParent(_ document: GedcomDocument, _ index: RelationshipIndex) -> [Issue] {
        var issues: [Issue] = []
        for child in document.allIndividuals {
            guard let childBirth = child.birth?.date?.sortKey else { continue }
            for parentID in index.parents(of: child.id) {
                guard let parent = document.individuals[parentID],
                      let parentBirth = parent.birth?.date?.sortKey, childBirth < parentBirth else { continue }
                issues.append(Issue(category: .childBeforeParent, severity: .error,
                    message: "\(child.displayName) (b. \(child.birth?.date?.raw ?? "?")) was born before parent \(parent.displayName) (b. \(parent.birth?.date?.raw ?? "?")).",
                    individuals: [child.id, parentID], sourceLineRange: child.node.sourceLineRange))
            }
        }
        return issues
    }

    /// parentTooYoung / parentTooOld: a parent implausibly young or old at a child's birth. (A
    /// negative age is reported by childBeforeParent instead, so we only consider age >= 0 here.)
    static func parentAge(_ document: GedcomDocument, _ index: RelationshipIndex) -> [Issue] {
        var issues: [Issue] = []
        for child in document.allIndividuals {
            guard let childBirth = child.birth?.date?.sortKey else { continue }
            for parentID in index.parents(of: child.id) {
                guard let parent = document.individuals[parentID],
                      let parentBirth = parent.birth?.date?.sortKey else { continue }
                let age = childBirth - parentBirth
                if age >= 0 && age < minParentAgeYears {
                    issues.append(Issue(category: .parentTooYoung, severity: .warning,
                        message: "\(parent.displayName) was only about \(Int(age)) at the birth of \(child.displayName).",
                        individuals: [parentID, child.id], sourceLineRange: parent.node.sourceLineRange))
                } else if age > maxParentAgeYears {
                    issues.append(Issue(category: .parentTooOld, severity: .warning,
                        message: "\(parent.displayName) was about \(Int(age)) at the birth of \(child.displayName).",
                        individuals: [parentID, child.id], sourceLineRange: parent.node.sourceLineRange))
                }
            }
        }
        return issues
    }

    /// implausibleLifespan: an individual who lived longer than `maxLifespanYears`.
    static func implausibleLifespan(_ document: GedcomDocument) -> [Issue] {
        document.allIndividuals.compactMap { person in
            guard let birth = person.birth?.date?.sortKey,
                  let death = person.death?.date?.sortKey, death - birth > maxLifespanYears else { return nil }
            return Issue(category: .implausibleLifespan, severity: .warning,
                         message: "\(person.displayName) has an implausible lifespan of about \(Int(death - birth)) years.",
                         individuals: [person.id], sourceLineRange: person.node.sourceLineRange)
        }
    }

    /// eventAfterDeath: a non-postmortem event dated after the individual's death.
    static func eventAfterDeath(_ document: GedcomDocument) -> [Issue] {
        var issues: [Issue] = []
        for person in document.allIndividuals {
            guard let death = person.death?.date?.sortKey else { continue }
            for event in person.events where !postmortemEventTags.contains(event.tag) {
                guard let when = event.date?.sortKey, when > death else { continue }
                issues.append(Issue(category: .eventAfterDeath, severity: .warning,
                    message: "\(person.displayName) has a \(event.tag) event (\(event.date?.raw ?? "?")) dated after their death (\(person.death?.date?.raw ?? "?")).",
                    individuals: [person.id], sourceLineRange: event.node.sourceLineRange))
            }
        }
        return issues
    }

    /// missingBirthDate: an individual with no usable birth date (no BIRT, or an unparseable one).
    static func missingBirthDate(_ document: GedcomDocument) -> [Issue] {
        document.allIndividuals.compactMap { person in
            guard person.birth?.date?.sortKey == nil else { return nil }
            return Issue(category: .missingBirthDate, severity: .info,
                         message: "\(person.displayName) has no usable birth date.",
                         individuals: [person.id], sourceLineRange: person.node.sourceLineRange)
        }
    }

    /// brokenReference: a relationship pointer that names a record which doesn't exist. Checks both
    /// family→person (HUSB/WIFE/CHIL) and person→family (FAMC/FAMS) directions.
    static func brokenReference(_ document: GedcomDocument) -> [Issue] {
        var issues: [Issue] = []
        for family in document.allFamilies {
            for personID in family.spouses + family.children where document.individuals[personID] == nil {
                issues.append(Issue(category: .brokenReference, severity: .error,
                    message: "Family \(family.id) references individual \(personID), which does not exist.",
                    individuals: [], sourceLineRange: family.node.sourceLineRange))
            }
        }
        for person in document.allIndividuals {
            for familyID in person.childInFamilies + person.spouseInFamilies where document.families[familyID] == nil {
                issues.append(Issue(category: .brokenReference, severity: .error,
                    message: "\(person.displayName) references family \(familyID), which does not exist.",
                    individuals: [person.id], sourceLineRange: person.node.sourceLineRange))
            }
        }
        return issues
    }

    /// possibleDuplicates: two individuals sharing surname + birth decade + given name. Bucketing
    /// by (surname, decade) first keeps this near-linear instead of comparing all pairs (O(n²)).
    static func possibleDuplicates(_ document: GedcomDocument) -> [Issue] {
        // Bucket key -> individuals sharing surname + birth decade.
        var buckets: [String: [Individual]] = [:]
        for person in document.allIndividuals {
            guard let surname = person.name?.surname?.lowercased(),
                  let birth = person.birth?.date?.sortKey else { continue }
            let decade = Int(birth / 10) * 10
            buckets["\(surname)|\(decade)", default: []].append(person)
        }

        var issues: [Issue] = []
        for (_, people) in buckets where people.count > 1 {
            // Within a bucket, flag pairs that also share a given name.
            for i in people.indices {
                for j in people.indices where j > i {
                    let a = people[i], b = people[j]
                    guard let ga = a.name?.given?.lowercased(), ga == b.name?.given?.lowercased() else { continue }
                    issues.append(Issue(category: .possibleDuplicate, severity: .info,
                        message: "\(a.displayName) and \(b.displayName) may be the same person.",
                        individuals: [a.id, b.id], sourceLineRange: nil))
                }
            }
        }
        return issues
    }
}
