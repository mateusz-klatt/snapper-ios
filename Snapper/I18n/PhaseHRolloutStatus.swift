import Foundation

/// Tracks the i18n Phase H rollout state. Single source of truth for
/// gates that need to deactivate during the multi-phase migration and
/// activate at completion:
/// - ``CatalogParityTests.testEveryExpectedKeyAppearsInCatalog`` —
///   strict bidirectional catalog parity activates here.
/// - ``ios-i18n-check`` strict-mode lint (``check_i18n_strict.sh``) —
///   the multi-pattern SwiftUI literal scan wired into
///   ``check-all`` activates at the same time.
///
/// Flip to ``true`` in the final Phase J commit when every catalog
/// key has shipped and every view callsite has migrated.
enum PhaseHRolloutStatus {

    static let isComplete: Bool = false
}
