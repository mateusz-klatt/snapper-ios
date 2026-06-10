import Foundation

/// Tracks whether bidirectional i18n catalog parity is enforced. Single
/// source of truth for the catalog parity gate.
///
/// When ``true``,
/// ``CatalogParityTests.testEveryExpectedKeyAppearsInCatalog`` asserts
/// that every key in ``ExpectedKeys.values`` is present in
/// ``Localizable.xcstrings`` (in addition to the always-on
/// catalog ⊆ ExpectedKeys assertion).
///
/// The strict-mode multi-pattern SwiftUI literal lint
/// (``scripts/check_i18n_strict.sh``) is a separate gate. The v1
/// single-pattern lint (``scripts/check_i18n.sh``) stays the active CI
/// guard until every raw ``Text(...)`` callsite has migrated.
enum PhaseHRolloutStatus {

    static let isComplete: Bool = true
}
