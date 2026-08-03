import XCTest
@testable import Snapper

final class ProtocolAndBridgeTests: XCTestCase {

    func testBridgeIdentifiableIdsUseDomainKeys() {
        let date = Date(timeIntervalSince1970: 0)

        let order = OrderData(
            type: nil,
            sequenceId: 1,
            publicId: "order-1",
            timestamp: date,
            sessionId: "session-1",
            topic: nil,
            exchangeOrderId: nil,
            clientOrderId: "client-order-1",
            instrument: "BTCUSD",
            exchange: "kraken",
            mode: "paper",
            side: "buy",
            status: "open",
            orderType: "limit",
            size: 1.0,
            filledSize: 0.0,
            price: 10.0,
            averagePrice: nil,
            reason: nil,
            timeInForce: nil,
            error: nil,
            createdAt: date,
            updatedAt: nil,
            leverage: nil,
            reduceOnly: nil,
            walletPublicId: nil,
            operatorPublicId: nil,
            userPublicId: nil,
            planPublicId: nil,
            pairedGroupId: nil,
            pairedGroupSize: nil,
            pairedGroupIndex: nil,
            pairedGroupPolicy: nil
        )
        let position = PositionData(
            type: nil,
            sequenceId: 1,
            publicId: "position-1",
            timestamp: date,
            sessionId: "session-1",
            topic: nil,
            instrument: "BTCUSD",
            instrumentPublicId: nil,
            exchange: "kraken",
            mode: "paper",
            quantity: 1.0,
            averagePrice: 10.0,
            unrealizedPnl: 0.0,
            realizedPnl: 0.0,
            markPrice: nil,
            markedAt: nil,
            sourceVenueEventId: nil,
            positionCyclePublicId: nil,
            walletPublicId: nil
        )
        let signal = SignalData(
            type: nil,
            sequenceId: 1,
            publicId: "signal-1",
            timestamp: date,
            sessionId: "session-1",
            topic: nil,
            instrument: "BTCUSD",
            exchange: "kraken",
            side: "buy",
            strength: 0.9,
            reason: "fixture",
            price: nil,
            strategyName: nil,
            firedAt: date,
            walletPublicId: nil,
            operatorPublicId: nil,
            userPublicId: nil,
            aiReviewPublicId: nil,
            aiReviewDispatchVersion: nil,
            pairedGroupId: nil,
            pairedGroupSize: nil,
            pairedGroupIndex: nil,
            pairedGroupPolicy: nil,
            pairedGroupKey: nil,
            origin: nil,
            replayWindowStart: nil,
            replayWindowEnd: nil
        )
        let execution = ExecutionData(
            type: nil,
            sequenceId: 1,
            publicId: "execution-1",
            timestamp: date,
            sessionId: "session-1",
            topic: nil,
            tradeId: nil,
            exchangeOrderId: nil,
            clientOrderId: "client-execution-1",
            instrument: "BTCUSD",
            exchange: "kraken",
            side: "buy",
            size: 1.0,
            price: 10.0,
            lastSize: 1.0,
            lastPrice: 10.0,
            fee: 0.01,
            feeAsset: "USD",
            status: "filled",
            executedAt: date,
            walletPublicId: nil,
            operatorPublicId: nil,
            userPublicId: nil,
            liquidityRole: nil,
            pairedGroupId: nil,
            pairedGroupSize: nil,
            pairedGroupIndex: nil,
            pairedGroupPolicy: nil
        )
        let candle = CandleData(
            type: "candle",
            sequenceId: 1,
            publicId: "candle-1",
            timestamp: date,
            sessionId: "session-1",
            topic: nil,
            instrument: "BTCUSD",
            exchange: "kraken",
            timeframe: "1m",
            openAt: date,
            open: 10.0,
            high: 11.0,
            low: 9.0,
            close: 10.5,
            volume: 2.0,
            vwap: nil,
            trades: nil,
            complete: nil,
            origin: nil,
            replayWindowStart: nil,
            replayWindowEnd: nil
        )

        XCTAssertEqual(order.id, "order-1")
        XCTAssertEqual(position.id, "position-1")
        XCTAssertEqual(signal.id, "signal-1")
        XCTAssertEqual(execution.id, "execution-1")
        XCTAssertEqual(candle.id, "candle-1")
    }

    func testURLSessionWebSocketTaskFactoryCreatesTask() {
        let session = URLSession(configuration: .ephemeral)
        let factory = URLSessionWebSocketTaskFactory(session: session)
        let request = URLRequest(url: URL(string: "ws://localhost:8000/api/ws")!)

        let task = factory.makeTask(request: request)

        XCTAssertTrue(task is URLSessionWebSocketTask)
        task.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }

    func testTaskSleeperAcceptsZeroDelay() async throws {
        try await TaskSleeper().sleep(seconds: 0)
    }
}
