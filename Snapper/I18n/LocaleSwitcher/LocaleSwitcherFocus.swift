import Foundation

/// Pure helper for ``LocaleSwitcher`` keyboard navigation. Walks
/// the 15×3 transposed flag-and-name grid in cardinal directions;
/// vertical movement steps one row (15 visible rows), horizontal
/// movement steps one column (3 visible columns). Returns ``nil``
/// when the move would leave the grid — callers surface this as
/// ``.ignored`` so the default key handler runs.
///
/// The grid is the mathematical transpose of ``AppLocale``'s
/// semantic ``row1`` / ``row2`` / ``row3`` blocks: column 0 is
/// the Western-Europe + Americas block laid out top-to-bottom,
/// column 1 the Asia + Middle-East block, column 2 the CEE +
/// Balkans + Caucasus block. The transposition exists because the
/// previous 3-rows-of-15 layout did not fit any iPhone width
/// without horizontal scrolling, which hid columns 3+ from any
/// user who did not discover the scroll affordance.
///
/// Extracted as a pure function so the routing table is unit
/// testable without rendering the SwiftUI body (the repo pattern
/// from ``MainTabView/routeDeepLink(...)``).
enum LocaleSwitcherFocus {

    /// Number of visible rows in the transposed grid. Locked at 15
    /// — every semantic row in ``AppLocale`` has exactly 15 entries.
    static let rowCount = 15

    /// Number of visible columns in the transposed grid. Locked at
    /// 3 — one per ``AppLocale`` semantic row.
    static let columnCount = 3

    /// Transposed grid layout — row index in ``[0, rowCount)``,
    /// column index in ``[0, columnCount)``. ``rows[r][c]`` returns
    /// the code at visual row ``r``, column ``c``. The columns are
    /// the original ``row1``/``row2``/``row3`` blocks laid out
    /// top-to-bottom.
    static let rows: [[AppLocale]] = {
        let columns = [AppLocale.row1, AppLocale.row2, AppLocale.row3]
        return (0..<rowCount).map { rowIdx in
            columns.map { col in col[rowIdx] }
        }
    }()

    /// ``(row, column)`` coordinate of ``code`` within the
    /// transposed grid, or ``nil`` if the code is not present
    /// (should never happen with the locked 45-code set, but the
    /// optional return keeps the caller honest).
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
    /// would go off the grid (no wrap-around). Off-axis movement
    /// stays in the same row or column, so column-aligned scans
    /// across regional blocks remain stable as the user pages
    /// vertically through the picker.
    static func next(from current: AppLocale, by delta: Int, vertical: Bool) -> AppLocale? {
        guard let (r, c) = position(of: current) else { return nil }
        if vertical {
            let newRow = r + delta
            guard newRow >= 0, newRow < rows.count else { return nil }
            return rows[newRow][c]
        }
        let newCol = c + delta
        guard newCol >= 0, newCol < rows[r].count else { return nil }
        return rows[r][newCol]
    }
}
