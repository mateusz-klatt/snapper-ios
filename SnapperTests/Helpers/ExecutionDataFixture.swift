import Foundation
@testable import Snapper

/// Test fixture for ``ExecutionData``. Default values render a realistic
/// market-fill execution; named arguments override individual fields.
extension ExecutionData {
    static func fixture(
        clientOrderId: String = "test-coid-001",
        instrument: String = "BTC-USD",
        exchange: String = "kraken",
        side: String = "buy",
        size: Double = 0.05,
        price: Double = 97_840.0,
        publicId: String = "00000000-0000-0000-0000-000000000002",
        sequenceId: Int = 1
    ) -> ExecutionData {
        return ExecutionData(
            type: "execution",
            sequenceId: sequenceId,
            publicId: publicId,
            timestamp: Date(timeIntervalSince1970: 1_715_000_000),
            sessionId: "test-session",
            topic: nil,
            tradeId: "T-001",
            exchangeOrderId: "EX-001",
            clientOrderId: clientOrderId,
            instrument: instrument,
            exchange: exchange,
            side: side,
            size: size,
            price: price,
            lastSize: size,
            lastPrice: price,
            fee: 0.0,
            feeAsset: "USD",
            status: "filled",
            executedAt: Date(timeIntervalSince1970: 1_715_000_000),
            walletPublicId: nil,
            operatorPublicId: nil,
            userPublicId: nil,
            liquidityRole: nil
        )
    }
}
