import Foundation

/// Supported chart timeframes for the Market Data screen.
///
/// The raw values match the backend's `timeframe` query parameter
/// shape (e.g. `?timeframe=1m`) and the WS topic suffix
/// (`market.{exchange}.{instrument}.candles.{timeframe}`).
enum MarketTimeframe: String, CaseIterable, Identifiable, Sendable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case oneHour = "1h"
    case fourHours = "4h"
    case oneDay = "1d"

    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
}

/// iOS-normalized candle. Storage is ``Decimal`` to avoid the
/// binary-float noise that ``Decimal(_: Double)`` carries.
///
/// REST `/candles` rows and WS `market.*.candles.*` frames both
/// arrive as ``CandleData`` (the generated WS type at
/// ``Models/Generated/WSMessages.swift``) — a single conversion
/// path keeps the two sources aligned.
struct MarketCandle: Identifiable, Equatable, Sendable {
    let openAt: Date
    let open: Decimal
    let high: Decimal
    let low: Decimal
    let close: Decimal
    let volume: Decimal
    let vwap: Decimal?
    let trades: Int?

    var id: Date { openAt }
}

extension MarketCandle {
    /// Normalize a ``CandleData`` (REST envelope row or WS frame)
    /// into ``MarketCandle``. Uses ``Decimal(string:)`` with
    /// ``String(describing:)`` to avoid the binary-float
    /// representation error that ``Decimal.init(_: Double)``
    /// silently carries. Returns ``nil`` if any required field
    /// fails to parse.
    static func from(wsCandleData data: CandleData) -> MarketCandle? {
        guard
            let open = Decimal(string: String(describing: data.open)),
            let high = Decimal(string: String(describing: data.high)),
            let low = Decimal(string: String(describing: data.low)),
            let close = Decimal(string: String(describing: data.close)),
            let volume = Decimal(string: String(describing: data.volume))
        else { return nil }
        let vwap: Decimal? = data.vwap.flatMap { Decimal(string: String(describing: $0)) }
        return MarketCandle(
            openAt: data.openAt,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            vwap: vwap,
            trades: data.trades
        )
    }
}

/// Single source of truth for market WS topic strings.
///
/// Format mirrors the backend ZMQ pattern
/// `market.{exchange}.{instrument}.{type}` — see the topic
/// registry in `src/snapper/messaging/topics/schemas.py`. The
/// exchange and instrument segments are passed verbatim; the
/// backend's topic router does the matching.
enum MarketTopic {
    static func candle(
        exchange: String,
        instrument: String,
        timeframe: MarketTimeframe
    ) -> String {
        "market.\(exchange).\(instrument).candles.\(timeframe.rawValue)"
    }

    static func tick(exchange: String, instrument: String) -> String {
        "market.\(exchange).\(instrument).ticks"
    }
}

/// Snapshot of market-data KPIs displayed in the 2x2 metric grid.
///
/// 24-hour metrics derive from a separate `?timeframe=1h&limit=25`
/// candle fetch so the values stay consistent regardless of the
/// chart's currently-selected timeframe.
struct MarketMetrics: Equatable, Sendable {
    let lastPrice: Decimal?
    let changePct24h: Decimal?
    let high24h: Decimal?
    let low24h: Decimal?
    let isDelayed: Bool

    static let empty = MarketMetrics(
        lastPrice: nil,
        changePct24h: nil,
        high24h: nil,
        low24h: nil,
        isDelayed: false
    )
}
