import Foundation

extension CachedCandle {

    /// Normalize a ``CachedCandle`` (the cache-warming endpoint's
    /// candle row) into ``MarketCandle`` so the metrics surface can
    /// reuse all the existing chart / metric code paths that already
    /// consume ``MarketCandle``.
    ///
    /// Precision: uses ``Decimal(string: String(describing: value))``
    /// for every OHLCV field, matching the existing
    /// ``MarketCandle.from(wsCandleData:)`` pattern. Going through the
    /// string round-trip avoids the binary-float error
    /// ``Decimal(_:Double)`` would introduce. Returns ``nil`` on any
    /// unparseable input (NaN / Infinity / malformed value) so caller
    /// can drop the offending row without aborting the whole snapshot.
    ///
    /// Field absence:
    /// - ``vwap`` and ``trades`` are NOT present on the cache-warming
    ///   payload; the conversion sets both to ``nil``. The metrics
    ///   computation tolerates that — only ``open`` / ``high`` /
    ///   ``low`` / ``close`` / ``volume`` participate in 24h
    ///   high / low / change% calculation.
    func toMarketCandle() -> MarketCandle? {
        guard
            let openDec = Decimal(string: String(describing: self.open)),
            let highDec = Decimal(string: String(describing: self.high)),
            let lowDec = Decimal(string: String(describing: self.low)),
            let closeDec = Decimal(string: String(describing: self.close)),
            let volumeDec = Decimal(string: String(describing: self.volume))
        else {
            return nil
        }
        return MarketCandle(
            openAt: Date(timeIntervalSince1970: TimeInterval(self.openAtMs) / 1000),
            open: openDec,
            high: highDec,
            low: lowDec,
            close: closeDec,
            volume: volumeDec,
            vwap: nil,
            trades: nil
        )
    }
}
