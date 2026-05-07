import Foundation
@testable import Snapper

/// Test fixture for ``OrderEventData``. Default values exercise the
/// happy path; named arguments override individual fields.
extension OrderEventData {
    static func fixture(
        clientOrderId: String = "test-coid-001",
        instrument: String = "BTC-USD",
        event: String = "submitted",
        exchange: String = "kraken",
        publicId: String = "00000000-0000-0000-0000-000000000001",
        sequenceId: Int = 1
    ) -> OrderEventData {
        return OrderEventData(
            type: "order_event",
            sequenceId: sequenceId,
            publicId: publicId,
            timestamp: Date(timeIntervalSince1970: 1_715_000_000),
            sessionId: "test-session",
            topic: nil,
            exchangeOrderId: "EX-001",
            clientOrderId: clientOrderId,
            exchange: exchange,
            instrument: instrument,
            event: event,
            reason: nil,
            walletPublicId: nil,
            operatorPublicId: nil,
            userPublicId: nil
        )
    }
}
