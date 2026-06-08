// This file was auto-generated from backend schemas.
// DO NOT EDIT - regenerate with: make ios-gen-types

import Foundation

enum AlertEventDataAlertType: String, Codable, Sendable {
    case orderFillFull = "order_fill_full"
    case orderRejected = "order_rejected"
    case positionStopLossFired = "position_stop_loss_fired"
    case marginWarning = "margin_warning"
    case criticalSystemError = "critical_system_error"
}

enum AlertEventDataPriority: String, Codable, Sendable {
    case low
    case medium
    case high
}

enum BacktestProgressDataEvent: String, Codable, Sendable {
    case started
    case progress
    case milestone
    case completed
    case failed
    case cancelled
}

enum FundingAccrualDataExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum FundingAccrualDataMode: String, Codable, Sendable {
    case live
    case paper
}

enum FundingAccrualDataAccrualType: String, Codable, Sendable {
    case funding
    case rollover
    case borrow
}

enum HeartbeatDataStatus: String, Codable, Sendable {
    case healthy
    case warning
    case error
}

enum OrderCancelDataExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum OrderEventDataExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum OrderEventDataEvent: String, Codable, Sendable {
    case submitted
    case accepted
    case rejected
    case cancelled
    case expired
    case replaced
}

enum OrderReplaceDataExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum OrderRequestDataExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum OrderRequestDataMode: String, Codable, Sendable {
    case live
    case paper
}

enum OrderRequestDataSide: String, Codable, Sendable {
    case buy
    case sell
}

enum OrderRequestDataOrderType: String, Codable, Sendable {
    case market
    case limit
    case stop
    case stopLimit = "stop_limit"
}

enum ScopeGrantedDataScopeKind: String, Codable, Sendable {
    case underlying
    case instrument
}

enum ScopeHandedOverDataScopeKind: String, Codable, Sendable {
    case underlying
    case instrument
}

enum ScopeRevokedDataScopeKind: String, Codable, Sendable {
    case underlying
    case instrument
}

enum TickDataExchange: String, Codable, Sendable {
    case kraken
    case krakenFutures = "kraken_futures"
    case krakenEquities = "kraken_equities"
    case walutomat
    case polygon
}

enum TradeDataExchange: String, Codable, Sendable {
    case kraken
    case krakenFutures = "kraken_futures"
    case krakenEquities = "kraken_equities"
    case walutomat
    case polygon
}

enum WSSubscriptionSuccessResponseAction: String, Codable, Sendable {
    case subscribe
    case unsubscribe
}

enum WSSubscriptionSuccessResponseStatus: String, Codable, Sendable {
    case subscribed
    case unsubscribed
    case partial
    case denied
    case noTopics = "no_topics"
}

struct WsMessageBase: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
    }
}

struct AiReviewCapsViolationFrameData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let reviewPublicId: String
    let userPublicId: String
    let strategyPublicId: String
    let walletPublicId: String
    let instrumentPublicId: String
    let capType: String
    let attempted: Double
    let limit: Double
    let dispatchVersion: Int

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        reviewPublicId: String,
        userPublicId: String,
        strategyPublicId: String,
        walletPublicId: String,
        instrumentPublicId: String,
        capType: String,
        attempted: Double,
        limit: Double,
        dispatchVersion: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.reviewPublicId = reviewPublicId
        self.userPublicId = userPublicId
        self.strategyPublicId = strategyPublicId
        self.walletPublicId = walletPublicId
        self.instrumentPublicId = instrumentPublicId
        self.capType = capType
        self.attempted = attempted
        self.limit = limit
        self.dispatchVersion = dispatchVersion
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case reviewPublicId = "review_public_id"
        case userPublicId = "user_public_id"
        case strategyPublicId = "strategy_public_id"
        case walletPublicId = "wallet_public_id"
        case instrumentPublicId = "instrument_public_id"
        case capType = "cap_type"
        case attempted
        case limit
        case dispatchVersion = "dispatch_version"
    }
}

struct AiReviewDecisionAckFrameData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let reviewPublicId: String
    let userPublicId: String
    let strategyPublicId: String
    let walletPublicId: String
    let instrumentPublicId: String
    let respondingDelegatePublicId: String
    let decision: String
    let newStatus: String
    let resolutionMode: String
    let rationale: String?
    let dispatchVersion: Int

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        reviewPublicId: String,
        userPublicId: String,
        strategyPublicId: String,
        walletPublicId: String,
        instrumentPublicId: String,
        respondingDelegatePublicId: String,
        decision: String,
        newStatus: String,
        resolutionMode: String,
        rationale: String?,
        dispatchVersion: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.reviewPublicId = reviewPublicId
        self.userPublicId = userPublicId
        self.strategyPublicId = strategyPublicId
        self.walletPublicId = walletPublicId
        self.instrumentPublicId = instrumentPublicId
        self.respondingDelegatePublicId = respondingDelegatePublicId
        self.decision = decision
        self.newStatus = newStatus
        self.resolutionMode = resolutionMode
        self.rationale = rationale
        self.dispatchVersion = dispatchVersion
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case reviewPublicId = "review_public_id"
        case userPublicId = "user_public_id"
        case strategyPublicId = "strategy_public_id"
        case walletPublicId = "wallet_public_id"
        case instrumentPublicId = "instrument_public_id"
        case respondingDelegatePublicId = "responding_delegate_public_id"
        case decision
        case newStatus = "new_status"
        case resolutionMode = "resolution_mode"
        case rationale
        case dispatchVersion = "dispatch_version"
    }
}

struct AiReviewDecisionData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let reviewPublicId: String
    let respondingDelegatePublicId: String
    let decision: String
    let newStatus: String
    let resolutionMode: String
    let dispatchVersion: Int

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        reviewPublicId: String,
        respondingDelegatePublicId: String,
        decision: String,
        newStatus: String,
        resolutionMode: String,
        dispatchVersion: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.reviewPublicId = reviewPublicId
        self.respondingDelegatePublicId = respondingDelegatePublicId
        self.decision = decision
        self.newStatus = newStatus
        self.resolutionMode = resolutionMode
        self.dispatchVersion = dispatchVersion
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case reviewPublicId = "review_public_id"
        case respondingDelegatePublicId = "responding_delegate_public_id"
        case decision
        case newStatus = "new_status"
        case resolutionMode = "resolution_mode"
        case dispatchVersion = "dispatch_version"
    }
}

struct AiReviewRequestFrameData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let reviewPublicId: String
    let userPublicId: String
    let strategyPublicId: String
    let walletPublicId: String
    let instrumentPublicId: String
    let selectedDelegatePublicId: String
    let deadline: Date
    let signalEnvelope: JsonObject
    let instrumentMetadata: JsonObject
    let dispatchVersion: Int

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        reviewPublicId: String,
        userPublicId: String,
        strategyPublicId: String,
        walletPublicId: String,
        instrumentPublicId: String,
        selectedDelegatePublicId: String,
        deadline: Date,
        signalEnvelope: JsonObject,
        instrumentMetadata: JsonObject,
        dispatchVersion: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.reviewPublicId = reviewPublicId
        self.userPublicId = userPublicId
        self.strategyPublicId = strategyPublicId
        self.walletPublicId = walletPublicId
        self.instrumentPublicId = instrumentPublicId
        self.selectedDelegatePublicId = selectedDelegatePublicId
        self.deadline = deadline
        self.signalEnvelope = signalEnvelope
        self.instrumentMetadata = instrumentMetadata
        self.dispatchVersion = dispatchVersion
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case reviewPublicId = "review_public_id"
        case userPublicId = "user_public_id"
        case strategyPublicId = "strategy_public_id"
        case walletPublicId = "wallet_public_id"
        case instrumentPublicId = "instrument_public_id"
        case selectedDelegatePublicId = "selected_delegate_public_id"
        case deadline
        case signalEnvelope = "signal_envelope"
        case instrumentMetadata = "instrument_metadata"
        case dispatchVersion = "dispatch_version"
    }
}

struct AlertEventData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let userPublicId: String
    let operatorPublicId: String?
    let walletPublicId: String?
    let alertType: String
    let priority: String?
    let isSafetyCritical: Bool?
    let title: String
    let body: String
    let payload: JsonObject?
    let dedupKey: String?
    let threadKey: String?
    let sourceTopic: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        userPublicId: String,
        operatorPublicId: String? = nil,
        walletPublicId: String? = nil,
        alertType: String,
        priority: String? = nil,
        isSafetyCritical: Bool? = nil,
        title: String,
        body: String,
        payload: JsonObject? = nil,
        dedupKey: String? = nil,
        threadKey: String? = nil,
        sourceTopic: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.userPublicId = userPublicId
        self.operatorPublicId = operatorPublicId
        self.walletPublicId = walletPublicId
        self.alertType = alertType
        self.priority = priority
        self.isSafetyCritical = isSafetyCritical
        self.title = title
        self.body = body
        self.payload = payload
        self.dedupKey = dedupKey
        self.threadKey = threadKey
        self.sourceTopic = sourceTopic
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case userPublicId = "user_public_id"
        case operatorPublicId = "operator_public_id"
        case walletPublicId = "wallet_public_id"
        case alertType = "alert_type"
        case priority
        case isSafetyCritical = "is_safety_critical"
        case title
        case body
        case payload
        case dedupKey = "dedup_key"
        case threadKey = "thread_key"
        case sourceTopic = "source_topic"
    }
}

struct BacktestProgressData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let runPublicId: String
    let walletPublicId: String
    let event: String
    let milestone: String?
    let candlesDone: Int
    let totalCandles: Int?
    let signalsCount: Int
    let tradesCount: Int
    let equity: Double
    let progressPct: Double

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        runPublicId: String,
        walletPublicId: String,
        event: String,
        milestone: String? = nil,
        candlesDone: Int,
        totalCandles: Int?,
        signalsCount: Int,
        tradesCount: Int,
        equity: Double,
        progressPct: Double
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.runPublicId = runPublicId
        self.walletPublicId = walletPublicId
        self.event = event
        self.milestone = milestone
        self.candlesDone = candlesDone
        self.totalCandles = totalCandles
        self.signalsCount = signalsCount
        self.tradesCount = tradesCount
        self.equity = equity
        self.progressPct = progressPct
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case runPublicId = "run_public_id"
        case walletPublicId = "wallet_public_id"
        case event
        case milestone
        case candlesDone = "candles_done"
        case totalCandles = "total_candles"
        case signalsCount = "signals_count"
        case tradesCount = "trades_count"
        case equity
        case progressPct = "progress_pct"
    }
}

struct CapsViolationAfterAiApproveData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let reviewPublicId: String
    let userPublicId: String
    let strategyPublicId: String
    let walletPublicId: String
    let instrumentPublicId: String
    let capType: String
    let attempted: Double
    let limit: Double
    let dispatchVersion: Int

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        reviewPublicId: String,
        userPublicId: String,
        strategyPublicId: String,
        walletPublicId: String,
        instrumentPublicId: String,
        capType: String,
        attempted: Double,
        limit: Double,
        dispatchVersion: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.reviewPublicId = reviewPublicId
        self.userPublicId = userPublicId
        self.strategyPublicId = strategyPublicId
        self.walletPublicId = walletPublicId
        self.instrumentPublicId = instrumentPublicId
        self.capType = capType
        self.attempted = attempted
        self.limit = limit
        self.dispatchVersion = dispatchVersion
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case reviewPublicId = "review_public_id"
        case userPublicId = "user_public_id"
        case strategyPublicId = "strategy_public_id"
        case walletPublicId = "wallet_public_id"
        case instrumentPublicId = "instrument_public_id"
        case capType = "cap_type"
        case attempted
        case limit
        case dispatchVersion = "dispatch_version"
    }
}

struct DelegateOfflineData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let userPublicId: String
    let delegatePublicId: String
    let lastSeenAt: Date

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        userPublicId: String,
        delegatePublicId: String,
        lastSeenAt: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.userPublicId = userPublicId
        self.delegatePublicId = delegatePublicId
        self.lastSeenAt = lastSeenAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case userPublicId = "user_public_id"
        case delegatePublicId = "delegate_public_id"
        case lastSeenAt = "last_seen_at"
    }
}

struct ExecutionPlanDecisionEventData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let decisionPublicId: String
    let planPublicId: String
    let decisionType: String
    let triggerType: String
    let reason: String
    let triggeredAt: Date

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        decisionPublicId: String,
        planPublicId: String,
        decisionType: String,
        triggerType: String,
        reason: String,
        triggeredAt: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.decisionPublicId = decisionPublicId
        self.planPublicId = planPublicId
        self.decisionType = decisionType
        self.triggerType = triggerType
        self.reason = reason
        self.triggeredAt = triggeredAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case decisionPublicId = "decision_public_id"
        case planPublicId = "plan_public_id"
        case decisionType = "decision_type"
        case triggerType = "trigger_type"
        case reason
        case triggeredAt = "triggered_at"
    }
}

struct FundingAccrualData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrument: String
    let exchange: String
    let mode: String
    let accrualType: String
    let accruedAt: Date
    let amount: Double
    let amountAsset: String
    let rate: Double
    let notional: Double
    let positionQuantity: Double

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrument: String,
        exchange: String,
        mode: String,
        accrualType: String,
        accruedAt: Date,
        amount: Double,
        amountAsset: String,
        rate: Double,
        notional: Double,
        positionQuantity: Double
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrument = instrument
        self.exchange = exchange
        self.mode = mode
        self.accrualType = accrualType
        self.accruedAt = accruedAt
        self.amount = amount
        self.amountAsset = amountAsset
        self.rate = rate
        self.notional = notional
        self.positionQuantity = positionQuantity
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrument
        case exchange
        case mode
        case accrualType = "accrual_type"
        case accruedAt = "accrued_at"
        case amount
        case amountAsset = "amount_asset"
        case rate
        case notional
        case positionQuantity = "position_quantity"
    }
}

struct HeartbeatData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let component: String
    let sequence: Int
    let status: String
    let lagMs: Int
    let meta: JsonObject?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        component: String,
        sequence: Int,
        status: String,
        lagMs: Int,
        meta: JsonObject? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.component = component
        self.sequence = sequence
        self.status = status
        self.lagMs = lagMs
        self.meta = meta
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case component
        case sequence
        case status
        case lagMs = "lag_ms"
        case meta
    }
}

struct OrderCancelData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let exchange: String
    let instrument: String
    let exchangeOrderId: String
    let clientOrderId: String
    let walletPublicId: String?
    let operatorPublicId: String?
    let userPublicId: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        exchange: String,
        instrument: String,
        exchangeOrderId: String,
        clientOrderId: String,
        walletPublicId: String? = nil,
        operatorPublicId: String? = nil,
        userPublicId: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.exchange = exchange
        self.instrument = instrument
        self.exchangeOrderId = exchangeOrderId
        self.clientOrderId = clientOrderId
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.userPublicId = userPublicId
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case exchange
        case instrument
        case exchangeOrderId = "exchange_order_id"
        case clientOrderId = "client_order_id"
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case userPublicId = "user_public_id"
    }
}

struct OrderEventData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let exchangeOrderId: String
    let clientOrderId: String
    let exchange: String
    let instrument: String
    let event: String
    let reason: String?
    let walletPublicId: String?
    let operatorPublicId: String?
    let userPublicId: String?
    let pairedGroupId: String?
    let pairedGroupSize: Int?
    let pairedGroupIndex: Int?
    let pairedGroupPolicy: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        exchangeOrderId: String,
        clientOrderId: String,
        exchange: String,
        instrument: String,
        event: String,
        reason: String? = nil,
        walletPublicId: String? = nil,
        operatorPublicId: String? = nil,
        userPublicId: String? = nil,
        pairedGroupId: String? = nil,
        pairedGroupSize: Int? = nil,
        pairedGroupIndex: Int? = nil,
        pairedGroupPolicy: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.exchangeOrderId = exchangeOrderId
        self.clientOrderId = clientOrderId
        self.exchange = exchange
        self.instrument = instrument
        self.event = event
        self.reason = reason
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.userPublicId = userPublicId
        self.pairedGroupId = pairedGroupId
        self.pairedGroupSize = pairedGroupSize
        self.pairedGroupIndex = pairedGroupIndex
        self.pairedGroupPolicy = pairedGroupPolicy
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case exchangeOrderId = "exchange_order_id"
        case clientOrderId = "client_order_id"
        case exchange
        case instrument
        case event
        case reason
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case userPublicId = "user_public_id"
        case pairedGroupId = "paired_group_id"
        case pairedGroupSize = "paired_group_size"
        case pairedGroupIndex = "paired_group_index"
        case pairedGroupPolicy = "paired_group_policy"
    }
}

struct OrderReplaceData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let exchange: String
    let instrument: String
    let exchangeOrderId: String
    let clientOrderId: String
    let newQuantity: Double?
    let newPrice: Double?
    let walletPublicId: String?
    let operatorPublicId: String?
    let userPublicId: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        exchange: String,
        instrument: String,
        exchangeOrderId: String,
        clientOrderId: String,
        newQuantity: Double? = nil,
        newPrice: Double? = nil,
        walletPublicId: String? = nil,
        operatorPublicId: String? = nil,
        userPublicId: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.exchange = exchange
        self.instrument = instrument
        self.exchangeOrderId = exchangeOrderId
        self.clientOrderId = clientOrderId
        self.newQuantity = newQuantity
        self.newPrice = newPrice
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.userPublicId = userPublicId
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case exchange
        case instrument
        case exchangeOrderId = "exchange_order_id"
        case clientOrderId = "client_order_id"
        case newQuantity = "new_quantity"
        case newPrice = "new_price"
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case userPublicId = "user_public_id"
    }
}

struct OrderRequestData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let strategyId: String
    let exchange: String
    let instrument: String
    let mode: String
    let side: String
    let orderType: String
    let quantity: Double
    let price: Double?
    let clientOrderId: String
    let signaledAt: Date?
    let strategyTag: String?
    let leverage: Int?
    let reduceOnly: Bool?
    let walletPublicId: String?
    let operatorPublicId: String?
    let userPublicId: String?
    let pairedGroupId: String?
    let pairedGroupSize: Int?
    let pairedGroupIndex: Int?
    let pairedGroupPolicy: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        strategyId: String,
        exchange: String,
        instrument: String,
        mode: String,
        side: String,
        orderType: String,
        quantity: Double,
        price: Double? = nil,
        clientOrderId: String,
        signaledAt: Date? = nil,
        strategyTag: String? = nil,
        leverage: Int? = nil,
        reduceOnly: Bool? = nil,
        walletPublicId: String? = nil,
        operatorPublicId: String? = nil,
        userPublicId: String? = nil,
        pairedGroupId: String? = nil,
        pairedGroupSize: Int? = nil,
        pairedGroupIndex: Int? = nil,
        pairedGroupPolicy: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.strategyId = strategyId
        self.exchange = exchange
        self.instrument = instrument
        self.mode = mode
        self.side = side
        self.orderType = orderType
        self.quantity = quantity
        self.price = price
        self.clientOrderId = clientOrderId
        self.signaledAt = signaledAt
        self.strategyTag = strategyTag
        self.leverage = leverage
        self.reduceOnly = reduceOnly
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.userPublicId = userPublicId
        self.pairedGroupId = pairedGroupId
        self.pairedGroupSize = pairedGroupSize
        self.pairedGroupIndex = pairedGroupIndex
        self.pairedGroupPolicy = pairedGroupPolicy
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case strategyId = "strategy_id"
        case exchange
        case instrument
        case mode
        case side
        case orderType = "order_type"
        case quantity
        case price
        case clientOrderId = "client_order_id"
        case signaledAt = "signaled_at"
        case strategyTag = "strategy_tag"
        case leverage
        case reduceOnly = "reduce_only"
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case userPublicId = "user_public_id"
        case pairedGroupId = "paired_group_id"
        case pairedGroupSize = "paired_group_size"
        case pairedGroupIndex = "paired_group_index"
        case pairedGroupPolicy = "paired_group_policy"
    }
}

struct ProcessConfiguredEventData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let processNames: [String]
    let snapshotAt: Date

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        processNames: [String],
        snapshotAt: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.processNames = processNames
        self.snapshotAt = snapshotAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case processNames = "process_names"
        case snapshotAt = "snapshot_at"
    }
}

struct ProcessRunEventData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let processName: String
    let runId: String
    let status: String
    let startedAt: Date
    let completedAt: Date?
    let exitCode: Int?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        processName: String,
        runId: String,
        status: String,
        startedAt: Date,
        completedAt: Date? = nil,
        exitCode: Int? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.processName = processName
        self.runId = runId
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.exitCode = exitCode
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case processName = "process_name"
        case runId = "run_id"
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case exitCode = "exit_code"
    }
}

struct ProcessSummaryEventData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let coordinator: String?
    let processes: [ProcessSummaryItem]
    let snapshotAt: Date

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        coordinator: String? = nil,
        processes: [ProcessSummaryItem],
        snapshotAt: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.coordinator = coordinator
        self.processes = processes
        self.snapshotAt = snapshotAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case coordinator
        case processes
        case snapshotAt = "snapshot_at"
    }
}

struct ReplayEndData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
    }
}

struct ReplayStartData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let startedAt: Date?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        startedAt: Date? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.startedAt = startedAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case startedAt = "started_at"
    }
}

struct ScopeGrantedData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let grantPublicId: String
    let operatorPublicId: String
    let walletPublicId: String
    let scopeKind: String
    let underlyingPublicId: String?
    let instrumentPublicId: String?
    let grantedAt: Date
    let grantedByUserPublicId: String
    let reason: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        grantPublicId: String,
        operatorPublicId: String,
        walletPublicId: String,
        scopeKind: String,
        underlyingPublicId: String? = nil,
        instrumentPublicId: String? = nil,
        grantedAt: Date,
        grantedByUserPublicId: String,
        reason: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.grantPublicId = grantPublicId
        self.operatorPublicId = operatorPublicId
        self.walletPublicId = walletPublicId
        self.scopeKind = scopeKind
        self.underlyingPublicId = underlyingPublicId
        self.instrumentPublicId = instrumentPublicId
        self.grantedAt = grantedAt
        self.grantedByUserPublicId = grantedByUserPublicId
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case grantPublicId = "grant_public_id"
        case operatorPublicId = "operator_public_id"
        case walletPublicId = "wallet_public_id"
        case scopeKind = "scope_kind"
        case underlyingPublicId = "underlying_public_id"
        case instrumentPublicId = "instrument_public_id"
        case grantedAt = "granted_at"
        case grantedByUserPublicId = "granted_by_user_public_id"
        case reason
    }
}

struct ScopeHandedOverData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let grantPublicId: String
    let fromOperatorPublicId: String
    let toOperatorPublicId: String
    let walletPublicId: String
    let scopeKind: String
    let underlyingPublicId: String?
    let instrumentPublicId: String?
    let handoverAt: Date
    let handoverByUserPublicId: String
    let reason: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        grantPublicId: String,
        fromOperatorPublicId: String,
        toOperatorPublicId: String,
        walletPublicId: String,
        scopeKind: String,
        underlyingPublicId: String? = nil,
        instrumentPublicId: String? = nil,
        handoverAt: Date,
        handoverByUserPublicId: String,
        reason: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.grantPublicId = grantPublicId
        self.fromOperatorPublicId = fromOperatorPublicId
        self.toOperatorPublicId = toOperatorPublicId
        self.walletPublicId = walletPublicId
        self.scopeKind = scopeKind
        self.underlyingPublicId = underlyingPublicId
        self.instrumentPublicId = instrumentPublicId
        self.handoverAt = handoverAt
        self.handoverByUserPublicId = handoverByUserPublicId
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case grantPublicId = "grant_public_id"
        case fromOperatorPublicId = "from_operator_public_id"
        case toOperatorPublicId = "to_operator_public_id"
        case walletPublicId = "wallet_public_id"
        case scopeKind = "scope_kind"
        case underlyingPublicId = "underlying_public_id"
        case instrumentPublicId = "instrument_public_id"
        case handoverAt = "handover_at"
        case handoverByUserPublicId = "handover_by_user_public_id"
        case reason
    }
}

struct ScopeRevokedData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let grantPublicId: String
    let operatorPublicId: String
    let walletPublicId: String
    let scopeKind: String
    let underlyingPublicId: String?
    let instrumentPublicId: String?
    let revokedAt: Date
    let revokedByUserPublicId: String?
    let reason: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        grantPublicId: String,
        operatorPublicId: String,
        walletPublicId: String,
        scopeKind: String,
        underlyingPublicId: String? = nil,
        instrumentPublicId: String? = nil,
        revokedAt: Date,
        revokedByUserPublicId: String? = nil,
        reason: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.grantPublicId = grantPublicId
        self.operatorPublicId = operatorPublicId
        self.walletPublicId = walletPublicId
        self.scopeKind = scopeKind
        self.underlyingPublicId = underlyingPublicId
        self.instrumentPublicId = instrumentPublicId
        self.revokedAt = revokedAt
        self.revokedByUserPublicId = revokedByUserPublicId
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case grantPublicId = "grant_public_id"
        case operatorPublicId = "operator_public_id"
        case walletPublicId = "wallet_public_id"
        case scopeKind = "scope_kind"
        case underlyingPublicId = "underlying_public_id"
        case instrumentPublicId = "instrument_public_id"
        case revokedAt = "revoked_at"
        case revokedByUserPublicId = "revoked_by_user_public_id"
        case reason
    }
}

struct SettingChangedData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let key: String
    let value: String
    let category: String
    let updatedBy: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        key: String,
        value: String,
        category: String,
        updatedBy: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.key = key
        self.value = value
        self.category = category
        self.updatedBy = updatedBy
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case key
        case value
        case category
        case updatedBy = "updated_by"
    }
}

struct StrategyListEventData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let strategyClasses: [String]
    let snapshotAt: Date

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        strategyClasses: [String],
        snapshotAt: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.strategyClasses = strategyClasses
        self.snapshotAt = snapshotAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case strategyClasses = "strategy_classes"
        case snapshotAt = "snapshot_at"
    }
}

struct SymbolAliasUpdateData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let event: String
    let action: String

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        event: String,
        action: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.event = event
        self.action = action
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case event
        case action
    }
}

struct TickData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrument: String
    let exchange: String
    let volume: Double
    let bid: Double?
    let ask: Double?
    let last: Double?
    let isDelayed: Bool?
    let isExtendedHours: Bool?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrument: String,
        exchange: String,
        volume: Double,
        bid: Double? = nil,
        ask: Double? = nil,
        last: Double? = nil,
        isDelayed: Bool? = nil,
        isExtendedHours: Bool? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrument = instrument
        self.exchange = exchange
        self.volume = volume
        self.bid = bid
        self.ask = ask
        self.last = last
        self.isDelayed = isDelayed
        self.isExtendedHours = isExtendedHours
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrument
        case exchange
        case volume
        case bid
        case ask
        case last
        case isDelayed = "is_delayed"
        case isExtendedHours = "is_extended_hours"
    }
}

struct TradeData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrument: String
    let exchange: String
    let executedAt: Date?
    let price: Double
    let volume: Double
    let side: String?
    let tradeId: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrument: String,
        exchange: String,
        executedAt: Date? = nil,
        price: Double,
        volume: Double,
        side: String? = nil,
        tradeId: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrument = instrument
        self.exchange = exchange
        self.executedAt = executedAt
        self.price = price
        self.volume = volume
        self.side = side
        self.tradeId = tradeId
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrument
        case exchange
        case executedAt = "executed_at"
        case price
        case volume
        case side
        case tradeId = "trade_id"
    }
}

struct UserDeactivatedData: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let userPublicId: String
    let deactivatedAt: Date
    let reason: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        userPublicId: String,
        deactivatedAt: Date,
        reason: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.userPublicId = userPublicId
        self.deactivatedAt = deactivatedAt
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case userPublicId = "user_public_id"
        case deactivatedAt = "deactivated_at"
        case reason
    }
}

struct WSAuthCompleteResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let availableTopics: [String]
    let userRole: UserRole
    let sessionExpiresAt: Date?
    let wsTokenExp: Date

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        availableTopics: [String],
        userRole: UserRole,
        sessionExpiresAt: Date? = nil,
        wsTokenExp: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.availableTopics = availableTopics
        self.userRole = userRole
        self.sessionExpiresAt = sessionExpiresAt
        self.wsTokenExp = wsTokenExp
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case availableTopics = "available_topics"
        case userRole = "user_role"
        case sessionExpiresAt = "session_expires_at"
        case wsTokenExp = "ws_token_exp"
    }
}

struct WSAuthExpiredResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
    }
}

struct WSAuthFailedResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let reason: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        reason: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case reason
    }
}

struct WSAuthOkResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let exp: Date

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        exp: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.exp = exp
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case exp
    }
}

struct WSAuthRequiredResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let timeout: Int?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        timeout: Int? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.timeout = timeout
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case timeout
    }
}

struct WSAuthenticateRequest: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let wsToken: String

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        wsToken: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.wsToken = wsToken
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case wsToken = "ws_token"
    }
}

struct WSErrorResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let message: String

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        message: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case message
    }
}

struct WSGetSubscriptionsRequest: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
    }
}

struct WSPingRequest: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
    }
}

struct WSPongResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let activeConnections: Int

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        activeConnections: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.activeConnections = activeConnections
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case activeConnections = "active_connections"
    }
}

struct WSReauthOkResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let exp: Date

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        exp: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.exp = exp
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case exp
    }
}

struct WSReauthRequest: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let wsToken: String

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        wsToken: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.wsToken = wsToken
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case wsToken = "ws_token"
    }
}

struct WSReauthRequiredResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let deadline: Date

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        deadline: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.deadline = deadline
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case deadline
    }
}

struct WSSubscribeRequest: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let topics: [String]

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        topics: [String]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.topics = topics
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case topics
    }
}

struct WSSubscriptionSuccessResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let action: String
    let status: String
    let topics: [String]
    let deniedTopics: [String]?
    let activeSubscriptions: [String]
    let message: String?

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        action: String,
        status: String,
        topics: [String],
        deniedTopics: [String]? = nil,
        activeSubscriptions: [String],
        message: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.action = action
        self.status = status
        self.topics = topics
        self.deniedTopics = deniedTopics
        self.activeSubscriptions = activeSubscriptions
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case action
        case status
        case topics
        case deniedTopics = "denied_topics"
        case activeSubscriptions = "active_subscriptions"
        case message
    }
}

struct WSSubscriptionsListResponse: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let subscriptions: [String]
    let availableTopics: [String]
    let totalAvailable: Int

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        subscriptions: [String],
        availableTopics: [String],
        totalAvailable: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.subscriptions = subscriptions
        self.availableTopics = availableTopics
        self.totalAvailable = totalAvailable
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case subscriptions
        case availableTopics = "available_topics"
        case totalAvailable = "total_available"
    }
}

struct WSUnsubscribeRequest: Codable, Sendable {
    let type: String
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let topics: [String]

    init(
        type: String,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        topics: [String]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.topics = topics
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case topics
    }
}
