import Foundation

typealias OrderStatus = OrderData
typealias PositionSnapshot = PositionData
typealias TradingSignal = SignalData
typealias ExecutionRecord = ExecutionData
typealias CandleEnvelope = CandleData
typealias SystemStatus = SystemStatusData

extension OrderData: Identifiable {
    var id: String { publicId }
}

extension PositionData: Identifiable {
    var id: String { publicId }
}

extension SignalData: Identifiable {
    var id: String { publicId }
}

extension ExecutionData: Identifiable {
    var id: String { publicId }
}

extension CandleData: Identifiable {
    var id: String { publicId }
}
