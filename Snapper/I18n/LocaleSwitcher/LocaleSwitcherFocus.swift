import Foundation

/// Pure helper for ``LocaleSwitcher`` keyboard navigation. Walks the
/// 3×15 flag grid in cardinal directions; vertical movement stays
/// column-aligned (or clamps to the row's last column when the
/// target row is shorter, though all three rows are 15 wide today).
/// Returns ``nil`` when the move would leave the grid — callers
/// surface this as `.ignored` so the default key handler runs.
///
/// Extracted as a pure function so the routing table is unit
/// testable without rendering the SwiftUI body (the repo pattern
/// from ``MainTabView/routeDeepLink(...)``).
enum LocaleSwitcherFocus {

    /// Grid layout — row index in `[0, 3)`, column index in `[0, 15)`.
    static let rows: [[AppLocale]] = [
        AppLocale.row1,
        AppLocale.row2,
        AppLocale.row3,
    ]

    /// (row, column) coordinate of `code` within the grid, or
    /// ``nil`` if the code is somehow not in any row (should never
    /// happen with the locked 45-code set, but the optional return
    /// keeps the caller honest).
    static func position(of code: AppLocale) -> (row: Int, col: Int)? {
        for (r, row) in rows.enumerated() {
            if let c = row.firstIndex(of: code) {
                return (r, c)
            }
        }
        return nil
    }

    /// Next focus target after walking by ``delta`` along the axis
    /// specified by ``vertical``. Returns ``nil`` when the move
    /// would go off the grid.
    static func next(from current: AppLocale, by delta: Int, vertical: Bool) -> AppLocale? {
        guard let (r, c) = position(of: current) else { return nil }
        if vertical {
            let newRow = r + delta
            guard newRow >= 0, newRow < rows.count else { return nil }
            let row = rows[newRow]
            let newCol = min(c, row.count - 1)
            return row[newCol]
        }
        let newCol = c + delta
        guard newCol >= 0, newCol < rows[r].count else { return nil }
        return rows[r][newCol]
    }
}
