// This file was auto-generated from backend schemas.
// DO NOT EDIT - regenerate with: make ios-gen-types

import Foundation

enum PortfolioReconciliationEffectiveStatus: String, Codable, Sendable {
    case matched
    case mismatched
    case incomplete
    case unsupported
    case error
    case stale
    case clockError = "clock_error"
    case corrupt
}

enum PortfolioReconciliationEvaluationStatus: String, Codable, Sendable {
    case matched
    case mismatched
    case incomplete
    case unsupported
    case error
}

enum PortfolioReconciliationMethod: String, Codable, Sendable {
    case futuresPosition = "futures_position"
    case spotExecutionReplay = "spot_execution_replay"
    case marginLedgerReplay = "margin_ledger_replay"
    case unclassified
}

enum RealPortfolioReconciliationMethod: String, Codable, Sendable {
    case futuresPosition = "futures_position"
    case spotExecutionReplay = "spot_execution_replay"
    case marginLedgerReplay = "margin_ledger_replay"
}

enum RelationshipTypeEnum: String, Codable, Sendable {
    case exact
    case derivative
    case proxy
}

enum UserRole: String, Codable, Sendable {
    case aiDelegate = "ai_delegate"
    case viewer
    case operatorRole = "operator"
    case admin
}

enum AvailableProcessLifecycle: String, Codable, Sendable {
    case longRunning = "long_running"
    case oneShot = "one_shot"
}

enum AvailableProcessRole: String, Codable, Sendable {
    case core
    case task
    case strategy
    case backtest
}

enum CachedCandlesPayloadSource: String, Codable, Sendable {
    case cache
    case derived
    case db
}

enum CandleDataExchange: String, Codable, Sendable {
    case kraken
    case krakenFutures = "kraken_futures"
    case krakenEquities = "kraken_equities"
    case walutomat
    case polygon
}

enum CandleDataOrigin: String, Codable, Sendable {
    case live
    case replay
}

enum ConfiguredProcessMode: String, Codable, Sendable {
    case thread
    case process
}

enum ConfiguredProcessLifecycle: String, Codable, Sendable {
    case longRunning = "long_running"
    case oneShot = "one_shot"
}

enum ConfiguredProcessRole: String, Codable, Sendable {
    case core
    case task
    case strategy
    case backtest
}

enum ConfiguredProcessKind: String, Codable, Sendable {
    case template
    case instance
}

enum DiskMetricsStatus: String, Codable, Sendable {
    case healthy
    case warning
    case error
}

enum EgressActiveReservationSnapshotTrafficClass: String, Codable, Sendable {
    case publicValue = "public"
    case privateValue = "private"
}

enum EgressConnectionSnapshotKind: String, Codable, Sendable {
    case ws
    case rest
}

enum EgressConnectionSnapshotTrafficClass: String, Codable, Sendable {
    case publicValue = "public"
    case privateValue = "private"
}

enum EgressRouteStatusSnapshotKind: String, Codable, Sendable {
    case direct
    case socks5
}

enum ExecutionDataExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum ExecutionDataSide: String, Codable, Sendable {
    case buy
    case sell
}

enum ExecutionDataStatus: String, Codable, Sendable {
    case filled
    case partial
}

enum HealthCheckDataStatus: String, Codable, Sendable {
    case healthy
    case warning
    case error
}

enum OrderDataExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum OrderDataMode: String, Codable, Sendable {
    case live
    case paper
}

enum OrderDataSide: String, Codable, Sendable {
    case buy
    case sell
}

enum OrderDataOrderType: String, Codable, Sendable {
    case market
    case limit
    case stop
    case stopLimit = "stop_limit"
}

enum PortfolioAccountStateExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum PortfolioAccountStateMode: String, Codable, Sendable {
    case live
    case paper
}

enum PositionDataExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum PositionDataMode: String, Codable, Sendable {
    case live
    case paper
}

enum ProcessDesiredStateDataAction: String, Codable, Sendable {
    case enable
    case disable
    case restart
}

enum ProcessRunStatus: String, Codable, Sendable {
    case running
    case succeeded
    case failed
    case cancelled
}

enum ProcessRunRole: String, Codable, Sendable {
    case core
    case task
    case strategy
    case backtest
}

enum ProcessRunLifecycle: String, Codable, Sendable {
    case longRunning = "long_running"
    case oneShot = "one_shot"
}

enum ProcessSchemaDataDefaultMode: String, Codable, Sendable {
    case thread
    case process
}

enum ProcessSchemaDataLifecycle: String, Codable, Sendable {
    case longRunning = "long_running"
    case oneShot = "one_shot"
}

enum ProcessStartDataStatus: String, Codable, Sendable {
    case success
    case alreadyRunning = "already_running"
    case error
}

enum ProcessStatusStatus: String, Codable, Sendable {
    case notRunning = "not_running"
    case running
    case stopped
    case completed
    case error
}

enum ProcessStopDataStatus: String, Codable, Sendable {
    case success
    case notRunning = "not_running"
    case error
}

enum SignalDataExchange: String, Codable, Sendable {
    case paper
    case kraken
    case krakenFutures = "kraken_futures"
    case walutomat
}

enum SignalDataSide: String, Codable, Sendable {
    case buy
    case sell
}

enum SignalDataOrigin: String, Codable, Sendable {
    case live
    case replay
}

enum SignalDiffEntryLeg: String, Codable, Sendable {
    case a
    case b
    case common
}

enum StrategyProcessMode: String, Codable, Sendable {
    case thread
    case process
}

enum TableStatsItemTableKind: String, Codable, Sendable {
    case event
    case state
}

enum TradeDiffEntryLeg: String, Codable, Sendable {
    case a
    case b
    case common
}

enum ZmqComponentsZmqContext: String, Codable, Sendable {
    case ok
    case error
}

enum ZmqComponentsWebsocketManager: String, Codable, Sendable {
    case ok
    case error
}

enum ZmqHealthDataStatus: String, Codable, Sendable {
    case healthy
    case warning
    case error
}

enum UserAlertDefaultBodyAlertType: String, Codable, Sendable {
    case orderFillFull = "order_fill_full"
    case orderRejected = "order_rejected"
    case orderUnknown = "order_unknown"
    case positionStopLossFired = "position_stop_loss_fired"
    case marginWarning = "margin_warning"
    case criticalSystemError = "critical_system_error"
}

enum UserAlertDefaultBodyMinPriority: String, Codable, Sendable {
    case low
    case medium
    case high
}

enum BacktestCompareBodyMode: String, Codable, Sendable {
    case manual
    case auto
}

enum CreateCredentialBodyCredentialType: String, Codable, Sendable {
    case apiKeySecret = "api_key_secret"
    case rsaPem = "rsa_pem"
    case oauth
    case paper
}

enum RegisterDeviceBodyEnv: String, Codable, Sendable {
    case sandbox
    case prod
}

enum RegisterDeviceBodyPreviewsMode: String, Codable, Sendable {
    case privateValue = "private"
    case publicValue = "public"
}

enum DeviceAlertPrefBodyAlertType: String, Codable, Sendable {
    case orderFillFull = "order_fill_full"
    case orderRejected = "order_rejected"
    case orderUnknown = "order_unknown"
    case positionStopLossFired = "position_stop_loss_fired"
    case marginWarning = "margin_warning"
    case criticalSystemError = "critical_system_error"
}

enum DeviceAlertPrefBodyMinPriority: String, Codable, Sendable {
    case low
    case medium
    case high
}

enum CreateOrderBodyMode: String, Codable, Sendable {
    case live
    case paper
}

enum CreateOrderBodySide: String, Codable, Sendable {
    case buy
    case sell
}

enum CreateOrderBodyOrderType: String, Codable, Sendable {
    case market
    case limit
    case stop
    case stopLimit = "stop_limit"
}

enum ProcessDesiredStateBodyAction: String, Codable, Sendable {
    case enable
    case disable
    case restart
}

enum CreateScopeGrantBodyScopeKind: String, Codable, Sendable {
    case underlying
    case instrument
}

struct AccountBalanceEntry: Codable, Sendable {
    let currency: String
    let total: Double
    let free: Double?
    let used: Double?
    let totalDecimal: String?
    let freeDecimal: String?
    let usedDecimal: String?
    let numericProvenance: String?

    init(
        currency: String,
        total: Double,
        free: Double? = nil,
        used: Double? = nil,
        totalDecimal: String? = nil,
        freeDecimal: String? = nil,
        usedDecimal: String? = nil,
        numericProvenance: String? = nil
    ) {
        self.currency = currency
        self.total = total
        self.free = free
        self.used = used
        self.totalDecimal = totalDecimal
        self.freeDecimal = freeDecimal
        self.usedDecimal = usedDecimal
        self.numericProvenance = numericProvenance
    }

    enum CodingKeys: String, CodingKey {
        case currency
        case total
        case free
        case used
        case totalDecimal = "total_decimal"
        case freeDecimal = "free_decimal"
        case usedDecimal = "used_decimal"
        case numericProvenance = "numeric_provenance"
    }
}

struct AccountPositionEntry: Codable, Sendable {
    let symbol: String
    let side: String
    let size: Double
    let entryPrice: Double
    let markPrice: Double
    let unrealizedPnl: Double
    let unrealizedFunding: Double
    let timestamp: Date

    init(
        symbol: String,
        side: String,
        size: Double,
        entryPrice: Double,
        markPrice: Double,
        unrealizedPnl: Double,
        unrealizedFunding: Double,
        timestamp: Date
    ) {
        self.symbol = symbol
        self.side = side
        self.size = size
        self.entryPrice = entryPrice
        self.markPrice = markPrice
        self.unrealizedPnl = unrealizedPnl
        self.unrealizedFunding = unrealizedFunding
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case symbol
        case side
        case size
        case entryPrice = "entry_price"
        case markPrice = "mark_price"
        case unrealizedPnl = "unrealized_pnl"
        case unrealizedFunding = "unrealized_funding"
        case timestamp
    }
}

struct AdminAiReviewItem: Codable, Sendable {
    let reviewPublicId: String
    let strategyPublicId: String
    let userPublicId: String
    let operatorPublicId: String
    let walletPublicId: String
    let instrumentPublicId: String
    let selectedDelegatePublicId: String
    let respondingDelegatePublicId: String?
    let status: String
    let decision: String?
    let rationale: String?
    let resolutionMode: String?
    let dispatchVersion: Int
    let createdAt: Date
    let resolvedAt: Date?
    let deadline: Date
    let signalEnvelope: JsonObject?

    init(
        reviewPublicId: String,
        strategyPublicId: String,
        userPublicId: String,
        operatorPublicId: String,
        walletPublicId: String,
        instrumentPublicId: String,
        selectedDelegatePublicId: String,
        respondingDelegatePublicId: String?,
        status: String,
        decision: String?,
        rationale: String?,
        resolutionMode: String?,
        dispatchVersion: Int,
        createdAt: Date,
        resolvedAt: Date?,
        deadline: Date,
        signalEnvelope: JsonObject? = nil
    ) {
        self.reviewPublicId = reviewPublicId
        self.strategyPublicId = strategyPublicId
        self.userPublicId = userPublicId
        self.operatorPublicId = operatorPublicId
        self.walletPublicId = walletPublicId
        self.instrumentPublicId = instrumentPublicId
        self.selectedDelegatePublicId = selectedDelegatePublicId
        self.respondingDelegatePublicId = respondingDelegatePublicId
        self.status = status
        self.decision = decision
        self.rationale = rationale
        self.resolutionMode = resolutionMode
        self.dispatchVersion = dispatchVersion
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.deadline = deadline
        self.signalEnvelope = signalEnvelope
    }

    enum CodingKeys: String, CodingKey {
        case reviewPublicId = "review_public_id"
        case strategyPublicId = "strategy_public_id"
        case userPublicId = "user_public_id"
        case operatorPublicId = "operator_public_id"
        case walletPublicId = "wallet_public_id"
        case instrumentPublicId = "instrument_public_id"
        case selectedDelegatePublicId = "selected_delegate_public_id"
        case respondingDelegatePublicId = "responding_delegate_public_id"
        case status
        case decision
        case rationale
        case resolutionMode = "resolution_mode"
        case dispatchVersion = "dispatch_version"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
        case deadline
        case signalEnvelope = "signal_envelope"
    }
}

struct AdminAiReviewListResponse: Codable, Sendable {
    let items: [AdminAiReviewItem]
    let count: Int

    init(
        items: [AdminAiReviewItem],
        count: Int
    ) {
        self.items = items
        self.count = count
    }
}

struct AiReviewDecisionResponse: Codable, Sendable {
    let success: Bool
    let errorCode: String?
    let message: String
    let details: JsonObject

    init(
        success: Bool,
        errorCode: String?,
        message: String,
        details: JsonObject
    ) {
        self.success = success
        self.errorCode = errorCode
        self.message = message
        self.details = details
    }

    enum CodingKeys: String, CodingKey {
        case success
        case errorCode = "error_code"
        case message
        case details
    }
}

struct AlertEventInfo: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let userPublicId: String
    let operatorPublicId: String?
    let walletPublicId: String?
    let alertType: String
    let priority: String
    let isSafetyCritical: Bool
    let title: String
    let body: String
    let payload: JsonObject?
    let titleLocKey: String?
    let titleLocArgs: [String]?
    let bodyLocKey: String?
    let bodyLocArgs: [String]?
    let dedupKey: String?
    let threadKey: String?
    let sourceTopic: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        userPublicId: String,
        operatorPublicId: String? = nil,
        walletPublicId: String? = nil,
        alertType: String,
        priority: String,
        isSafetyCritical: Bool,
        title: String,
        body: String,
        payload: JsonObject? = nil,
        titleLocKey: String? = nil,
        titleLocArgs: [String]? = nil,
        bodyLocKey: String? = nil,
        bodyLocArgs: [String]? = nil,
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
        self.titleLocKey = titleLocKey
        self.titleLocArgs = titleLocArgs
        self.bodyLocKey = bodyLocKey
        self.bodyLocArgs = bodyLocArgs
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
        case titleLocKey = "title_loc_key"
        case titleLocArgs = "title_loc_args"
        case bodyLocKey = "body_loc_key"
        case bodyLocArgs = "body_loc_args"
        case dedupKey = "dedup_key"
        case threadKey = "thread_key"
        case sourceTopic = "source_topic"
    }
}

struct AlertEventResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: AlertEventInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: AlertEventInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct AlertHistoryResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [AlertEventInfo]
    let count: Int
    let nextCursor: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [AlertEventInfo],
        count: Int,
        nextCursor: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
        self.nextCursor = nextCursor
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
        case nextCursor = "next_cursor"
    }
}

struct AsyncioMetrics: Codable, Sendable {
    let activeTasks: Int
    let pendingTasks: Int

    init(
        activeTasks: Int,
        pendingTasks: Int
    ) {
        self.activeTasks = activeTasks
        self.pendingTasks = pendingTasks
    }

    enum CodingKeys: String, CodingKey {
        case activeTasks = "active_tasks"
        case pendingTasks = "pending_tasks"
    }
}

struct AvailableProcess: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let name: String
    let classPath: String
    let method: String
    let description: String
    let lifecycle: String
    let role: String
    let tags: [String]?
    let parametersSchema: JsonObject?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        name: String,
        classPath: String,
        method: String,
        description: String,
        lifecycle: String,
        role: String,
        tags: [String]? = nil,
        parametersSchema: JsonObject? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.name = name
        self.classPath = classPath
        self.method = method
        self.description = description
        self.lifecycle = lifecycle
        self.role = role
        self.tags = tags
        self.parametersSchema = parametersSchema
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case name
        case classPath = "class_path"
        case method
        case description
        case lifecycle
        case role
        case tags
        case parametersSchema = "parameters_schema"
    }
}

struct AvailableProcessesResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [AvailableProcess]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [AvailableProcess],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct BacktestComparisonData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let walletPublicId: String
    let runAPublicId: String
    let runBPublicId: String
    let configHash: String?
    let pairingMode: String
    let anchorRunPublicId: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        walletPublicId: String,
        runAPublicId: String,
        runBPublicId: String,
        configHash: String? = nil,
        pairingMode: String,
        anchorRunPublicId: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.walletPublicId = walletPublicId
        self.runAPublicId = runAPublicId
        self.runBPublicId = runBPublicId
        self.configHash = configHash
        self.pairingMode = pairingMode
        self.anchorRunPublicId = anchorRunPublicId
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case walletPublicId = "wallet_public_id"
        case runAPublicId = "run_a_public_id"
        case runBPublicId = "run_b_public_id"
        case configHash = "config_hash"
        case pairingMode = "pairing_mode"
        case anchorRunPublicId = "anchor_run_public_id"
    }
}

struct BacktestComparisonDetailResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: BacktestComparisonDetailResponseData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: BacktestComparisonDetailResponseData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct BacktestComparisonDetailResponseData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let comparison: BacktestComparisonData
    let runA: BacktestRunData
    let runB: BacktestRunData
    let metricsDiff: [MetricDiffRow]
    let equityOverlay: [EquityOverlayPoint]
    let tradesDiff: [TradeDiffEntry]
    let signalsDiff: [SignalDiffEntry]

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        comparison: BacktestComparisonData,
        runA: BacktestRunData,
        runB: BacktestRunData,
        metricsDiff: [MetricDiffRow],
        equityOverlay: [EquityOverlayPoint],
        tradesDiff: [TradeDiffEntry],
        signalsDiff: [SignalDiffEntry]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.comparison = comparison
        self.runA = runA
        self.runB = runB
        self.metricsDiff = metricsDiff
        self.equityOverlay = equityOverlay
        self.tradesDiff = tradesDiff
        self.signalsDiff = signalsDiff
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case comparison
        case runA = "run_a"
        case runB = "run_b"
        case metricsDiff = "metrics_diff"
        case equityOverlay = "equity_overlay"
        case tradesDiff = "trades_diff"
        case signalsDiff = "signals_diff"
    }
}

struct BacktestComparisonListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [BacktestComparisonData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [BacktestComparisonData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct BacktestComparisonResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: BacktestComparisonData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: BacktestComparisonData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct BacktestEquityPointInline: Codable, Sendable {
    let pointTime: Date
    let equity: Double
    let cash: Double
    let positionValue: Double?
    let drawdown: Double?

    init(
        pointTime: Date,
        equity: Double,
        cash: Double,
        positionValue: Double? = nil,
        drawdown: Double? = nil
    ) {
        self.pointTime = pointTime
        self.equity = equity
        self.cash = cash
        self.positionValue = positionValue
        self.drawdown = drawdown
    }

    enum CodingKeys: String, CodingKey {
        case pointTime = "point_time"
        case equity
        case cash
        case positionValue = "position_value"
        case drawdown
    }
}

struct BacktestEquityPointListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [BacktestEquityPointInline]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [BacktestEquityPointInline],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct BacktestEventData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let runPublicId: String
    let eventType: String
    let detail: [String: AnyCodable]?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        runPublicId: String,
        eventType: String,
        detail: [String: AnyCodable]? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.runPublicId = runPublicId
        self.eventType = eventType
        self.detail = detail
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case runPublicId = "run_public_id"
        case eventType = "event_type"
        case detail
    }
}

struct BacktestEventListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [BacktestEventData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [BacktestEventData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct BacktestResultInline: Codable, Sendable {
    let totalTrades: Int
    let winningTrades: Int
    let losingTrades: Int
    let totalPnl: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    let winRate: Double?
    let profitFactor: Double?
    let finalEquity: Double
    let maxEquity: Double
    let sortinoRatio: Double?
    let cagr: Double?
    let calmarRatio: Double?
    let expectancy: Double?
    let avgTradePnl: Double?
    let maxDrawdownDurationSeconds: Double?
    let exposureRatio: Double?
    let turnoverRatio: Double?
    let extraMetrics: JsonObject?

    init(
        totalTrades: Int,
        winningTrades: Int,
        losingTrades: Int,
        totalPnl: Double,
        maxDrawdown: Double,
        sharpeRatio: Double? = nil,
        winRate: Double? = nil,
        profitFactor: Double? = nil,
        finalEquity: Double,
        maxEquity: Double,
        sortinoRatio: Double? = nil,
        cagr: Double? = nil,
        calmarRatio: Double? = nil,
        expectancy: Double? = nil,
        avgTradePnl: Double? = nil,
        maxDrawdownDurationSeconds: Double? = nil,
        exposureRatio: Double? = nil,
        turnoverRatio: Double? = nil,
        extraMetrics: JsonObject? = nil
    ) {
        self.totalTrades = totalTrades
        self.winningTrades = winningTrades
        self.losingTrades = losingTrades
        self.totalPnl = totalPnl
        self.maxDrawdown = maxDrawdown
        self.sharpeRatio = sharpeRatio
        self.winRate = winRate
        self.profitFactor = profitFactor
        self.finalEquity = finalEquity
        self.maxEquity = maxEquity
        self.sortinoRatio = sortinoRatio
        self.cagr = cagr
        self.calmarRatio = calmarRatio
        self.expectancy = expectancy
        self.avgTradePnl = avgTradePnl
        self.maxDrawdownDurationSeconds = maxDrawdownDurationSeconds
        self.exposureRatio = exposureRatio
        self.turnoverRatio = turnoverRatio
        self.extraMetrics = extraMetrics
    }

    enum CodingKeys: String, CodingKey {
        case totalTrades = "total_trades"
        case winningTrades = "winning_trades"
        case losingTrades = "losing_trades"
        case totalPnl = "total_pnl"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
        case winRate = "win_rate"
        case profitFactor = "profit_factor"
        case finalEquity = "final_equity"
        case maxEquity = "max_equity"
        case sortinoRatio = "sortino_ratio"
        case cagr
        case calmarRatio = "calmar_ratio"
        case expectancy
        case avgTradePnl = "avg_trade_pnl"
        case maxDrawdownDurationSeconds = "max_drawdown_duration_seconds"
        case exposureRatio = "exposure_ratio"
        case turnoverRatio = "turnover_ratio"
        case extraMetrics = "extra_metrics"
    }
}

struct BacktestRunData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let walletPublicId: String
    let strategyName: String
    let strategyParams: JsonObject?
    let instrumentPublicId: String
    let instrument: String?
    let exchange: String
    let timeframe: String
    let startDate: Date
    let endDate: Date
    let initialCash: Double
    let status: String
    let executionMode: String?
    let fillModel: String?
    let slippageBps: Double?
    let commissionBps: Double?
    let configHash: String?
    let targetExecutionExchange: String?
    let startedAt: Date?
    let completedAt: Date?
    let error: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        walletPublicId: String,
        strategyName: String,
        strategyParams: JsonObject? = nil,
        instrumentPublicId: String,
        instrument: String? = nil,
        exchange: String,
        timeframe: String,
        startDate: Date,
        endDate: Date,
        initialCash: Double,
        status: String,
        executionMode: String? = nil,
        fillModel: String? = nil,
        slippageBps: Double? = nil,
        commissionBps: Double? = nil,
        configHash: String? = nil,
        targetExecutionExchange: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        error: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.walletPublicId = walletPublicId
        self.strategyName = strategyName
        self.strategyParams = strategyParams
        self.instrumentPublicId = instrumentPublicId
        self.instrument = instrument
        self.exchange = exchange
        self.timeframe = timeframe
        self.startDate = startDate
        self.endDate = endDate
        self.initialCash = initialCash
        self.status = status
        self.executionMode = executionMode
        self.fillModel = fillModel
        self.slippageBps = slippageBps
        self.commissionBps = commissionBps
        self.configHash = configHash
        self.targetExecutionExchange = targetExecutionExchange
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case walletPublicId = "wallet_public_id"
        case strategyName = "strategy_name"
        case strategyParams = "strategy_params"
        case instrumentPublicId = "instrument_public_id"
        case instrument
        case exchange
        case timeframe
        case startDate = "start_date"
        case endDate = "end_date"
        case initialCash = "initial_cash"
        case status
        case executionMode = "execution_mode"
        case fillModel = "fill_model"
        case slippageBps = "slippage_bps"
        case commissionBps = "commission_bps"
        case configHash = "config_hash"
        case targetExecutionExchange = "target_execution_exchange"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case error
    }
}

struct BacktestRunDetailData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let walletPublicId: String
    let strategyName: String
    let strategyParams: JsonObject?
    let instrumentPublicId: String
    let instrument: String?
    let exchange: String
    let timeframe: String
    let startDate: Date
    let endDate: Date
    let initialCash: Double
    let status: String
    let executionMode: String?
    let fillModel: String?
    let slippageBps: Double?
    let commissionBps: Double?
    let configHash: String?
    let targetExecutionExchange: String?
    let startedAt: Date?
    let completedAt: Date?
    let error: String?
    let result: BacktestResultInline?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        walletPublicId: String,
        strategyName: String,
        strategyParams: JsonObject? = nil,
        instrumentPublicId: String,
        instrument: String? = nil,
        exchange: String,
        timeframe: String,
        startDate: Date,
        endDate: Date,
        initialCash: Double,
        status: String,
        executionMode: String? = nil,
        fillModel: String? = nil,
        slippageBps: Double? = nil,
        commissionBps: Double? = nil,
        configHash: String? = nil,
        targetExecutionExchange: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        error: String? = nil,
        result: BacktestResultInline? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.walletPublicId = walletPublicId
        self.strategyName = strategyName
        self.strategyParams = strategyParams
        self.instrumentPublicId = instrumentPublicId
        self.instrument = instrument
        self.exchange = exchange
        self.timeframe = timeframe
        self.startDate = startDate
        self.endDate = endDate
        self.initialCash = initialCash
        self.status = status
        self.executionMode = executionMode
        self.fillModel = fillModel
        self.slippageBps = slippageBps
        self.commissionBps = commissionBps
        self.configHash = configHash
        self.targetExecutionExchange = targetExecutionExchange
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.error = error
        self.result = result
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case walletPublicId = "wallet_public_id"
        case strategyName = "strategy_name"
        case strategyParams = "strategy_params"
        case instrumentPublicId = "instrument_public_id"
        case instrument
        case exchange
        case timeframe
        case startDate = "start_date"
        case endDate = "end_date"
        case initialCash = "initial_cash"
        case status
        case executionMode = "execution_mode"
        case fillModel = "fill_model"
        case slippageBps = "slippage_bps"
        case commissionBps = "commission_bps"
        case configHash = "config_hash"
        case targetExecutionExchange = "target_execution_exchange"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case error
        case result
    }
}

struct BacktestRunDetailResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: BacktestRunDetailData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: BacktestRunDetailData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct BacktestRunListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [BacktestRunData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [BacktestRunData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct BacktestRunResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: BacktestRunData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: BacktestRunData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct BacktestSignalData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let runPublicId: String
    let signalTime: Date
    let signalType: String
    let instrument: String
    let price: Double
    let indicators: [String: AnyCodable]?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        runPublicId: String,
        signalTime: Date,
        signalType: String,
        instrument: String,
        price: Double,
        indicators: [String: AnyCodable]? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.runPublicId = runPublicId
        self.signalTime = signalTime
        self.signalType = signalType
        self.instrument = instrument
        self.price = price
        self.indicators = indicators
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case runPublicId = "run_public_id"
        case signalTime = "signal_time"
        case signalType = "signal_type"
        case instrument
        case price
        case indicators
    }
}

struct BacktestSignalListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [BacktestSignalData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [BacktestSignalData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct BacktestStrategyClassListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [String]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [String],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct BacktestTradeData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let runPublicId: String
    let executedAt: Date
    let instrument: String
    let side: String
    let quantity: Double
    let price: Double
    let fee: Double
    let pnl: Double?
    let positionAfter: Double?
    let signalPublicId: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        runPublicId: String,
        executedAt: Date,
        instrument: String,
        side: String,
        quantity: Double,
        price: Double,
        fee: Double,
        pnl: Double? = nil,
        positionAfter: Double? = nil,
        signalPublicId: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.runPublicId = runPublicId
        self.executedAt = executedAt
        self.instrument = instrument
        self.side = side
        self.quantity = quantity
        self.price = price
        self.fee = fee
        self.pnl = pnl
        self.positionAfter = positionAfter
        self.signalPublicId = signalPublicId
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case runPublicId = "run_public_id"
        case executedAt = "executed_at"
        case instrument
        case side
        case quantity
        case price
        case fee
        case pnl
        case positionAfter = "position_after"
        case signalPublicId = "signal_public_id"
    }
}

struct BacktestTradeListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [BacktestTradeData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [BacktestTradeData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct CacheHealthPayload: Codable, Sendable {
    let instrumentsCached: Int
    let pairsCached: Int
    let persistUniverseSize: Int

    init(
        instrumentsCached: Int,
        pairsCached: Int,
        persistUniverseSize: Int
    ) {
        self.instrumentsCached = instrumentsCached
        self.pairsCached = pairsCached
        self.persistUniverseSize = persistUniverseSize
    }

    enum CodingKeys: String, CodingKey {
        case instrumentsCached = "instruments_cached"
        case pairsCached = "pairs_cached"
        case persistUniverseSize = "persist_universe_size"
    }
}

struct CacheHealthResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CacheHealthPayload

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CacheHealthPayload
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CachedCandle: Codable, Sendable {
    let openAtMs: Int
    let timeframe: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double

    init(
        openAtMs: Int,
        timeframe: String,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double
    ) {
        self.openAtMs = openAtMs
        self.timeframe = timeframe
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }

    enum CodingKeys: String, CodingKey {
        case openAtMs = "open_at_ms"
        case timeframe
        case open
        case high
        case low
        case close
        case volume
    }
}

struct CachedCandlesPayload: Codable, Sendable {
    let candles: [CachedCandle]
    let sampleCount: Int
    let isWarm: Bool
    let source: String

    init(
        candles: [CachedCandle],
        sampleCount: Int,
        isWarm: Bool,
        source: String
    ) {
        self.candles = candles
        self.sampleCount = sampleCount
        self.isWarm = isWarm
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case candles
        case sampleCount = "sample_count"
        case isWarm = "is_warm"
        case source
    }
}

struct CachedCandlesResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CachedCandlesPayload

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CachedCandlesPayload
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CachedStatsPayload: Codable, Sendable {
    let left: String
    let right: String
    let pearsonR: Double?
    let pearsonN: Int
    let cointT: Double?
    let cointPvalue: Double?
    let cointCriticalValues: [AnyCodable]?
    let computedAt: Date?
    let sampleCount: Int
    let isWarm: Bool

    init(
        left: String,
        right: String,
        pearsonR: Double?,
        pearsonN: Int,
        cointT: Double?,
        cointPvalue: Double?,
        cointCriticalValues: [AnyCodable]?,
        computedAt: Date?,
        sampleCount: Int,
        isWarm: Bool
    ) {
        self.left = left
        self.right = right
        self.pearsonR = pearsonR
        self.pearsonN = pearsonN
        self.cointT = cointT
        self.cointPvalue = cointPvalue
        self.cointCriticalValues = cointCriticalValues
        self.computedAt = computedAt
        self.sampleCount = sampleCount
        self.isWarm = isWarm
    }

    enum CodingKeys: String, CodingKey {
        case left
        case right
        case pearsonR = "pearson_r"
        case pearsonN = "pearson_n"
        case cointT = "coint_t"
        case cointPvalue = "coint_pvalue"
        case cointCriticalValues = "coint_critical_values"
        case computedAt = "computed_at"
        case sampleCount = "sample_count"
        case isWarm = "is_warm"
    }
}

struct CachedStatsResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CachedStatsPayload

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CachedStatsPayload
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CandleData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrument: String
    let exchange: String
    let timeframe: String
    let openAt: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let vwap: Double?
    let trades: Int?
    let complete: Bool?
    let origin: String?
    let replayWindowStart: Date?
    let replayWindowEnd: Date?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrument: String,
        exchange: String,
        timeframe: String,
        openAt: Date,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double,
        vwap: Double? = nil,
        trades: Int? = nil,
        complete: Bool? = nil,
        origin: String? = nil,
        replayWindowStart: Date? = nil,
        replayWindowEnd: Date? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrument = instrument
        self.exchange = exchange
        self.timeframe = timeframe
        self.openAt = openAt
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.vwap = vwap
        self.trades = trades
        self.complete = complete
        self.origin = origin
        self.replayWindowStart = replayWindowStart
        self.replayWindowEnd = replayWindowEnd
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
        case timeframe
        case openAt = "open_at"
        case open
        case high
        case low
        case close
        case volume
        case vwap
        case trades
        case complete
        case origin
        case replayWindowStart = "replay_window_start"
        case replayWindowEnd = "replay_window_end"
    }
}

struct CandleListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [CandleData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [CandleData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct ConfiguredProcess: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let name: String
    let enabled: Bool
    let running: Bool
    let mode: String
    let classPath: String
    let method: String
    let parameters: JsonObject?
    let note: String?
    let lifecycle: String
    let role: String
    let tags: [String]?
    let parametersSchema: JsonObject?
    let isOneShot: Bool
    let activePublicId: String?
    let kind: String
    let walletPublicId: String?
    let parentTemplate: String?
    let template: String?
    let coordinator: String?
    let coordinatorLabel: String?
    let managedRemotely: Bool?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        name: String,
        enabled: Bool,
        running: Bool,
        mode: String,
        classPath: String,
        method: String,
        parameters: JsonObject? = nil,
        note: String? = nil,
        lifecycle: String,
        role: String,
        tags: [String]? = nil,
        parametersSchema: JsonObject? = nil,
        isOneShot: Bool,
        activePublicId: String? = nil,
        kind: String,
        walletPublicId: String? = nil,
        parentTemplate: String? = nil,
        template: String? = nil,
        coordinator: String? = nil,
        coordinatorLabel: String? = nil,
        managedRemotely: Bool? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.name = name
        self.enabled = enabled
        self.running = running
        self.mode = mode
        self.classPath = classPath
        self.method = method
        self.parameters = parameters
        self.note = note
        self.lifecycle = lifecycle
        self.role = role
        self.tags = tags
        self.parametersSchema = parametersSchema
        self.isOneShot = isOneShot
        self.activePublicId = activePublicId
        self.kind = kind
        self.walletPublicId = walletPublicId
        self.parentTemplate = parentTemplate
        self.template = template
        self.coordinator = coordinator
        self.coordinatorLabel = coordinatorLabel
        self.managedRemotely = managedRemotely
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case name
        case enabled
        case running
        case mode
        case classPath = "class_path"
        case method
        case parameters
        case note
        case lifecycle
        case role
        case tags
        case parametersSchema = "parameters_schema"
        case isOneShot = "is_one_shot"
        case activePublicId = "active_public_id"
        case kind
        case walletPublicId = "wallet_public_id"
        case parentTemplate = "parent_template"
        case template
        case coordinator
        case coordinatorLabel = "coordinator_label"
        case managedRemotely = "managed_remotely"
    }
}

struct ConfiguredProcessesResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [ConfiguredProcess]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [ConfiguredProcess],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct ConnectionStats: Codable, Sendable {
    let activeConnections: Int?
    let zmqSubscribers: Int?
    let subscriberTasks: Int?
    let activeTopics: Int?
    let activeClients: Int?

    init(
        activeConnections: Int? = nil,
        zmqSubscribers: Int? = nil,
        subscriberTasks: Int? = nil,
        activeTopics: Int? = nil,
        activeClients: Int? = nil
    ) {
        self.activeConnections = activeConnections
        self.zmqSubscribers = zmqSubscribers
        self.subscriberTasks = subscriberTasks
        self.activeTopics = activeTopics
        self.activeClients = activeClients
    }

    enum CodingKeys: String, CodingKey {
        case activeConnections = "active_connections"
        case zmqSubscribers = "zmq_subscribers"
        case subscriberTasks = "subscriber_tasks"
        case activeTopics = "active_topics"
        case activeClients = "active_clients"
    }
}

struct ContinuousCandleData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let openAt: Date
    let timeframe: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let vwap: Double?
    let trades: Int?
    let sourceContract: String
    let adjustmentFactor: Double?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        openAt: Date,
        timeframe: String,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double,
        vwap: Double?,
        trades: Int?,
        sourceContract: String,
        adjustmentFactor: Double?
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.openAt = openAt
        self.timeframe = timeframe
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.vwap = vwap
        self.trades = trades
        self.sourceContract = sourceContract
        self.adjustmentFactor = adjustmentFactor
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case openAt = "open_at"
        case timeframe
        case open
        case high
        case low
        case close
        case volume
        case vwap
        case trades
        case sourceContract = "source_contract"
        case adjustmentFactor = "adjustment_factor"
    }
}

struct ContinuousCandleListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [ContinuousCandleData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [ContinuousCandleData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct ContinuousSeriesPartialResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [ContinuousCandleData]
    let count: Int
    let failedRoll: RollPointDetail
    let message: String

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [ContinuousCandleData],
        count: Int,
        failedRoll: RollPointDetail,
        message: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
        self.failedRoll = failedRoll
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
        case failedRoll = "failed_roll"
        case message
    }
}

struct ContractData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrumentPublicId: String
    let nativeSymbol: String
    let exchange: String
    let expiryAt: Date?
    let instrumentKind: String?
    let relationshipType: String
    let contractFamily: String?
    let isFrontMonth: Bool

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrumentPublicId: String,
        nativeSymbol: String,
        exchange: String,
        expiryAt: Date?,
        instrumentKind: String?,
        relationshipType: String,
        contractFamily: String?,
        isFrontMonth: Bool
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrumentPublicId = instrumentPublicId
        self.nativeSymbol = nativeSymbol
        self.exchange = exchange
        self.expiryAt = expiryAt
        self.instrumentKind = instrumentKind
        self.relationshipType = relationshipType
        self.contractFamily = contractFamily
        self.isFrontMonth = isFrontMonth
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrumentPublicId = "instrument_public_id"
        case nativeSymbol = "native_symbol"
        case exchange
        case expiryAt = "expiry_at"
        case instrumentKind = "instrument_kind"
        case relationshipType = "relationship_type"
        case contractFamily = "contract_family"
        case isFrontMonth = "is_front_month"
    }
}

struct ContractListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [ContractData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [ContractData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct CpuMetrics: Codable, Sendable {
    let processPercent: Double
    let userTimeSeconds: Double
    let systemTimeSeconds: Double
    let cgroupQuotaMicroseconds: Int?
    let cgroupThrottledCount: Int?

    init(
        processPercent: Double,
        userTimeSeconds: Double,
        systemTimeSeconds: Double,
        cgroupQuotaMicroseconds: Int?,
        cgroupThrottledCount: Int?
    ) {
        self.processPercent = processPercent
        self.userTimeSeconds = userTimeSeconds
        self.systemTimeSeconds = systemTimeSeconds
        self.cgroupQuotaMicroseconds = cgroupQuotaMicroseconds
        self.cgroupThrottledCount = cgroupThrottledCount
    }

    enum CodingKeys: String, CodingKey {
        case processPercent = "process_percent"
        case userTimeSeconds = "user_time_seconds"
        case systemTimeSeconds = "system_time_seconds"
        case cgroupQuotaMicroseconds = "cgroup_quota_microseconds"
        case cgroupThrottledCount = "cgroup_throttled_count"
    }
}

struct CredentialListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [CredentialSummary]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [CredentialSummary],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct CredentialReconciliationMethodInfo: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let walletPublicId: String
    let exchange: String
    let mode: String
    let method: RealPortfolioReconciliationMethod

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        walletPublicId: String,
        exchange: String,
        mode: String,
        method: RealPortfolioReconciliationMethod
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.walletPublicId = walletPublicId
        self.exchange = exchange
        self.mode = mode
        self.method = method
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case walletPublicId = "wallet_public_id"
        case exchange
        case mode
        case method
    }
}

struct CredentialReconciliationMethodResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CredentialReconciliationMethodInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CredentialReconciliationMethodInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CredentialResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CredentialSummary

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CredentialSummary
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CredentialSummary: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let walletPublicId: String
    let exchange: String
    let credentialType: String
    let label: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        walletPublicId: String,
        exchange: String,
        credentialType: String,
        label: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.walletPublicId = walletPublicId
        self.exchange = exchange
        self.credentialType = credentialType
        self.label = label
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case walletPublicId = "wallet_public_id"
        case exchange
        case credentialType = "credential_type"
        case label
    }
}

struct DbInternalMetrics: Codable, Sendable {
    let aiosqliteLiveConnections: Int
    let poolSize: Int?
    let poolCheckedOut: Int?

    init(
        aiosqliteLiveConnections: Int,
        poolSize: Int?,
        poolCheckedOut: Int?
    ) {
        self.aiosqliteLiveConnections = aiosqliteLiveConnections
        self.poolSize = poolSize
        self.poolCheckedOut = poolCheckedOut
    }

    enum CodingKeys: String, CodingKey {
        case aiosqliteLiveConnections = "aiosqlite_live_connections"
        case poolSize = "pool_size"
        case poolCheckedOut = "pool_checked_out"
    }
}

struct DbStatsData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let snapshotStartedAt: Date
    let snapshotCompletedAt: Date
    let intervalSeconds: Int
    let tables: [TableStatsItem]

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        snapshotStartedAt: Date,
        snapshotCompletedAt: Date,
        intervalSeconds: Int,
        tables: [TableStatsItem]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.snapshotStartedAt = snapshotStartedAt
        self.snapshotCompletedAt = snapshotCompletedAt
        self.intervalSeconds = intervalSeconds
        self.tables = tables
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case snapshotStartedAt = "snapshot_started_at"
        case snapshotCompletedAt = "snapshot_completed_at"
        case intervalSeconds = "interval_seconds"
        case tables
    }
}

struct DbStatsResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DbStatsData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DbStatsData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct DelegateCapsBody: Codable, Sendable {
    let maxOrderQuantityPerInstrument: JsonObject?
    let maxOpenOrders: Int?
    let maxDailyNotionalUsd: Double?
    let maxCancelsPerMinute: Int?

    init(
        maxOrderQuantityPerInstrument: JsonObject? = nil,
        maxOpenOrders: Int? = nil,
        maxDailyNotionalUsd: Double? = nil,
        maxCancelsPerMinute: Int? = nil
    ) {
        self.maxOrderQuantityPerInstrument = maxOrderQuantityPerInstrument
        self.maxOpenOrders = maxOpenOrders
        self.maxDailyNotionalUsd = maxDailyNotionalUsd
        self.maxCancelsPerMinute = maxCancelsPerMinute
    }

    enum CodingKeys: String, CodingKey {
        case maxOrderQuantityPerInstrument = "max_order_quantity_per_instrument"
        case maxOpenOrders = "max_open_orders"
        case maxDailyNotionalUsd = "max_daily_notional_usd"
        case maxCancelsPerMinute = "max_cancels_per_minute"
    }
}

struct DelegateCreatedPayload: Codable, Sendable {
    let delegate: DelegateRead
    let accessToken: String
    let expiresIn: Int

    init(
        delegate: DelegateRead,
        accessToken: String,
        expiresIn: Int
    ) {
        self.delegate = delegate
        self.accessToken = accessToken
        self.expiresIn = expiresIn
    }

    enum CodingKeys: String, CodingKey {
        case delegate
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

struct DelegateCreatedResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DelegateCreatedPayload

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DelegateCreatedPayload
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct DelegateListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [DelegateRead]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [DelegateRead],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct DelegateRead: Codable, Sendable {
    let publicId: String
    let username: String
    let label: String
    let createdByUserPublicId: String
    let createdAt: Date
    let isActive: Bool
    let caps: DelegateCapsBody

    init(
        publicId: String,
        username: String,
        label: String,
        createdByUserPublicId: String,
        createdAt: Date,
        isActive: Bool,
        caps: DelegateCapsBody
    ) {
        self.publicId = publicId
        self.username = username
        self.label = label
        self.createdByUserPublicId = createdByUserPublicId
        self.createdAt = createdAt
        self.isActive = isActive
        self.caps = caps
    }

    enum CodingKeys: String, CodingKey {
        case publicId = "public_id"
        case username
        case label
        case createdByUserPublicId = "created_by_user_public_id"
        case createdAt = "created_at"
        case isActive = "is_active"
        case caps
    }
}

struct DelegateResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DelegateRead

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DelegateRead
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct DeviceAlertPrefInfo: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let devicePublicId: String
    let alertType: String
    let operatorPublicId: String?
    let walletPublicId: String?
    let enabled: Bool
    let minPriority: String
    let quietHoursStartMin: Int?
    let quietHoursEndMin: Int?
    let muteUntil: Date?
    let timezone: String

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        devicePublicId: String,
        alertType: String,
        operatorPublicId: String? = nil,
        walletPublicId: String? = nil,
        enabled: Bool,
        minPriority: String,
        quietHoursStartMin: Int? = nil,
        quietHoursEndMin: Int? = nil,
        muteUntil: Date? = nil,
        timezone: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.devicePublicId = devicePublicId
        self.alertType = alertType
        self.operatorPublicId = operatorPublicId
        self.walletPublicId = walletPublicId
        self.enabled = enabled
        self.minPriority = minPriority
        self.quietHoursStartMin = quietHoursStartMin
        self.quietHoursEndMin = quietHoursEndMin
        self.muteUntil = muteUntil
        self.timezone = timezone
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case devicePublicId = "device_public_id"
        case alertType = "alert_type"
        case operatorPublicId = "operator_public_id"
        case walletPublicId = "wallet_public_id"
        case enabled
        case minPriority = "min_priority"
        case quietHoursStartMin = "quiet_hours_start_min"
        case quietHoursEndMin = "quiet_hours_end_min"
        case muteUntil = "mute_until"
        case timezone
    }
}

struct DeviceAlertPrefListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [DeviceAlertPrefInfo]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [DeviceAlertPrefInfo],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct DeviceAlertPrefResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DeviceAlertPrefInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DeviceAlertPrefInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct DiskMetrics: Codable, Sendable {
    let mountPath: String
    let totalBytes: Int?
    let usedBytes: Int?
    let freeBytes: Int?
    let percentUsed: Double?
    let diskLow: Bool
    let diskCritical: Bool
    let status: String

    init(
        mountPath: String,
        totalBytes: Int?,
        usedBytes: Int?,
        freeBytes: Int?,
        percentUsed: Double?,
        diskLow: Bool,
        diskCritical: Bool,
        status: String
    ) {
        self.mountPath = mountPath
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.percentUsed = percentUsed
        self.diskLow = diskLow
        self.diskCritical = diskCritical
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case mountPath = "mount_path"
        case totalBytes = "total_bytes"
        case usedBytes = "used_bytes"
        case freeBytes = "free_bytes"
        case percentUsed = "percent_used"
        case diskLow = "disk_low"
        case diskCritical = "disk_critical"
        case status
    }
}

struct EgressActiveReservationSnapshot: Codable, Sendable {
    let exchange: String
    let trafficClass: String
    let container: String?

    init(
        exchange: String,
        trafficClass: String,
        container: String? = nil
    ) {
        self.exchange = exchange
        self.trafficClass = trafficClass
        self.container = container
    }

    enum CodingKeys: String, CodingKey {
        case exchange
        case trafficClass = "traffic_class"
        case container
    }
}

struct EgressConnectionSnapshot: Codable, Sendable {
    let host: String
    let kind: String
    let exchange: String
    let trafficClass: String
    let container: String?
    let count: Int
    let lastSeenAt: Date?

    init(
        host: String,
        kind: String,
        exchange: String,
        trafficClass: String,
        container: String? = nil,
        count: Int,
        lastSeenAt: Date? = nil
    ) {
        self.host = host
        self.kind = kind
        self.exchange = exchange
        self.trafficClass = trafficClass
        self.container = container
        self.count = count
        self.lastSeenAt = lastSeenAt
    }

    enum CodingKeys: String, CodingKey {
        case host
        case kind
        case exchange
        case trafficClass = "traffic_class"
        case container
        case count
        case lastSeenAt = "last_seen_at"
    }
}

struct EgressContainerSummary: Codable, Sendable {
    let container: String
    let lastSeenAgeSeconds: Double
    let stale: Bool
    let routeCount: Int

    init(
        container: String,
        lastSeenAgeSeconds: Double,
        stale: Bool,
        routeCount: Int
    ) {
        self.container = container
        self.lastSeenAgeSeconds = lastSeenAgeSeconds
        self.stale = stale
        self.routeCount = routeCount
    }

    enum CodingKeys: String, CodingKey {
        case container
        case lastSeenAgeSeconds = "last_seen_age_seconds"
        case stale
        case routeCount = "route_count"
    }
}

struct EgressHealthData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let enabled: Bool
    let onAllQuarantined: String?
    let privateFallbackRouteId: String?
    let privateOnFallback: Bool?
    let containers: [EgressContainerSummary]?
    let routes: [EgressRouteStatusSnapshot]?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        enabled: Bool,
        onAllQuarantined: String? = nil,
        privateFallbackRouteId: String? = nil,
        privateOnFallback: Bool? = nil,
        containers: [EgressContainerSummary]? = nil,
        routes: [EgressRouteStatusSnapshot]? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.enabled = enabled
        self.onAllQuarantined = onAllQuarantined
        self.privateFallbackRouteId = privateFallbackRouteId
        self.privateOnFallback = privateOnFallback
        self.containers = containers
        self.routes = routes
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case enabled
        case onAllQuarantined = "on_all_quarantined"
        case privateFallbackRouteId = "private_fallback_route_id"
        case privateOnFallback = "private_on_fallback"
        case containers
        case routes
    }
}

struct EgressHealthResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: EgressHealthData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: EgressHealthData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct EgressRouteStatusSnapshot: Codable, Sendable {
    let id: String
    let kind: String
    let proxyUrl: String?
    let region: String?
    let exitIp: String?
    let provider: String?
    let priority: Int
    let allowedExchanges: [String]?
    let enabled: Bool
    let quarantined: Bool
    let quarantineSecondsRemaining: Double?
    let inUseCount: Int
    let activeReservations: [EgressActiveReservationSnapshot]?
    let connections: [EgressConnectionSnapshot]?
    let transfer: EgressTransferSnapshot?

    init(
        id: String,
        kind: String,
        proxyUrl: String? = nil,
        region: String? = nil,
        exitIp: String? = nil,
        provider: String? = nil,
        priority: Int,
        allowedExchanges: [String]? = nil,
        enabled: Bool,
        quarantined: Bool,
        quarantineSecondsRemaining: Double?,
        inUseCount: Int,
        activeReservations: [EgressActiveReservationSnapshot]? = nil,
        connections: [EgressConnectionSnapshot]? = nil,
        transfer: EgressTransferSnapshot? = nil
    ) {
        self.id = id
        self.kind = kind
        self.proxyUrl = proxyUrl
        self.region = region
        self.exitIp = exitIp
        self.provider = provider
        self.priority = priority
        self.allowedExchanges = allowedExchanges
        self.enabled = enabled
        self.quarantined = quarantined
        self.quarantineSecondsRemaining = quarantineSecondsRemaining
        self.inUseCount = inUseCount
        self.activeReservations = activeReservations
        self.connections = connections
        self.transfer = transfer
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case proxyUrl = "proxy_url"
        case region
        case exitIp = "exit_ip"
        case provider
        case priority
        case allowedExchanges = "allowed_exchanges"
        case enabled
        case quarantined
        case quarantineSecondsRemaining = "quarantine_seconds_remaining"
        case inUseCount = "in_use_count"
        case activeReservations = "active_reservations"
        case connections
        case transfer
    }
}

struct EgressTransferSnapshot: Codable, Sendable {
    let interface: String
    let socks5ListenPort: Int
    let rxBytes: Int
    let txBytes: Int
    let rxRateBytesPerSecond: Double?
    let txRateBytesPerSecond: Double?
    let latestHandshakeAt: Date?
    let counterReset: Bool
    let sampledAt: Date
    let sampleAgeSeconds: Double
    let stale: Bool

    init(
        interface: String,
        socks5ListenPort: Int,
        rxBytes: Int,
        txBytes: Int,
        rxRateBytesPerSecond: Double? = nil,
        txRateBytesPerSecond: Double? = nil,
        latestHandshakeAt: Date? = nil,
        counterReset: Bool,
        sampledAt: Date,
        sampleAgeSeconds: Double,
        stale: Bool
    ) {
        self.interface = interface
        self.socks5ListenPort = socks5ListenPort
        self.rxBytes = rxBytes
        self.txBytes = txBytes
        self.rxRateBytesPerSecond = rxRateBytesPerSecond
        self.txRateBytesPerSecond = txRateBytesPerSecond
        self.latestHandshakeAt = latestHandshakeAt
        self.counterReset = counterReset
        self.sampledAt = sampledAt
        self.sampleAgeSeconds = sampleAgeSeconds
        self.stale = stale
    }

    enum CodingKeys: String, CodingKey {
        case interface
        case socks5ListenPort = "socks5_listen_port"
        case rxBytes = "rx_bytes"
        case txBytes = "tx_bytes"
        case rxRateBytesPerSecond = "rx_rate_bytes_per_second"
        case txRateBytesPerSecond = "tx_rate_bytes_per_second"
        case latestHandshakeAt = "latest_handshake_at"
        case counterReset = "counter_reset"
        case sampledAt = "sampled_at"
        case sampleAgeSeconds = "sample_age_seconds"
        case stale
    }
}

struct EquityOverlayPoint: Codable, Sendable {
    let pointTime: Date
    let equityA: Double?
    let equityB: Double?

    init(
        pointTime: Date,
        equityA: Double? = nil,
        equityB: Double? = nil
    ) {
        self.pointTime = pointTime
        self.equityA = equityA
        self.equityB = equityB
    }

    enum CodingKeys: String, CodingKey {
        case pointTime = "point_time"
        case equityA = "equity_a"
        case equityB = "equity_b"
    }
}

struct ExchangeListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [String]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [String],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct ExecutionData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let tradeId: String?
    let exchangeOrderId: String?
    let clientOrderId: String
    let instrument: String
    let exchange: String
    let side: String
    let size: Double
    let price: Double
    let lastSize: Double
    let lastPrice: Double
    let fee: Double
    let feeAsset: String
    let status: String
    let executedAt: Date
    let walletPublicId: String?
    let operatorPublicId: String?
    let userPublicId: String?
    let liquidityRole: String?
    let pairedGroupId: String?
    let pairedGroupSize: Int?
    let pairedGroupIndex: Int?
    let pairedGroupPolicy: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        tradeId: String? = nil,
        exchangeOrderId: String? = nil,
        clientOrderId: String,
        instrument: String,
        exchange: String,
        side: String,
        size: Double,
        price: Double,
        lastSize: Double,
        lastPrice: Double,
        fee: Double,
        feeAsset: String,
        status: String,
        executedAt: Date,
        walletPublicId: String? = nil,
        operatorPublicId: String? = nil,
        userPublicId: String? = nil,
        liquidityRole: String? = nil,
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
        self.tradeId = tradeId
        self.exchangeOrderId = exchangeOrderId
        self.clientOrderId = clientOrderId
        self.instrument = instrument
        self.exchange = exchange
        self.side = side
        self.size = size
        self.price = price
        self.lastSize = lastSize
        self.lastPrice = lastPrice
        self.fee = fee
        self.feeAsset = feeAsset
        self.status = status
        self.executedAt = executedAt
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.userPublicId = userPublicId
        self.liquidityRole = liquidityRole
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
        case tradeId = "trade_id"
        case exchangeOrderId = "exchange_order_id"
        case clientOrderId = "client_order_id"
        case instrument
        case exchange
        case side
        case size
        case price
        case lastSize = "last_size"
        case lastPrice = "last_price"
        case fee
        case feeAsset = "fee_asset"
        case status
        case executedAt = "executed_at"
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case userPublicId = "user_public_id"
        case liquidityRole = "liquidity_role"
        case pairedGroupId = "paired_group_id"
        case pairedGroupSize = "paired_group_size"
        case pairedGroupIndex = "paired_group_index"
        case pairedGroupPolicy = "paired_group_policy"
    }
}

struct ExecutionListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [ExecutionData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [ExecutionData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct ExecutionPlanData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let planType: String
    let status: String
    let instrumentPublicId: String
    let exchange: String
    let mode: String
    let side: String
    let totalQuantity: Double
    let filledQuantity: Double
    let createdAt: Date
    let createdVia: String
    let walletPublicId: String
    let operatorPublicId: String?
    let params: [String: AnyCodable]
    let positionCyclePublicId: String?
    let parentPlanPublicId: String?
    let lastError: String?
    let idempotencyKey: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        planType: String,
        status: String,
        instrumentPublicId: String,
        exchange: String,
        mode: String,
        side: String,
        totalQuantity: Double,
        filledQuantity: Double,
        createdAt: Date,
        createdVia: String,
        walletPublicId: String,
        operatorPublicId: String?,
        params: [String: AnyCodable],
        positionCyclePublicId: String?,
        parentPlanPublicId: String?,
        lastError: String?,
        idempotencyKey: String?
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.planType = planType
        self.status = status
        self.instrumentPublicId = instrumentPublicId
        self.exchange = exchange
        self.mode = mode
        self.side = side
        self.totalQuantity = totalQuantity
        self.filledQuantity = filledQuantity
        self.createdAt = createdAt
        self.createdVia = createdVia
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.params = params
        self.positionCyclePublicId = positionCyclePublicId
        self.parentPlanPublicId = parentPlanPublicId
        self.lastError = lastError
        self.idempotencyKey = idempotencyKey
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case planType = "plan_type"
        case status
        case instrumentPublicId = "instrument_public_id"
        case exchange
        case mode
        case side
        case totalQuantity = "total_quantity"
        case filledQuantity = "filled_quantity"
        case createdAt = "created_at"
        case createdVia = "created_via"
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case params
        case positionCyclePublicId = "position_cycle_public_id"
        case parentPlanPublicId = "parent_plan_public_id"
        case lastError = "last_error"
        case idempotencyKey = "idempotency_key"
    }
}

struct ExecutionPlanDecisionData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let planPublicId: String
    let decisionType: String
    let decidedAt: Date
    let triggerType: String
    let evidence: JsonObject?
    let emittedCommandPublicId: String?
    let newStatus: String?
    let reason: String
    let decisionImportance: String
    let sourceSurface: String

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        planPublicId: String,
        decisionType: String,
        decidedAt: Date,
        triggerType: String,
        evidence: JsonObject? = nil,
        emittedCommandPublicId: String? = nil,
        newStatus: String? = nil,
        reason: String,
        decisionImportance: String,
        sourceSurface: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.planPublicId = planPublicId
        self.decisionType = decisionType
        self.decidedAt = decidedAt
        self.triggerType = triggerType
        self.evidence = evidence
        self.emittedCommandPublicId = emittedCommandPublicId
        self.newStatus = newStatus
        self.reason = reason
        self.decisionImportance = decisionImportance
        self.sourceSurface = sourceSurface
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case planPublicId = "plan_public_id"
        case decisionType = "decision_type"
        case decidedAt = "decided_at"
        case triggerType = "trigger_type"
        case evidence
        case emittedCommandPublicId = "emitted_command_public_id"
        case newStatus = "new_status"
        case reason
        case decisionImportance = "decision_importance"
        case sourceSurface = "source_surface"
    }
}

struct ExecutionPlanDecisionListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [ExecutionPlanDecisionData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [ExecutionPlanDecisionData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct ExecutionPlanResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ExecutionPlanData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ExecutionPlanData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct FeatureFlagsPayload: Codable, Sendable {
    let aiIntegrationEnabled: Bool

    init(
        aiIntegrationEnabled: Bool
    ) {
        self.aiIntegrationEnabled = aiIntegrationEnabled
    }

    enum CodingKeys: String, CodingKey {
        case aiIntegrationEnabled = "ai_integration_enabled"
    }
}

struct FeatureFlagsResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: FeatureFlagsPayload

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: FeatureFlagsPayload
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct FrontMonthData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrumentPublicId: String
    let nativeSymbol: String
    let exchange: String
    let expiryAt: Date
    let relationshipType: String
    let contractFamily: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrumentPublicId: String,
        nativeSymbol: String,
        exchange: String,
        expiryAt: Date,
        relationshipType: String,
        contractFamily: String?
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrumentPublicId = instrumentPublicId
        self.nativeSymbol = nativeSymbol
        self.exchange = exchange
        self.expiryAt = expiryAt
        self.relationshipType = relationshipType
        self.contractFamily = contractFamily
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrumentPublicId = "instrument_public_id"
        case nativeSymbol = "native_symbol"
        case exchange
        case expiryAt = "expiry_at"
        case relationshipType = "relationship_type"
        case contractFamily = "contract_family"
    }
}

struct FrontMonthResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: FrontMonthData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: FrontMonthData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct GapDetectionStats: Codable, Sendable {
    let bridge: GapStats
    let restClients: [String: GapStats]?

    init(
        bridge: GapStats,
        restClients: [String: GapStats]? = nil
    ) {
        self.bridge = bridge
        self.restClients = restClients
    }

    enum CodingKeys: String, CodingKey {
        case bridge
        case restClients = "rest_clients"
    }
}

struct GapStats: Codable, Sendable {
    let gapsDetected: Int?
    let sessionResets: Int?
    let duplicates: Int?
    let midStreamJoins: Int?
    let rejectedUnstamped: Int?

    init(
        gapsDetected: Int? = nil,
        sessionResets: Int? = nil,
        duplicates: Int? = nil,
        midStreamJoins: Int? = nil,
        rejectedUnstamped: Int? = nil
    ) {
        self.gapsDetected = gapsDetected
        self.sessionResets = sessionResets
        self.duplicates = duplicates
        self.midStreamJoins = midStreamJoins
        self.rejectedUnstamped = rejectedUnstamped
    }

    enum CodingKeys: String, CodingKey {
        case gapsDetected = "gaps_detected"
        case sessionResets = "session_resets"
        case duplicates
        case midStreamJoins = "mid_stream_joins"
        case rejectedUnstamped = "rejected_unstamped"
    }
}

struct GcMetrics: Codable, Sendable {
    let collectionsGen0: Int
    let collectionsGen1: Int
    let collectionsGen2: Int
    let uncollectable: Int
    let currentObjects: Int

    init(
        collectionsGen0: Int,
        collectionsGen1: Int,
        collectionsGen2: Int,
        uncollectable: Int,
        currentObjects: Int
    ) {
        self.collectionsGen0 = collectionsGen0
        self.collectionsGen1 = collectionsGen1
        self.collectionsGen2 = collectionsGen2
        self.uncollectable = uncollectable
        self.currentObjects = currentObjects
    }

    enum CodingKeys: String, CodingKey {
        case collectionsGen0 = "collections_gen0"
        case collectionsGen1 = "collections_gen1"
        case collectionsGen2 = "collections_gen2"
        case uncollectable
        case currentObjects = "current_objects"
    }
}

struct HTTPValidationError: Codable, Sendable {
    let detail: [ValidationError]?

    init(
        detail: [ValidationError]? = nil
    ) {
        self.detail = detail
    }
}

struct HandoverScopeGrantResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: HandoverScopeGrantResult

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: HandoverScopeGrantResult
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct HandoverScopeGrantResult: Codable, Sendable {
    let closedGrant: ScopeGrantInfo
    let newGrant: ScopeGrantInfo

    init(
        closedGrant: ScopeGrantInfo,
        newGrant: ScopeGrantInfo
    ) {
        self.closedGrant = closedGrant
        self.newGrant = newGrant
    }

    enum CodingKeys: String, CodingKey {
        case closedGrant = "closed_grant"
        case newGrant = "new_grant"
    }
}

struct HealthCheckData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let status: String
    let version: String
    let connections: ConnectionStats
    let topics: HealthTopics
    let gapDetection: GapDetectionStats

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        status: String,
        version: String,
        connections: ConnectionStats,
        topics: HealthTopics,
        gapDetection: GapDetectionStats
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.status = status
        self.version = version
        self.connections = connections
        self.topics = topics
        self.gapDetection = gapDetection
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case status
        case version
        case connections
        case topics
        case gapDetection = "gap_detection"
    }
}

struct HealthCheckResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: HealthCheckData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: HealthCheckData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct HealthTopics: Codable, Sendable {
    let active: Int

    init(
        active: Int
    ) {
        self.active = active
    }
}

struct InstrumentCapabilityData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrumentPublicId: String
    let exchange: String
    let supportedOrderTypes: [String]
    let supportsPostOnly: Bool
    let supportsReduceOnly: Bool
    let supportsAmendInPlace: Bool
    let supportsNativeStopLoss: Bool
    let supportsNativeTakeProfit: Bool
    let supportsTrailingStopClientSide: Bool
    let supportsMarketMaking: Bool
    let supportsShortSelling: Bool
    let supportsLeverage: Bool
    let maxLeverageLong: Double
    let maxLeverageShort: Double
    let minNotional: Double?
    let maxOrderSize: Double?
    let topOfBookQuality: String

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrumentPublicId: String,
        exchange: String,
        supportedOrderTypes: [String],
        supportsPostOnly: Bool,
        supportsReduceOnly: Bool,
        supportsAmendInPlace: Bool,
        supportsNativeStopLoss: Bool,
        supportsNativeTakeProfit: Bool,
        supportsTrailingStopClientSide: Bool,
        supportsMarketMaking: Bool,
        supportsShortSelling: Bool,
        supportsLeverage: Bool,
        maxLeverageLong: Double,
        maxLeverageShort: Double,
        minNotional: Double?,
        maxOrderSize: Double?,
        topOfBookQuality: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrumentPublicId = instrumentPublicId
        self.exchange = exchange
        self.supportedOrderTypes = supportedOrderTypes
        self.supportsPostOnly = supportsPostOnly
        self.supportsReduceOnly = supportsReduceOnly
        self.supportsAmendInPlace = supportsAmendInPlace
        self.supportsNativeStopLoss = supportsNativeStopLoss
        self.supportsNativeTakeProfit = supportsNativeTakeProfit
        self.supportsTrailingStopClientSide = supportsTrailingStopClientSide
        self.supportsMarketMaking = supportsMarketMaking
        self.supportsShortSelling = supportsShortSelling
        self.supportsLeverage = supportsLeverage
        self.maxLeverageLong = maxLeverageLong
        self.maxLeverageShort = maxLeverageShort
        self.minNotional = minNotional
        self.maxOrderSize = maxOrderSize
        self.topOfBookQuality = topOfBookQuality
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrumentPublicId = "instrument_public_id"
        case exchange
        case supportedOrderTypes = "supported_order_types"
        case supportsPostOnly = "supports_post_only"
        case supportsReduceOnly = "supports_reduce_only"
        case supportsAmendInPlace = "supports_amend_in_place"
        case supportsNativeStopLoss = "supports_native_stop_loss"
        case supportsNativeTakeProfit = "supports_native_take_profit"
        case supportsTrailingStopClientSide = "supports_trailing_stop_client_side"
        case supportsMarketMaking = "supports_market_making"
        case supportsShortSelling = "supports_short_selling"
        case supportsLeverage = "supports_leverage"
        case maxLeverageLong = "max_leverage_long"
        case maxLeverageShort = "max_leverage_short"
        case minNotional = "min_notional"
        case maxOrderSize = "max_order_size"
        case topOfBookQuality = "top_of_book_quality"
    }
}

struct InstrumentCapabilityListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [InstrumentCapabilityData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [InstrumentCapabilityData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct InstrumentDetailData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrumentPublicId: String
    let symbolPublicId: String
    let symbol: String
    let exchange: String
    let canTrade: Bool
    let canMarketData: Bool
    let instrumentResolved: Bool
    let instrumentKind: String?
    let expiryAt: Date?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrumentPublicId: String,
        symbolPublicId: String,
        symbol: String,
        exchange: String,
        canTrade: Bool,
        canMarketData: Bool,
        instrumentResolved: Bool,
        instrumentKind: String?,
        expiryAt: Date?
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrumentPublicId = instrumentPublicId
        self.symbolPublicId = symbolPublicId
        self.symbol = symbol
        self.exchange = exchange
        self.canTrade = canTrade
        self.canMarketData = canMarketData
        self.instrumentResolved = instrumentResolved
        self.instrumentKind = instrumentKind
        self.expiryAt = expiryAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrumentPublicId = "instrument_public_id"
        case symbolPublicId = "symbol_public_id"
        case symbol
        case exchange
        case canTrade = "can_trade"
        case canMarketData = "can_market_data"
        case instrumentResolved = "instrument_resolved"
        case instrumentKind = "instrument_kind"
        case expiryAt = "expiry_at"
    }
}

struct InstrumentDetailListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [InstrumentDetailData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [InstrumentDetailData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct InstrumentFeedHealthRowSchema: Codable, Sendable {
    let coordinator: String
    let exchange: String
    let channel: String
    let symbol: String
    let status: String
    let requestedAt: Date
    let confirmedAt: Date?
    let lastSeenDataAt: Date?
    let lastError: String?
    let retryCount: Int
    let snapshotAt: Date

    init(
        coordinator: String,
        exchange: String,
        channel: String,
        symbol: String,
        status: String,
        requestedAt: Date,
        confirmedAt: Date?,
        lastSeenDataAt: Date?,
        lastError: String?,
        retryCount: Int,
        snapshotAt: Date
    ) {
        self.coordinator = coordinator
        self.exchange = exchange
        self.channel = channel
        self.symbol = symbol
        self.status = status
        self.requestedAt = requestedAt
        self.confirmedAt = confirmedAt
        self.lastSeenDataAt = lastSeenDataAt
        self.lastError = lastError
        self.retryCount = retryCount
        self.snapshotAt = snapshotAt
    }

    enum CodingKeys: String, CodingKey {
        case coordinator
        case exchange
        case channel
        case symbol
        case status
        case requestedAt = "requested_at"
        case confirmedAt = "confirmed_at"
        case lastSeenDataAt = "last_seen_data_at"
        case lastError = "last_error"
        case retryCount = "retry_count"
        case snapshotAt = "snapshot_at"
    }
}

struct InstrumentListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [String]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [String],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct JsonObject: Codable, Sendable {

    init(
    ) {
    }
}

struct LimitsMetrics: Codable, Sendable {
    let rlimitNproc: Int
    let rlimitNofile: Int
    let rlimitAsBytes: Int

    init(
        rlimitNproc: Int,
        rlimitNofile: Int,
        rlimitAsBytes: Int
    ) {
        self.rlimitNproc = rlimitNproc
        self.rlimitNofile = rlimitNofile
        self.rlimitAsBytes = rlimitAsBytes
    }

    enum CodingKeys: String, CodingKey {
        case rlimitNproc = "rlimit_nproc"
        case rlimitNofile = "rlimit_nofile"
        case rlimitAsBytes = "rlimit_as_bytes"
    }
}

struct ListedCachedStatsPayload: Codable, Sendable {
    let count: Int
    let pairs: [CachedStatsPayload]

    init(
        count: Int,
        pairs: [CachedStatsPayload]
    ) {
        self.count = count
        self.pairs = pairs
    }
}

struct ListedCachedStatsResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ListedCachedStatsPayload

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ListedCachedStatsPayload
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct LoginData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let message: String
    let expiresIn: Int
    let user: UserProfile
    let accessToken: String?
    let refreshToken: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        message: String,
        expiresIn: Int,
        user: UserProfile,
        accessToken: String? = nil,
        refreshToken: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.message = message
        self.expiresIn = expiresIn
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case message
        case expiresIn = "expires_in"
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct LoginResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: LoginData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: LoginData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct MarketDataCoverageExchange: Codable, Sendable {
    let exchange: String
    let instruments: Int
    let freshTicks: Int
    let freshCandles: Int
    let gatedOff: Int
    let dark: Int

    init(
        exchange: String,
        instruments: Int,
        freshTicks: Int,
        freshCandles: Int,
        gatedOff: Int,
        dark: Int
    ) {
        self.exchange = exchange
        self.instruments = instruments
        self.freshTicks = freshTicks
        self.freshCandles = freshCandles
        self.gatedOff = gatedOff
        self.dark = dark
    }

    enum CodingKeys: String, CodingKey {
        case exchange
        case instruments
        case freshTicks = "fresh_ticks"
        case freshCandles = "fresh_candles"
        case gatedOff = "gated_off"
        case dark
    }
}

struct MarketDataCoveragePayload: Codable, Sendable {
    let exchanges: [MarketDataCoverageExchange]
    let tickWindowSeconds: Int
    let candleWindowSeconds: Int

    init(
        exchanges: [MarketDataCoverageExchange],
        tickWindowSeconds: Int,
        candleWindowSeconds: Int
    ) {
        self.exchanges = exchanges
        self.tickWindowSeconds = tickWindowSeconds
        self.candleWindowSeconds = candleWindowSeconds
    }

    enum CodingKeys: String, CodingKey {
        case exchanges
        case tickWindowSeconds = "tick_window_seconds"
        case candleWindowSeconds = "candle_window_seconds"
    }
}

struct MarketDataCoverageResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: MarketDataCoveragePayload

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: MarketDataCoveragePayload
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct MarketFeedHealthPayload: Codable, Sendable {
    let rows: [InstrumentFeedHealthRowSchema]
    let exchange: String?
    let freshWithinSeconds: Int?

    init(
        rows: [InstrumentFeedHealthRowSchema],
        exchange: String?,
        freshWithinSeconds: Int?
    ) {
        self.rows = rows
        self.exchange = exchange
        self.freshWithinSeconds = freshWithinSeconds
    }

    enum CodingKeys: String, CodingKey {
        case rows
        case exchange
        case freshWithinSeconds = "fresh_within_seconds"
    }
}

struct MarketFeedHealthResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: MarketFeedHealthPayload

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: MarketFeedHealthPayload
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct MemoryMetrics: Codable, Sendable {
    let rssBytes: Int
    let rssPeakBytes: Int
    let vmsBytes: Int
    let pythonTracedBytes: Int?
    let nativeBytes: Int?
    let cgroupLimitBytes: Int?
    let cgroupCurrentBytes: Int?
    let saturationPct: Double?

    init(
        rssBytes: Int,
        rssPeakBytes: Int,
        vmsBytes: Int,
        pythonTracedBytes: Int?,
        nativeBytes: Int?,
        cgroupLimitBytes: Int?,
        cgroupCurrentBytes: Int?,
        saturationPct: Double?
    ) {
        self.rssBytes = rssBytes
        self.rssPeakBytes = rssPeakBytes
        self.vmsBytes = vmsBytes
        self.pythonTracedBytes = pythonTracedBytes
        self.nativeBytes = nativeBytes
        self.cgroupLimitBytes = cgroupLimitBytes
        self.cgroupCurrentBytes = cgroupCurrentBytes
        self.saturationPct = saturationPct
    }

    enum CodingKeys: String, CodingKey {
        case rssBytes = "rss_bytes"
        case rssPeakBytes = "rss_peak_bytes"
        case vmsBytes = "vms_bytes"
        case pythonTracedBytes = "python_traced_bytes"
        case nativeBytes = "native_bytes"
        case cgroupLimitBytes = "cgroup_limit_bytes"
        case cgroupCurrentBytes = "cgroup_current_bytes"
        case saturationPct = "saturation_pct"
    }
}

struct MessageResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: String

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct MetricDiffRow: Codable, Sendable {
    let name: String
    let runA: Double?
    let runB: Double?
    let delta: Double?
    let pct: Double?

    init(
        name: String,
        runA: Double? = nil,
        runB: Double? = nil,
        delta: Double? = nil,
        pct: Double? = nil
    ) {
        self.name = name
        self.runA = runA
        self.runB = runB
        self.delta = delta
        self.pct = pct
    }

    enum CodingKeys: String, CodingKey {
        case name
        case runA = "run_a"
        case runB = "run_b"
        case delta
        case pct
    }
}

struct NotificationDeviceInfo: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let userPublicId: String
    let deviceToken: String
    let deviceId: String
    let platform: String
    let env: String
    let appVersion: String?
    let previewsMode: String
    let registeredAt: Date
    let lastSeenAt: Date?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        userPublicId: String,
        deviceToken: String,
        deviceId: String,
        platform: String,
        env: String,
        appVersion: String? = nil,
        previewsMode: String,
        registeredAt: Date,
        lastSeenAt: Date? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.userPublicId = userPublicId
        self.deviceToken = deviceToken
        self.deviceId = deviceId
        self.platform = platform
        self.env = env
        self.appVersion = appVersion
        self.previewsMode = previewsMode
        self.registeredAt = registeredAt
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
        case deviceToken = "device_token"
        case deviceId = "device_id"
        case platform
        case env
        case appVersion = "app_version"
        case previewsMode = "previews_mode"
        case registeredAt = "registered_at"
        case lastSeenAt = "last_seen_at"
    }
}

struct NotificationDeviceListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [NotificationDeviceInfo]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [NotificationDeviceInfo],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct NotificationDeviceResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: NotificationDeviceInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: NotificationDeviceInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct NotificationMetricsData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let deliverySuccessTotal: Int
    let deliveryFailedTotal: Int
    let delivery410UnregisteredTotal: Int
    let deliveryCancelledScopeTotal: Int
    let outboxQueuedDepth: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        deliverySuccessTotal: Int,
        deliveryFailedTotal: Int,
        delivery410UnregisteredTotal: Int,
        deliveryCancelledScopeTotal: Int,
        outboxQueuedDepth: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.deliverySuccessTotal = deliverySuccessTotal
        self.deliveryFailedTotal = deliveryFailedTotal
        self.delivery410UnregisteredTotal = delivery410UnregisteredTotal
        self.deliveryCancelledScopeTotal = deliveryCancelledScopeTotal
        self.outboxQueuedDepth = outboxQueuedDepth
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case deliverySuccessTotal = "delivery_success_total"
        case deliveryFailedTotal = "delivery_failed_total"
        case delivery410UnregisteredTotal = "delivery_410_unregistered_total"
        case deliveryCancelledScopeTotal = "delivery_cancelled_scope_total"
        case outboxQueuedDepth = "outbox_queued_depth"
    }
}

struct NotificationMetricsResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: NotificationMetricsData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: NotificationMetricsData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct OperatorInfo: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let label: String
    let description: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        label: String,
        description: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.label = label
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case label
        case description
    }
}

struct OperatorListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [OperatorInfo]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [OperatorInfo],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct OperatorResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: OperatorInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: OperatorInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct OrderData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let exchangeOrderId: String?
    let clientOrderId: String
    let instrument: String
    let exchange: String
    let mode: String?
    let side: String
    let status: String
    let orderType: String
    let size: Double
    let filledSize: Double
    let price: Double?
    let averagePrice: Double?
    let reason: String?
    let timeInForce: String?
    let error: String?
    let createdAt: Date
    let updatedAt: Date?
    let leverage: Int?
    let reduceOnly: Bool?
    let walletPublicId: String?
    let operatorPublicId: String?
    let userPublicId: String?
    let planPublicId: String?
    let pairedGroupId: String?
    let pairedGroupSize: Int?
    let pairedGroupIndex: Int?
    let pairedGroupPolicy: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        exchangeOrderId: String? = nil,
        clientOrderId: String,
        instrument: String,
        exchange: String,
        mode: String? = nil,
        side: String,
        status: String,
        orderType: String,
        size: Double,
        filledSize: Double,
        price: Double? = nil,
        averagePrice: Double? = nil,
        reason: String? = nil,
        timeInForce: String? = nil,
        error: String? = nil,
        createdAt: Date,
        updatedAt: Date? = nil,
        leverage: Int? = nil,
        reduceOnly: Bool? = nil,
        walletPublicId: String? = nil,
        operatorPublicId: String? = nil,
        userPublicId: String? = nil,
        planPublicId: String? = nil,
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
        self.instrument = instrument
        self.exchange = exchange
        self.mode = mode
        self.side = side
        self.status = status
        self.orderType = orderType
        self.size = size
        self.filledSize = filledSize
        self.price = price
        self.averagePrice = averagePrice
        self.reason = reason
        self.timeInForce = timeInForce
        self.error = error
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.leverage = leverage
        self.reduceOnly = reduceOnly
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.userPublicId = userPublicId
        self.planPublicId = planPublicId
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
        case instrument
        case exchange
        case mode
        case side
        case status
        case orderType = "order_type"
        case size
        case filledSize = "filled_size"
        case price
        case averagePrice = "average_price"
        case reason
        case timeInForce = "time_in_force"
        case error
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case leverage
        case reduceOnly = "reduce_only"
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case userPublicId = "user_public_id"
        case planPublicId = "plan_public_id"
        case pairedGroupId = "paired_group_id"
        case pairedGroupSize = "paired_group_size"
        case pairedGroupIndex = "paired_group_index"
        case pairedGroupPolicy = "paired_group_policy"
    }
}

struct OrderListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [OrderData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [OrderData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct OrphanSweepResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: OrphanSweepResultData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: OrphanSweepResultData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct OrphanSweepResultData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let closedCount: Int
    let closedCycleIds: [String]

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        closedCount: Int,
        closedCycleIds: [String]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.closedCount = closedCount
        self.closedCycleIds = closedCycleIds
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case closedCount = "closed_count"
        case closedCycleIds = "closed_cycle_ids"
    }
}

struct PairedExecutionIncident: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let walletPublicId: String
    let strategyId: String
    let groupKey: String
    let halt: PairedHaltInfo?
    let haltMissing: Bool
    let groups: [PairedGroupIncident]

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        walletPublicId: String,
        strategyId: String,
        groupKey: String,
        halt: PairedHaltInfo?,
        haltMissing: Bool,
        groups: [PairedGroupIncident]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.walletPublicId = walletPublicId
        self.strategyId = strategyId
        self.groupKey = groupKey
        self.halt = halt
        self.haltMissing = haltMissing
        self.groups = groups
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case walletPublicId = "wallet_public_id"
        case strategyId = "strategy_id"
        case groupKey = "group_key"
        case halt
        case haltMissing = "halt_missing"
        case groups
    }
}

struct PairedExecutionIncidentListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [PairedExecutionIncident]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [PairedExecutionIncident],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct PairedGroupIncident: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let groupPublicId: String
    let status: String
    let policy: String
    let failureReason: String?
    let haltedAt: Date?
    let createdAt: Date
    let legs: [PairedLegExposure]

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        groupPublicId: String,
        status: String,
        policy: String,
        failureReason: String?,
        haltedAt: Date?,
        createdAt: Date,
        legs: [PairedLegExposure]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.groupPublicId = groupPublicId
        self.status = status
        self.policy = policy
        self.failureReason = failureReason
        self.haltedAt = haltedAt
        self.createdAt = createdAt
        self.legs = legs
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case groupPublicId = "group_public_id"
        case status
        case policy
        case failureReason = "failure_reason"
        case haltedAt = "halted_at"
        case createdAt = "created_at"
        case legs
    }
}

struct PairedGroupTerminalizeResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: PairedGroupIncident

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: PairedGroupIncident
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct PairedHaltInfo: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let haltPublicId: String
    let reason: String
    let groupPublicId: String
    let createdAt: Date

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        haltPublicId: String,
        reason: String,
        groupPublicId: String,
        createdAt: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.haltPublicId = haltPublicId
        self.reason = reason
        self.groupPublicId = groupPublicId
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case haltPublicId = "halt_public_id"
        case reason
        case groupPublicId = "group_public_id"
        case createdAt = "created_at"
    }
}

struct PairedLegExposure: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let legPublicId: String
    let legIndex: Int
    let exchange: String
    let instrument: String
    let mode: String
    let shardKey: String
    let side: String
    let status: String
    let filledSignedQty: Double
    let compensatedSignedQty: Double
    let openQty: Double
    let compensationSeq: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        legPublicId: String,
        legIndex: Int,
        exchange: String,
        instrument: String,
        mode: String,
        shardKey: String,
        side: String,
        status: String,
        filledSignedQty: Double,
        compensatedSignedQty: Double,
        openQty: Double,
        compensationSeq: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.legPublicId = legPublicId
        self.legIndex = legIndex
        self.exchange = exchange
        self.instrument = instrument
        self.mode = mode
        self.shardKey = shardKey
        self.side = side
        self.status = status
        self.filledSignedQty = filledSignedQty
        self.compensatedSignedQty = compensatedSignedQty
        self.openQty = openQty
        self.compensationSeq = compensationSeq
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case legPublicId = "leg_public_id"
        case legIndex = "leg_index"
        case exchange
        case instrument
        case mode
        case shardKey = "shard_key"
        case side
        case status
        case filledSignedQty = "filled_signed_qty"
        case compensatedSignedQty = "compensated_signed_qty"
        case openQty = "open_qty"
        case compensationSeq = "compensation_seq"
    }
}

struct PendingReviewListResponse: Codable, Sendable {
    let items: [PendingReviewSummaryItem]
    let count: Int

    init(
        items: [PendingReviewSummaryItem],
        count: Int
    ) {
        self.items = items
        self.count = count
    }
}

struct PendingReviewSummaryItem: Codable, Sendable {
    let reviewPublicId: String
    let selectedDelegatePublicId: String
    let walletPublicId: String
    let dispatchVersion: Int
    let status: String
    let deadline: Date
    let fanoutAfter: Date
    let instrument: String?
    let signalEnvelope: JsonObject?

    init(
        reviewPublicId: String,
        selectedDelegatePublicId: String,
        walletPublicId: String,
        dispatchVersion: Int,
        status: String,
        deadline: Date,
        fanoutAfter: Date,
        instrument: String? = nil,
        signalEnvelope: JsonObject? = nil
    ) {
        self.reviewPublicId = reviewPublicId
        self.selectedDelegatePublicId = selectedDelegatePublicId
        self.walletPublicId = walletPublicId
        self.dispatchVersion = dispatchVersion
        self.status = status
        self.deadline = deadline
        self.fanoutAfter = fanoutAfter
        self.instrument = instrument
        self.signalEnvelope = signalEnvelope
    }

    enum CodingKeys: String, CodingKey {
        case reviewPublicId = "review_public_id"
        case selectedDelegatePublicId = "selected_delegate_public_id"
        case walletPublicId = "wallet_public_id"
        case dispatchVersion = "dispatch_version"
        case status
        case deadline
        case fanoutAfter = "fanout_after"
        case instrument
        case signalEnvelope = "signal_envelope"
    }
}

struct PortfolioAccountState: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let walletPublicId: String?
    let exchange: String
    let mode: String?
    let syncStatus: String
    let effectiveStatus: String
    let isAuthoritative: Bool
    let balanceStatus: String
    let positionStatus: String
    let valuationStatus: String
    let balances: [AccountBalanceEntry]?
    let openPositions: [AccountPositionEntry]?
    let balanceObservedAt: Date?
    let positionObservedAt: Date?
    let authoritativeUntil: Date?
    let currentAttemptObservationId: Int?
    let balancePayloadSourceObservationId: Int?
    let positionPayloadSourceObservationId: Int?
    let error: String?
    let reconciliation: PortfolioReconciliationView

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        walletPublicId: String? = nil,
        exchange: String,
        mode: String? = nil,
        syncStatus: String,
        effectiveStatus: String,
        isAuthoritative: Bool,
        balanceStatus: String,
        positionStatus: String,
        valuationStatus: String,
        balances: [AccountBalanceEntry]? = nil,
        openPositions: [AccountPositionEntry]? = nil,
        balanceObservedAt: Date? = nil,
        positionObservedAt: Date? = nil,
        authoritativeUntil: Date? = nil,
        currentAttemptObservationId: Int? = nil,
        balancePayloadSourceObservationId: Int? = nil,
        positionPayloadSourceObservationId: Int? = nil,
        error: String? = nil,
        reconciliation: PortfolioReconciliationView
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.walletPublicId = walletPublicId
        self.exchange = exchange
        self.mode = mode
        self.syncStatus = syncStatus
        self.effectiveStatus = effectiveStatus
        self.isAuthoritative = isAuthoritative
        self.balanceStatus = balanceStatus
        self.positionStatus = positionStatus
        self.valuationStatus = valuationStatus
        self.balances = balances
        self.openPositions = openPositions
        self.balanceObservedAt = balanceObservedAt
        self.positionObservedAt = positionObservedAt
        self.authoritativeUntil = authoritativeUntil
        self.currentAttemptObservationId = currentAttemptObservationId
        self.balancePayloadSourceObservationId = balancePayloadSourceObservationId
        self.positionPayloadSourceObservationId = positionPayloadSourceObservationId
        self.error = error
        self.reconciliation = reconciliation
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case walletPublicId = "wallet_public_id"
        case exchange
        case mode
        case syncStatus = "sync_status"
        case effectiveStatus = "effective_status"
        case isAuthoritative = "is_authoritative"
        case balanceStatus = "balance_status"
        case positionStatus = "position_status"
        case valuationStatus = "valuation_status"
        case balances
        case openPositions = "open_positions"
        case balanceObservedAt = "balance_observed_at"
        case positionObservedAt = "position_observed_at"
        case authoritativeUntil = "authoritative_until"
        case currentAttemptObservationId = "current_attempt_observation_id"
        case balancePayloadSourceObservationId = "balance_payload_source_observation_id"
        case positionPayloadSourceObservationId = "position_payload_source_observation_id"
        case error
        case reconciliation
    }
}

struct PortfolioAccountStateListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [PortfolioAccountState]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [PortfolioAccountState],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct PortfolioReconciliationDriftEpisode: Codable, Sendable {
    let publicId: String
    let status: String
    let openedAt: Date
    let triggerObservationId: Int
    let lastObservationId: Int
    let detailsSourceObservationId: Int
    let latestFullMismatchCount: Int

    init(
        publicId: String,
        status: String,
        openedAt: Date,
        triggerObservationId: Int,
        lastObservationId: Int,
        detailsSourceObservationId: Int,
        latestFullMismatchCount: Int
    ) {
        self.publicId = publicId
        self.status = status
        self.openedAt = openedAt
        self.triggerObservationId = triggerObservationId
        self.lastObservationId = lastObservationId
        self.detailsSourceObservationId = detailsSourceObservationId
        self.latestFullMismatchCount = latestFullMismatchCount
    }

    enum CodingKeys: String, CodingKey {
        case publicId = "public_id"
        case status
        case openedAt = "opened_at"
        case triggerObservationId = "trigger_observation_id"
        case lastObservationId = "last_observation_id"
        case detailsSourceObservationId = "details_source_observation_id"
        case latestFullMismatchCount = "latest_full_mismatch_count"
    }
}

struct PortfolioReconciliationView: Codable, Sendable {
    let method: PortfolioReconciliationMethod?
    let evaluationStatus: PortfolioReconciliationEvaluationStatus?
    let effectiveStatus: PortfolioReconciliationEffectiveStatus
    let isAuthoritative: Bool
    let evaluatedAt: Date?
    let currentObservationId: Int?
    let lastFullObservationId: Int?
    let detailSourceObservationId: Int?
    let lastFullOutcome: String?
    let consecutiveFullMismatches: Int
    let anchorPublicId: String?
    let venueAccountStatePublicId: String?
    let venueAccountObservationId: Int?
    let sourceWatermarkKind: String?
    let sourceWatermark: Int?
    let expected: JsonObject?
    let actual: JsonObject?
    let difference: JsonObject?
    let tolerance: JsonObject?
    let reconciledAt: Date?
    let authoritativeUntil: Date?
    let error: String?
    let openDriftEpisode: PortfolioReconciliationDriftEpisode?

    init(
        method: PortfolioReconciliationMethod?,
        evaluationStatus: PortfolioReconciliationEvaluationStatus?,
        effectiveStatus: PortfolioReconciliationEffectiveStatus,
        isAuthoritative: Bool,
        evaluatedAt: Date?,
        currentObservationId: Int?,
        lastFullObservationId: Int?,
        detailSourceObservationId: Int?,
        lastFullOutcome: String?,
        consecutiveFullMismatches: Int,
        anchorPublicId: String?,
        venueAccountStatePublicId: String?,
        venueAccountObservationId: Int?,
        sourceWatermarkKind: String?,
        sourceWatermark: Int?,
        expected: JsonObject?,
        actual: JsonObject?,
        difference: JsonObject?,
        tolerance: JsonObject?,
        reconciledAt: Date?,
        authoritativeUntil: Date?,
        error: String?,
        openDriftEpisode: PortfolioReconciliationDriftEpisode?
    ) {
        self.method = method
        self.evaluationStatus = evaluationStatus
        self.effectiveStatus = effectiveStatus
        self.isAuthoritative = isAuthoritative
        self.evaluatedAt = evaluatedAt
        self.currentObservationId = currentObservationId
        self.lastFullObservationId = lastFullObservationId
        self.detailSourceObservationId = detailSourceObservationId
        self.lastFullOutcome = lastFullOutcome
        self.consecutiveFullMismatches = consecutiveFullMismatches
        self.anchorPublicId = anchorPublicId
        self.venueAccountStatePublicId = venueAccountStatePublicId
        self.venueAccountObservationId = venueAccountObservationId
        self.sourceWatermarkKind = sourceWatermarkKind
        self.sourceWatermark = sourceWatermark
        self.expected = expected
        self.actual = actual
        self.difference = difference
        self.tolerance = tolerance
        self.reconciledAt = reconciledAt
        self.authoritativeUntil = authoritativeUntil
        self.error = error
        self.openDriftEpisode = openDriftEpisode
    }

    enum CodingKeys: String, CodingKey {
        case method
        case evaluationStatus = "evaluation_status"
        case effectiveStatus = "effective_status"
        case isAuthoritative = "is_authoritative"
        case evaluatedAt = "evaluated_at"
        case currentObservationId = "current_observation_id"
        case lastFullObservationId = "last_full_observation_id"
        case detailSourceObservationId = "detail_source_observation_id"
        case lastFullOutcome = "last_full_outcome"
        case consecutiveFullMismatches = "consecutive_full_mismatches"
        case anchorPublicId = "anchor_public_id"
        case venueAccountStatePublicId = "venue_account_state_public_id"
        case venueAccountObservationId = "venue_account_observation_id"
        case sourceWatermarkKind = "source_watermark_kind"
        case sourceWatermark = "source_watermark"
        case expected
        case actual
        case difference
        case tolerance
        case reconciledAt = "reconciled_at"
        case authoritativeUntil = "authoritative_until"
        case error
        case openDriftEpisode = "open_drift_episode"
    }
}

struct PositionCycleData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let cyclePublicId: String
    let shardKey: String
    let instrumentPublicId: String
    let exchange: String
    let mode: String
    let walletPublicId: String
    let operatorPublicId: String?
    let direction: String
    let maxQty: Double
    let openedAt: String
    let ageHours: Double

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        cyclePublicId: String,
        shardKey: String,
        instrumentPublicId: String,
        exchange: String,
        mode: String,
        walletPublicId: String,
        operatorPublicId: String?,
        direction: String,
        maxQty: Double,
        openedAt: String,
        ageHours: Double
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.cyclePublicId = cyclePublicId
        self.shardKey = shardKey
        self.instrumentPublicId = instrumentPublicId
        self.exchange = exchange
        self.mode = mode
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.direction = direction
        self.maxQty = maxQty
        self.openedAt = openedAt
        self.ageHours = ageHours
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case cyclePublicId = "cycle_public_id"
        case shardKey = "shard_key"
        case instrumentPublicId = "instrument_public_id"
        case exchange
        case mode
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case direction
        case maxQty = "max_qty"
        case openedAt = "opened_at"
        case ageHours = "age_hours"
    }
}

struct PositionCycleListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [PositionCycleData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [PositionCycleData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct PositionData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrument: String
    let instrumentPublicId: String?
    let exchange: String
    let mode: String?
    let quantity: Double
    let averagePrice: Double?
    let unrealizedPnl: Double?
    let realizedPnl: Double
    let markPrice: Double?
    let markedAt: Date?
    let sourceVenueEventId: Int?
    let positionCyclePublicId: String?
    let walletPublicId: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrument: String,
        instrumentPublicId: String? = nil,
        exchange: String,
        mode: String? = nil,
        quantity: Double,
        averagePrice: Double? = nil,
        unrealizedPnl: Double? = nil,
        realizedPnl: Double,
        markPrice: Double? = nil,
        markedAt: Date? = nil,
        sourceVenueEventId: Int? = nil,
        positionCyclePublicId: String? = nil,
        walletPublicId: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrument = instrument
        self.instrumentPublicId = instrumentPublicId
        self.exchange = exchange
        self.mode = mode
        self.quantity = quantity
        self.averagePrice = averagePrice
        self.unrealizedPnl = unrealizedPnl
        self.realizedPnl = realizedPnl
        self.markPrice = markPrice
        self.markedAt = markedAt
        self.sourceVenueEventId = sourceVenueEventId
        self.positionCyclePublicId = positionCyclePublicId
        self.walletPublicId = walletPublicId
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrument
        case instrumentPublicId = "instrument_public_id"
        case exchange
        case mode
        case quantity
        case averagePrice = "average_price"
        case unrealizedPnl = "unrealized_pnl"
        case realizedPnl = "realized_pnl"
        case markPrice = "mark_price"
        case markedAt = "marked_at"
        case sourceVenueEventId = "source_venue_event_id"
        case positionCyclePublicId = "position_cycle_public_id"
        case walletPublicId = "wallet_public_id"
    }
}

struct PositionListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [PositionData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [PositionData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct ProcessCategoryCount: Codable, Sendable {
    let running: Int
    let total: Int

    init(
        running: Int,
        total: Int
    ) {
        self.running = running
        self.total = total
    }
}

struct ProcessConfigScopeData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let status: String?
    let name: String
    let parameters: JsonObject
    let restartRequired: Bool?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        status: String? = nil,
        name: String,
        parameters: JsonObject,
        restartRequired: Bool? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.status = status
        self.name = name
        self.parameters = parameters
        self.restartRequired = restartRequired
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case status
        case name
        case parameters
        case restartRequired = "restart_required"
    }
}

struct ProcessConfigScopeResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessConfigScopeData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessConfigScopeData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessCreateData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let status: String
    let process: ProcessCreatedInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        status: String,
        process: ProcessCreatedInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.status = status
        self.process = process
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case status
        case process
    }
}

struct ProcessCreateResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessCreateData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessCreateData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessCreatedInfo: Codable, Sendable {
    let name: String
    let template: String

    init(
        name: String,
        template: String
    ) {
        self.name = name
        self.template = template
    }
}

struct ProcessDesiredStateData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let status: String?
    let name: String
    let action: String
    let coordinator: String?
    let managedRemotely: Bool
    let message: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        status: String? = nil,
        name: String,
        action: String,
        coordinator: String? = nil,
        managedRemotely: Bool,
        message: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.status = status
        self.name = name
        self.action = action
        self.coordinator = coordinator
        self.managedRemotely = managedRemotely
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case status
        case name
        case action
        case coordinator
        case managedRemotely = "managed_remotely"
        case message
    }
}

struct ProcessDesiredStateResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessDesiredStateData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessDesiredStateData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessMetrics: Codable, Sendable {
    let pid: Int
    let uptimeSeconds: Double
    let status: String
    let numThreads: Int
    let numFds: Int
    let numConnections: Int

    init(
        pid: Int,
        uptimeSeconds: Double,
        status: String,
        numThreads: Int,
        numFds: Int,
        numConnections: Int
    ) {
        self.pid = pid
        self.uptimeSeconds = uptimeSeconds
        self.status = status
        self.numThreads = numThreads
        self.numFds = numFds
        self.numConnections = numConnections
    }

    enum CodingKeys: String, CodingKey {
        case pid
        case uptimeSeconds = "uptime_seconds"
        case status
        case numThreads = "num_threads"
        case numFds = "num_fds"
        case numConnections = "num_connections"
    }
}

struct ProcessRun: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let processName: String
    let status: String
    let role: String
    let lifecycle: String
    let parameters: JsonObject?
    let result: JsonObject?
    let error: String?
    let tags: [String]?
    let startedAt: String
    let completedAt: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        processName: String,
        status: String,
        role: String,
        lifecycle: String,
        parameters: JsonObject? = nil,
        result: JsonObject? = nil,
        error: String? = nil,
        tags: [String]? = nil,
        startedAt: String,
        completedAt: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.processName = processName
        self.status = status
        self.role = role
        self.lifecycle = lifecycle
        self.parameters = parameters
        self.result = result
        self.error = error
        self.tags = tags
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case processName = "process_name"
        case status
        case role
        case lifecycle
        case parameters
        case result
        case error
        case tags
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct ProcessRunsResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [ProcessRun]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [ProcessRun],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct ProcessSchemaData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let name: String
    let description: String
    let classPath: String
    let method: String
    let defaultEnabled: Bool
    let defaultMode: String
    let defaultParameters: JsonObject?
    let referenceIdentityParams: [String: String]?
    let seededIdentityParams: [String]?
    let lifecycle: String

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        name: String,
        description: String,
        classPath: String,
        method: String,
        defaultEnabled: Bool,
        defaultMode: String,
        defaultParameters: JsonObject? = nil,
        referenceIdentityParams: [String: String]? = nil,
        seededIdentityParams: [String]? = nil,
        lifecycle: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.name = name
        self.description = description
        self.classPath = classPath
        self.method = method
        self.defaultEnabled = defaultEnabled
        self.defaultMode = defaultMode
        self.defaultParameters = defaultParameters
        self.referenceIdentityParams = referenceIdentityParams
        self.seededIdentityParams = seededIdentityParams
        self.lifecycle = lifecycle
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case name
        case description
        case classPath = "class_path"
        case method
        case defaultEnabled = "default_enabled"
        case defaultMode = "default_mode"
        case defaultParameters = "default_parameters"
        case referenceIdentityParams = "reference_identity_params"
        case seededIdentityParams = "seeded_identity_params"
        case lifecycle
    }
}

struct ProcessSchemaResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessSchemaData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessSchemaData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessStartData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let status: String
    let name: String
    let processPublicId: String?
    let message: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        status: String,
        name: String,
        processPublicId: String? = nil,
        message: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.status = status
        self.name = name
        self.processPublicId = processPublicId
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case status
        case name
        case processPublicId = "process_public_id"
        case message
    }
}

struct ProcessStartResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessStartData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessStartData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessStatus: Codable, Sendable {
    let status: String
    let pid: Int?
    let startedAt: String?
    let command: String?
    let exitCode: Int?
    let error: String?

    init(
        status: String,
        pid: Int? = nil,
        startedAt: String? = nil,
        command: String? = nil,
        exitCode: Int? = nil,
        error: String? = nil
    ) {
        self.status = status
        self.pid = pid
        self.startedAt = startedAt
        self.command = command
        self.exitCode = exitCode
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case status
        case pid
        case startedAt = "started_at"
        case command
        case exitCode = "exit_code"
        case error
    }
}

struct ProcessStopData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let status: String
    let name: String
    let message: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        status: String,
        name: String,
        message: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.status = status
        self.name = name
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case status
        case name
        case message
    }
}

struct ProcessStopResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessStopData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessStopData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessSummaryData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let coordinator: String?
    let coordinatorLabel: String?
    let feeds: ProcessCategoryCount
    let strategies: ProcessCategoryCount
    let executors: ProcessCategoryCount
    let brokers: ProcessCategoryCount
    let processes: [ProcessSummaryItem]?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        coordinator: String? = nil,
        coordinatorLabel: String? = nil,
        feeds: ProcessCategoryCount,
        strategies: ProcessCategoryCount,
        executors: ProcessCategoryCount,
        brokers: ProcessCategoryCount,
        processes: [ProcessSummaryItem]? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.coordinator = coordinator
        self.coordinatorLabel = coordinatorLabel
        self.feeds = feeds
        self.strategies = strategies
        self.executors = executors
        self.brokers = brokers
        self.processes = processes
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case coordinator
        case coordinatorLabel = "coordinator_label"
        case feeds
        case strategies
        case executors
        case brokers
        case processes
    }
}

struct ProcessSummaryItem: Codable, Sendable {
    let name: String
    let running: Bool
    let enabled: Bool
    let role: String
    let lifecycle: String
    let activePublicId: String?
    let rssBytes: Int?
    let cpuPercent: Double?
    let owned: Bool?

    init(
        name: String,
        running: Bool,
        enabled: Bool,
        role: String,
        lifecycle: String,
        activePublicId: String? = nil,
        rssBytes: Int? = nil,
        cpuPercent: Double? = nil,
        owned: Bool? = nil
    ) {
        self.name = name
        self.running = running
        self.enabled = enabled
        self.role = role
        self.lifecycle = lifecycle
        self.activePublicId = activePublicId
        self.rssBytes = rssBytes
        self.cpuPercent = cpuPercent
        self.owned = owned
    }

    enum CodingKeys: String, CodingKey {
        case name
        case running
        case enabled
        case role
        case lifecycle
        case activePublicId = "active_public_id"
        case rssBytes = "rss_bytes"
        case cpuPercent = "cpu_percent"
        case owned
    }
}

struct ProcessSummaryResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessSummaryData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessSummaryData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct PushBetaConfigRead: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let enabled: Bool
    let userPublicIds: [String]

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        enabled: Bool,
        userPublicIds: [String]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.enabled = enabled
        self.userPublicIds = userPublicIds
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case enabled
        case userPublicIds = "user_public_ids"
    }
}

struct PushBetaConfigResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: PushBetaConfigRead

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: PushBetaConfigRead
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RefreshData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let message: String
    let wsToken: String
    let wsTokenExp: Date
    let csrfToken: String
    let user: UserProfile
    let accessToken: String?
    let refreshToken: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        message: String,
        wsToken: String,
        wsTokenExp: Date,
        csrfToken: String,
        user: UserProfile,
        accessToken: String? = nil,
        refreshToken: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.message = message
        self.wsToken = wsToken
        self.wsTokenExp = wsTokenExp
        self.csrfToken = csrfToken
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case message
        case wsToken = "ws_token"
        case wsTokenExp = "ws_token_exp"
        case csrfToken = "csrf_token"
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct RefreshResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RefreshData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RefreshData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RelatedInstrumentData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrumentPublicId: String
    let nativeSymbol: String
    let exchange: String
    let assetType: String
    let relationshipType: String
    let contractFamily: String?
    let isSelected: Bool

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrumentPublicId: String,
        nativeSymbol: String,
        exchange: String,
        assetType: String,
        relationshipType: String,
        contractFamily: String?,
        isSelected: Bool
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrumentPublicId = instrumentPublicId
        self.nativeSymbol = nativeSymbol
        self.exchange = exchange
        self.assetType = assetType
        self.relationshipType = relationshipType
        self.contractFamily = contractFamily
        self.isSelected = isSelected
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrumentPublicId = "instrument_public_id"
        case nativeSymbol = "native_symbol"
        case exchange
        case assetType = "asset_type"
        case relationshipType = "relationship_type"
        case contractFamily = "contract_family"
        case isSelected = "is_selected"
    }
}

struct RelatedInstrumentsGroup: Codable, Sendable {
    let relationshipType: String
    let label: String
    let items: [RelatedInstrumentData]

    init(
        relationshipType: String,
        label: String,
        items: [RelatedInstrumentData]
    ) {
        self.relationshipType = relationshipType
        self.label = label
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case relationshipType = "relationship_type"
        case label
        case items
    }
}

struct RelatedInstrumentsPayloadData: Codable, Sendable {
    let selected: RelatedInstrumentsSelected
    let underlying: RelatedInstrumentsUnderlying?
    let groups: [RelatedInstrumentsGroup]

    init(
        selected: RelatedInstrumentsSelected,
        underlying: RelatedInstrumentsUnderlying?,
        groups: [RelatedInstrumentsGroup]
    ) {
        self.selected = selected
        self.underlying = underlying
        self.groups = groups
    }
}

struct RelatedInstrumentsResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RelatedInstrumentsPayloadData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RelatedInstrumentsPayloadData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RelatedInstrumentsSelected: Codable, Sendable {
    let exchange: String
    let nativeSymbol: String

    init(
        exchange: String,
        nativeSymbol: String
    ) {
        self.exchange = exchange
        self.nativeSymbol = nativeSymbol
    }

    enum CodingKeys: String, CodingKey {
        case exchange
        case nativeSymbol = "native_symbol"
    }
}

struct RelatedInstrumentsUnderlying: Codable, Sendable {
    let publicId: String
    let ticker: String
    let name: String
    let assetClass: String
    let sector: String?
    let description: String?

    init(
        publicId: String,
        ticker: String,
        name: String,
        assetClass: String,
        sector: String?,
        description: String?
    ) {
        self.publicId = publicId
        self.ticker = ticker
        self.name = name
        self.assetClass = assetClass
        self.sector = sector
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case publicId = "public_id"
        case ticker
        case name
        case assetClass = "asset_class"
        case sector
        case description
    }
}

struct RestRateData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let exchanges: [String: RestRateExchangeStats]

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        exchanges: [String: RestRateExchangeStats]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.exchanges = exchanges
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case exchanges
    }
}

struct RestRateExchangeStats: Codable, Sendable {
    let rps1S: Double
    let rps10S: Double
    let rps60S: Double
    let limitRps: Double?
    let utilization: Double?

    init(
        rps1S: Double,
        rps10S: Double,
        rps60S: Double,
        limitRps: Double? = nil,
        utilization: Double? = nil
    ) {
        self.rps1S = rps1S
        self.rps10S = rps10S
        self.rps60S = rps60S
        self.limitRps = limitRps
        self.utilization = utilization
    }

    enum CodingKeys: String, CodingKey {
        case rps1S = "rps_1s"
        case rps10S = "rps_10s"
        case rps60S = "rps_60s"
        case limitRps = "limit_rps"
        case utilization
    }
}

struct RestRateResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RestRateData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RestRateData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RetentionPolicyResult: Codable, Sendable {
    let table: String
    let retainDays: Int
    let backlogLookbackDays: Int
    let dayStart: String?
    let dayEnd: String?
    let archivedRows: Int
    let purgedRows: Int
    let filesWritten: Int
    let error: String?

    init(
        table: String,
        retainDays: Int,
        backlogLookbackDays: Int,
        dayStart: String?,
        dayEnd: String?,
        archivedRows: Int,
        purgedRows: Int,
        filesWritten: Int,
        error: String?
    ) {
        self.table = table
        self.retainDays = retainDays
        self.backlogLookbackDays = backlogLookbackDays
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.archivedRows = archivedRows
        self.purgedRows = purgedRows
        self.filesWritten = filesWritten
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case table
        case retainDays = "retain_days"
        case backlogLookbackDays = "backlog_lookback_days"
        case dayStart = "day_start"
        case dayEnd = "day_end"
        case archivedRows = "archived_rows"
        case purgedRows = "purged_rows"
        case filesWritten = "files_written"
        case error
    }
}

struct RetentionRunData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let runStartedAt: Date
    let runCompletedAt: Date
    let dryRun: Bool
    let results: [RetentionPolicyResult]

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        runStartedAt: Date,
        runCompletedAt: Date,
        dryRun: Bool,
        results: [RetentionPolicyResult]
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.runStartedAt = runStartedAt
        self.runCompletedAt = runCompletedAt
        self.dryRun = dryRun
        self.results = results
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case runStartedAt = "run_started_at"
        case runCompletedAt = "run_completed_at"
        case dryRun = "dry_run"
        case results
    }
}

struct RetentionRunResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RetentionRunData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RetentionRunData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RevokeDevicePrefResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DeviceAlertPrefInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DeviceAlertPrefInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RevokeScopeGrantResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ScopeGrantInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ScopeGrantInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RollPointDetail: Codable, Sendable {
    let fromContract: String
    let toContract: String
    let rollAt: String

    init(
        fromContract: String,
        toContract: String,
        rollAt: String
    ) {
        self.fromContract = fromContract
        self.toContract = toContract
        self.rollAt = rollAt
    }

    enum CodingKeys: String, CodingKey {
        case fromContract = "from_contract"
        case toContract = "to_contract"
        case rollAt = "roll_at"
    }
}

struct SaturationMetrics: Codable, Sendable {
    let threadsPct: Double?
    let fdsPct: Double?

    init(
        threadsPct: Double?,
        fdsPct: Double?
    ) {
        self.threadsPct = threadsPct
        self.fdsPct = fdsPct
    }

    enum CodingKeys: String, CodingKey {
        case threadsPct = "threads_pct"
        case fdsPct = "fds_pct"
    }
}

struct ScopeGrantInfo: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let operatorPublicId: String
    let walletPublicId: String
    let grantedByUserPublicId: String
    let scopeKind: String
    let underlyingPublicId: String?
    let instrumentPublicId: String?
    let note: String?
    let knownTo: Date

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        operatorPublicId: String,
        walletPublicId: String,
        grantedByUserPublicId: String,
        scopeKind: String,
        underlyingPublicId: String? = nil,
        instrumentPublicId: String? = nil,
        note: String? = nil,
        knownTo: Date
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.operatorPublicId = operatorPublicId
        self.walletPublicId = walletPublicId
        self.grantedByUserPublicId = grantedByUserPublicId
        self.scopeKind = scopeKind
        self.underlyingPublicId = underlyingPublicId
        self.instrumentPublicId = instrumentPublicId
        self.note = note
        self.knownTo = knownTo
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case operatorPublicId = "operator_public_id"
        case walletPublicId = "wallet_public_id"
        case grantedByUserPublicId = "granted_by_user_public_id"
        case scopeKind = "scope_kind"
        case underlyingPublicId = "underlying_public_id"
        case instrumentPublicId = "instrument_public_id"
        case note
        case knownTo = "known_to"
    }
}

struct ScopeGrantListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [ScopeGrantInfo]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [ScopeGrantInfo],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct ScopeGrantResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ScopeGrantInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ScopeGrantInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct SettingCategoriesResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [String]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [String],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct SettingListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [SettingRead]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [SettingRead],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct SettingRead: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let key: String
    let value: String
    let category: String
    let description: String?
    let updatedAt: Date
    let updatedBy: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        key: String,
        value: String,
        category: String,
        description: String? = nil,
        updatedAt: Date,
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
        self.description = description
        self.updatedAt = updatedAt
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
        case description
        case updatedAt = "updated_at"
        case updatedBy = "updated_by"
    }
}

struct SettingResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: SettingRead

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: SettingRead
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct SignalData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrument: String
    let exchange: String
    let side: String
    let strength: Double
    let reason: String
    let price: Double?
    let strategyName: String?
    let firedAt: Date
    let walletPublicId: String?
    let operatorPublicId: String?
    let userPublicId: String?
    let aiReviewPublicId: String?
    let aiReviewDispatchVersion: Int?
    let pairedGroupId: String?
    let pairedGroupSize: Int?
    let pairedGroupIndex: Int?
    let pairedGroupPolicy: String?
    let pairedGroupKey: String?
    let origin: String?
    let replayWindowStart: Date?
    let replayWindowEnd: Date?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrument: String,
        exchange: String,
        side: String,
        strength: Double,
        reason: String,
        price: Double? = nil,
        strategyName: String? = nil,
        firedAt: Date,
        walletPublicId: String? = nil,
        operatorPublicId: String? = nil,
        userPublicId: String? = nil,
        aiReviewPublicId: String? = nil,
        aiReviewDispatchVersion: Int? = nil,
        pairedGroupId: String? = nil,
        pairedGroupSize: Int? = nil,
        pairedGroupIndex: Int? = nil,
        pairedGroupPolicy: String? = nil,
        pairedGroupKey: String? = nil,
        origin: String? = nil,
        replayWindowStart: Date? = nil,
        replayWindowEnd: Date? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrument = instrument
        self.exchange = exchange
        self.side = side
        self.strength = strength
        self.reason = reason
        self.price = price
        self.strategyName = strategyName
        self.firedAt = firedAt
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.userPublicId = userPublicId
        self.aiReviewPublicId = aiReviewPublicId
        self.aiReviewDispatchVersion = aiReviewDispatchVersion
        self.pairedGroupId = pairedGroupId
        self.pairedGroupSize = pairedGroupSize
        self.pairedGroupIndex = pairedGroupIndex
        self.pairedGroupPolicy = pairedGroupPolicy
        self.pairedGroupKey = pairedGroupKey
        self.origin = origin
        self.replayWindowStart = replayWindowStart
        self.replayWindowEnd = replayWindowEnd
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
        case side
        case strength
        case reason
        case price
        case strategyName = "strategy_name"
        case firedAt = "fired_at"
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case userPublicId = "user_public_id"
        case aiReviewPublicId = "ai_review_public_id"
        case aiReviewDispatchVersion = "ai_review_dispatch_version"
        case pairedGroupId = "paired_group_id"
        case pairedGroupSize = "paired_group_size"
        case pairedGroupIndex = "paired_group_index"
        case pairedGroupPolicy = "paired_group_policy"
        case pairedGroupKey = "paired_group_key"
        case origin
        case replayWindowStart = "replay_window_start"
        case replayWindowEnd = "replay_window_end"
    }
}

struct SignalDiffEntry: Codable, Sendable {
    let instrument: String
    let signalTime: Date
    let signalType: String
    let leg: String

    init(
        instrument: String,
        signalTime: Date,
        signalType: String,
        leg: String
    ) {
        self.instrument = instrument
        self.signalTime = signalTime
        self.signalType = signalType
        self.leg = leg
    }

    enum CodingKeys: String, CodingKey {
        case instrument
        case signalTime = "signal_time"
        case signalType = "signal_type"
        case leg
    }
}

struct SignalListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [SignalData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [SignalData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct StrategyListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [StrategyProcess]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [StrategyProcess],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct StrategyProcess: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let name: String
    let running: Bool
    let enabled: Bool
    let mode: String
    let strategyClass: String?
    let coordinator: String?
    let coordinatorLabel: String?
    let managedRemotely: Bool?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        name: String,
        running: Bool,
        enabled: Bool,
        mode: String,
        strategyClass: String? = nil,
        coordinator: String? = nil,
        coordinatorLabel: String? = nil,
        managedRemotely: Bool? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.name = name
        self.running = running
        self.enabled = enabled
        self.mode = mode
        self.strategyClass = strategyClass
        self.coordinator = coordinator
        self.coordinatorLabel = coordinatorLabel
        self.managedRemotely = managedRemotely
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case name
        case running
        case enabled
        case mode
        case strategyClass = "strategy_class"
        case coordinator
        case coordinatorLabel = "coordinator_label"
        case managedRemotely = "managed_remotely"
    }
}

struct StrategyStatusPayload: Codable, Sendable {
    let strategyName: String
    let status: String
    let details: JsonObject?
    let signalsGenerated: Int?
    let tradesExecuted: Int?
    let lastSignal: String?
    let lastSignalTime: String?
    let pnl: Double?
    let pid: Int?
    let uptime: String?

    init(
        strategyName: String,
        status: String,
        details: JsonObject? = nil,
        signalsGenerated: Int? = nil,
        tradesExecuted: Int? = nil,
        lastSignal: String? = nil,
        lastSignalTime: String? = nil,
        pnl: Double? = nil,
        pid: Int? = nil,
        uptime: String? = nil
    ) {
        self.strategyName = strategyName
        self.status = status
        self.details = details
        self.signalsGenerated = signalsGenerated
        self.tradesExecuted = tradesExecuted
        self.lastSignal = lastSignal
        self.lastSignalTime = lastSignalTime
        self.pnl = pnl
        self.pid = pid
        self.uptime = uptime
    }

    enum CodingKeys: String, CodingKey {
        case strategyName = "strategy_name"
        case status
        case details
        case signalsGenerated = "signals_generated"
        case tradesExecuted = "trades_executed"
        case lastSignal = "last_signal"
        case lastSignalTime = "last_signal_time"
        case pnl
        case pid
        case uptime
    }
}

struct SubscriptionsStats: Codable, Sendable {
    let perTopic: [String: Int]
    let perClient: [String: [String]]

    init(
        perTopic: [String: Int],
        perClient: [String: [String]]
    ) {
        self.perTopic = perTopic
        self.perClient = perClient
    }

    enum CodingKeys: String, CodingKey {
        case perTopic = "per_topic"
        case perClient = "per_client"
    }
}

struct SystemMetricsData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let busTime: Date
    let process: ProcessMetrics
    let cpu: CpuMetrics
    let memory: MemoryMetrics
    let asyncio: AsyncioMetrics
    let gc: GcMetrics
    let limits: LimitsMetrics
    let saturation: SaturationMetrics
    let dbInternal: DbInternalMetrics
    let disk: DiskMetrics
    let tracemallocActive: Bool
    let cgroupVersion: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        busTime: Date,
        process: ProcessMetrics,
        cpu: CpuMetrics,
        memory: MemoryMetrics,
        asyncio: AsyncioMetrics,
        gc: GcMetrics,
        limits: LimitsMetrics,
        saturation: SaturationMetrics,
        dbInternal: DbInternalMetrics,
        disk: DiskMetrics,
        tracemallocActive: Bool,
        cgroupVersion: String?
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.busTime = busTime
        self.process = process
        self.cpu = cpu
        self.memory = memory
        self.asyncio = asyncio
        self.gc = gc
        self.limits = limits
        self.saturation = saturation
        self.dbInternal = dbInternal
        self.disk = disk
        self.tracemallocActive = tracemallocActive
        self.cgroupVersion = cgroupVersion
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case busTime = "bus_time"
        case process
        case cpu
        case memory
        case asyncio
        case gc
        case limits
        case saturation
        case dbInternal = "db_internal"
        case disk
        case tracemallocActive = "tracemalloc_active"
        case cgroupVersion = "cgroup_version"
    }
}

struct SystemMetricsHistoryItem: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let busTime: Date
    let process: ProcessMetrics
    let cpu: CpuMetrics
    let memory: MemoryMetrics
    let asyncio: AsyncioMetrics
    let gc: GcMetrics
    let limits: LimitsMetrics
    let saturation: SaturationMetrics
    let dbInternal: DbInternalMetrics
    let disk: DiskMetrics
    let tracemallocActive: Bool
    let cgroupVersion: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        busTime: Date,
        process: ProcessMetrics,
        cpu: CpuMetrics,
        memory: MemoryMetrics,
        asyncio: AsyncioMetrics,
        gc: GcMetrics,
        limits: LimitsMetrics,
        saturation: SaturationMetrics,
        dbInternal: DbInternalMetrics,
        disk: DiskMetrics,
        tracemallocActive: Bool,
        cgroupVersion: String?
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.busTime = busTime
        self.process = process
        self.cpu = cpu
        self.memory = memory
        self.asyncio = asyncio
        self.gc = gc
        self.limits = limits
        self.saturation = saturation
        self.dbInternal = dbInternal
        self.disk = disk
        self.tracemallocActive = tracemallocActive
        self.cgroupVersion = cgroupVersion
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case busTime = "bus_time"
        case process
        case cpu
        case memory
        case asyncio
        case gc
        case limits
        case saturation
        case dbInternal = "db_internal"
        case disk
        case tracemallocActive = "tracemalloc_active"
        case cgroupVersion = "cgroup_version"
    }
}

struct SystemMetricsHistoryResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [SystemMetricsHistoryItem]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [SystemMetricsHistoryItem],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct SystemMetricsResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: SystemMetricsData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: SystemMetricsData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct SystemStatusData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let trader: ProcessStatus
    let backtests: [String: ProcessStatus]
    let strategies: [StrategyStatusPayload]?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        trader: ProcessStatus,
        backtests: [String: ProcessStatus],
        strategies: [StrategyStatusPayload]? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.trader = trader
        self.backtests = backtests
        self.strategies = strategies
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case trader
        case backtests
        case strategies
    }
}

struct SystemStatusResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: SystemStatusData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: SystemStatusData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct TableStatsItem: Codable, Sendable {
    let table: String
    let tableKind: String
    let total: Int?
    let current: Int?
    let closed: Int?
    let archivable: Int?
    let isStale: Bool
    let lastSampledAt: Date

    init(
        table: String,
        tableKind: String,
        total: Int?,
        current: Int?,
        closed: Int?,
        archivable: Int?,
        isStale: Bool,
        lastSampledAt: Date
    ) {
        self.table = table
        self.tableKind = tableKind
        self.total = total
        self.current = current
        self.closed = closed
        self.archivable = archivable
        self.isStale = isStale
        self.lastSampledAt = lastSampledAt
    }

    enum CodingKeys: String, CodingKey {
        case table
        case tableKind = "table_kind"
        case total
        case current
        case closed
        case archivable
        case isStale = "is_stale"
        case lastSampledAt = "last_sampled_at"
    }
}

struct TopicMetricSnapshot: Codable, Sendable {
    let activeSubscribers: Int?
    let received: Int?
    let forwarded: Int?
    let throttled: Int?
    let dropped: Int?
    let timeout: Int?
    let errors: Int?
    let invalidMessages: Int?
    let lastMessageTs: Double?
    let throttleMs: Int?
    let pattern: String?

    init(
        activeSubscribers: Int? = nil,
        received: Int? = nil,
        forwarded: Int? = nil,
        throttled: Int? = nil,
        dropped: Int? = nil,
        timeout: Int? = nil,
        errors: Int? = nil,
        invalidMessages: Int? = nil,
        lastMessageTs: Double? = nil,
        throttleMs: Int? = nil,
        pattern: String? = nil
    ) {
        self.activeSubscribers = activeSubscribers
        self.received = received
        self.forwarded = forwarded
        self.throttled = throttled
        self.dropped = dropped
        self.timeout = timeout
        self.errors = errors
        self.invalidMessages = invalidMessages
        self.lastMessageTs = lastMessageTs
        self.throttleMs = throttleMs
        self.pattern = pattern
    }

    enum CodingKeys: String, CodingKey {
        case activeSubscribers = "active_subscribers"
        case received
        case forwarded
        case throttled
        case dropped
        case timeout
        case errors
        case invalidMessages = "invalid_messages"
        case lastMessageTs = "last_message_ts"
        case throttleMs = "throttle_ms"
        case pattern
    }
}

struct TracemallocState: Codable, Sendable {
    let active: Bool
    let requestedDurationSeconds: Double?

    init(
        active: Bool,
        requestedDurationSeconds: Double?
    ) {
        self.active = active
        self.requestedDurationSeconds = requestedDurationSeconds
    }

    enum CodingKeys: String, CodingKey {
        case active
        case requestedDurationSeconds = "requested_duration_seconds"
    }
}

struct TracemallocStateResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: TracemallocState

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: TracemallocState
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct TradeDiffEntry: Codable, Sendable {
    let instrument: String
    let executedAt: Date
    let side: String
    let quantity: Double
    let price: Double
    let leg: String
    let pnlA: Double?
    let pnlB: Double?
    let pnlDelta: Double?

    init(
        instrument: String,
        executedAt: Date,
        side: String,
        quantity: Double,
        price: Double,
        leg: String,
        pnlA: Double? = nil,
        pnlB: Double? = nil,
        pnlDelta: Double? = nil
    ) {
        self.instrument = instrument
        self.executedAt = executedAt
        self.side = side
        self.quantity = quantity
        self.price = price
        self.leg = leg
        self.pnlA = pnlA
        self.pnlB = pnlB
        self.pnlDelta = pnlDelta
    }

    enum CodingKeys: String, CodingKey {
        case instrument
        case executedAt = "executed_at"
        case side
        case quantity
        case price
        case leg
        case pnlA = "pnl_a"
        case pnlB = "pnl_b"
        case pnlDelta = "pnl_delta"
    }
}

struct TrailingStopStateData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let planPublicId: String
    let status: String
    let trailingPct: Double
    let minLockPct: Double
    let entryPrice: Double
    let peakPrice: Double
    let currentStop: Double
    let side: String

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        planPublicId: String,
        status: String,
        trailingPct: Double,
        minLockPct: Double,
        entryPrice: Double,
        peakPrice: Double,
        currentStop: Double,
        side: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.planPublicId = planPublicId
        self.status = status
        self.trailingPct = trailingPct
        self.minLockPct = minLockPct
        self.entryPrice = entryPrice
        self.peakPrice = peakPrice
        self.currentStop = currentStop
        self.side = side
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case planPublicId = "plan_public_id"
        case status
        case trailingPct = "trailing_pct"
        case minLockPct = "min_lock_pct"
        case entryPrice = "entry_price"
        case peakPrice = "peak_price"
        case currentStop = "current_stop"
        case side
    }
}

struct TrailingStopStateResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: TrailingStopStateData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: TrailingStopStateData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct UnderlyingAssetData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let ticker: String
    let name: String
    let assetClass: String
    let sector: String?
    let description: String?
    let instrumentCount: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        ticker: String,
        name: String,
        assetClass: String,
        sector: String?,
        description: String?,
        instrumentCount: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.ticker = ticker
        self.name = name
        self.assetClass = assetClass
        self.sector = sector
        self.description = description
        self.instrumentCount = instrumentCount
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case ticker
        case name
        case assetClass = "asset_class"
        case sector
        case description
        case instrumentCount = "instrument_count"
    }
}

struct UnderlyingAssetListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [UnderlyingAssetData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [UnderlyingAssetData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct UnderlyingInstrumentData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let instrumentPublicId: String
    let nativeSymbol: String
    let exchange: String
    let assetType: String
    let relationshipType: String
    let contractFamily: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        instrumentPublicId: String,
        nativeSymbol: String,
        exchange: String,
        assetType: String,
        relationshipType: String,
        contractFamily: String?
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.instrumentPublicId = instrumentPublicId
        self.nativeSymbol = nativeSymbol
        self.exchange = exchange
        self.assetType = assetType
        self.relationshipType = relationshipType
        self.contractFamily = contractFamily
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case instrumentPublicId = "instrument_public_id"
        case nativeSymbol = "native_symbol"
        case exchange
        case assetType = "asset_type"
        case relationshipType = "relationship_type"
        case contractFamily = "contract_family"
    }
}

struct UnderlyingInstrumentListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [UnderlyingInstrumentData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [UnderlyingInstrumentData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct UserAlertDefaultInfo: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let userPublicId: String
    let alertType: String
    let enabled: Bool
    let minPriority: String

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        userPublicId: String,
        alertType: String,
        enabled: Bool,
        minPriority: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.userPublicId = userPublicId
        self.alertType = alertType
        self.enabled = enabled
        self.minPriority = minPriority
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case userPublicId = "user_public_id"
        case alertType = "alert_type"
        case enabled
        case minPriority = "min_priority"
    }
}

struct UserAlertDefaultListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [UserAlertDefaultInfo]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [UserAlertDefaultInfo],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct UserAlertDefaultResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: UserAlertDefaultInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: UserAlertDefaultInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct UserListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [UserProfile]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [UserProfile],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct UserProfile: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let username: String
    let email: String?
    let role: UserRole
    let isActive: Bool?
    let createdAt: Date
    let operatorPublicIds: [String]?
    let primaryOperatorPublicId: String?
    let activeWalletPublicId: String?
    let defaultLanguage: String?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        username: String,
        email: String? = nil,
        role: UserRole,
        isActive: Bool? = nil,
        createdAt: Date,
        operatorPublicIds: [String]? = nil,
        primaryOperatorPublicId: String? = nil,
        activeWalletPublicId: String? = nil,
        defaultLanguage: String? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.username = username
        self.email = email
        self.role = role
        self.isActive = isActive
        self.createdAt = createdAt
        self.operatorPublicIds = operatorPublicIds
        self.primaryOperatorPublicId = primaryOperatorPublicId
        self.activeWalletPublicId = activeWalletPublicId
        self.defaultLanguage = defaultLanguage
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case username
        case email
        case role
        case isActive = "is_active"
        case createdAt = "created_at"
        case operatorPublicIds = "operator_public_ids"
        case primaryOperatorPublicId = "primary_operator_public_id"
        case activeWalletPublicId = "active_wallet_public_id"
        case defaultLanguage = "default_language"
    }
}

struct UserResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: UserProfile

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: UserProfile
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ValidationError: Codable, Sendable {
    let loc: [AnyCodable?]
    let msg: String
    let type: String
    let input: AnyCodable?
    let ctx: [String: AnyCodable]?

    init(
        loc: [AnyCodable?],
        msg: String,
        type: String,
        input: AnyCodable? = nil,
        ctx: [String: AnyCodable]? = nil
    ) {
        self.loc = loc
        self.msg = msg
        self.type = type
        self.input = input
        self.ctx = ctx
    }
}

struct VenueFeeScheduleData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let exchange: String
    let instrumentPublicId: String?
    let feeTier: String
    let makerBps: Double
    let takerBps: Double
    let minVolume30D: Double?
    let currency: String

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        exchange: String,
        instrumentPublicId: String?,
        feeTier: String,
        makerBps: Double,
        takerBps: Double,
        minVolume30D: Double?,
        currency: String
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.exchange = exchange
        self.instrumentPublicId = instrumentPublicId
        self.feeTier = feeTier
        self.makerBps = makerBps
        self.takerBps = takerBps
        self.minVolume30D = minVolume30D
        self.currency = currency
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case exchange
        case instrumentPublicId = "instrument_public_id"
        case feeTier = "fee_tier"
        case makerBps = "maker_bps"
        case takerBps = "taker_bps"
        case minVolume30D = "min_volume_30d"
        case currency
    }
}

struct VenueFeeScheduleListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [VenueFeeScheduleData]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [VenueFeeScheduleData],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct WalletInfo: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let label: String
    let description: String?
    let isPaper: Bool

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        label: String,
        description: String? = nil,
        isPaper: Bool
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.label = label
        self.description = description
        self.isPaper = isPaper
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case label
        case description
        case isPaper = "is_paper"
    }
}

struct WalletListResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: [WalletInfo]
    let count: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: [WalletInfo],
        count: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
        self.count = count
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
        case count
    }
}

struct WalletResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: WalletInfo

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: WalletInfo
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct WebSocketStats: Codable, Sendable {
    let activeConnections: Int
    let topicSubscribers: [String: Int]
    let clientCount: Int

    init(
        activeConnections: Int,
        topicSubscribers: [String: Int],
        clientCount: Int
    ) {
        self.activeConnections = activeConnections
        self.topicSubscribers = topicSubscribers
        self.clientCount = clientCount
    }

    enum CodingKeys: String, CodingKey {
        case activeConnections = "active_connections"
        case topicSubscribers = "topic_subscribers"
        case clientCount = "client_count"
    }
}

struct WsStatsConfig: Codable, Sendable {
    let brokerXpub: String
    let heartbeatIntervalMs: Int

    init(
        brokerXpub: String,
        heartbeatIntervalMs: Int
    ) {
        self.brokerXpub = brokerXpub
        self.heartbeatIntervalMs = heartbeatIntervalMs
    }

    enum CodingKeys: String, CodingKey {
        case brokerXpub = "broker_xpub"
        case heartbeatIntervalMs = "heartbeat_interval_ms"
    }
}

struct WsStatsData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let websocket: WebSocketStats
    let zmqBridge: ZmqBridgeStats
    let connections: ConnectionStats
    let topics: [String: TopicMetricSnapshot]
    let subscriptions: SubscriptionsStats
    let config: WsStatsConfig

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        websocket: WebSocketStats,
        zmqBridge: ZmqBridgeStats,
        connections: ConnectionStats,
        topics: [String: TopicMetricSnapshot],
        subscriptions: SubscriptionsStats,
        config: WsStatsConfig
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.websocket = websocket
        self.zmqBridge = zmqBridge
        self.connections = connections
        self.topics = topics
        self.subscriptions = subscriptions
        self.config = config
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case websocket
        case zmqBridge = "zmq_bridge"
        case connections
        case topics
        case subscriptions
        case config
    }
}

struct WsStatsResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: WsStatsData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: WsStatsData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct WsTokenData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let message: String
    let wsToken: String
    let wsTokenExp: Date
    let expiresIn: Int

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        message: String,
        wsToken: String,
        wsTokenExp: Date,
        expiresIn: Int
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.message = message
        self.wsToken = wsToken
        self.wsTokenExp = wsTokenExp
        self.expiresIn = expiresIn
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case message
        case wsToken = "ws_token"
        case wsTokenExp = "ws_token_exp"
        case expiresIn = "expires_in"
    }
}

struct WsTokenResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: WsTokenData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: WsTokenData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ZmqBridgeStats: Codable, Sendable {
    let activeTopics: Int
    let subscriberTasks: Int
    let availableTopics: [String]

    init(
        activeTopics: Int,
        subscriberTasks: Int,
        availableTopics: [String]
    ) {
        self.activeTopics = activeTopics
        self.subscriberTasks = subscriberTasks
        self.availableTopics = availableTopics
    }

    enum CodingKeys: String, CodingKey {
        case activeTopics = "active_topics"
        case subscriberTasks = "subscriber_tasks"
        case availableTopics = "available_topics"
    }
}

struct ZmqComponents: Codable, Sendable {
    let zmqContext: String
    let websocketManager: String
    let activeConnections: Int

    init(
        zmqContext: String,
        websocketManager: String,
        activeConnections: Int
    ) {
        self.zmqContext = zmqContext
        self.websocketManager = websocketManager
        self.activeConnections = activeConnections
    }

    enum CodingKeys: String, CodingKey {
        case zmqContext = "zmq_context"
        case websocketManager = "websocket_manager"
        case activeConnections = "active_connections"
    }
}

struct ZmqConfig: Codable, Sendable {
    let availableTopics: [String]

    init(
        availableTopics: [String]
    ) {
        self.availableTopics = availableTopics
    }

    enum CodingKeys: String, CodingKey {
        case availableTopics = "available_topics"
    }
}

struct ZmqHealthData: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let status: String
    let components: ZmqComponents
    let config: ZmqConfig
    let connections: ConnectionStats
    let messageStats: [String: TopicMetricSnapshot]
    let errors: [String]?

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        status: String,
        components: ZmqComponents,
        config: ZmqConfig,
        connections: ConnectionStats,
        messageStats: [String: TopicMetricSnapshot],
        errors: [String]? = nil
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.status = status
        self.components = components
        self.config = config
        self.connections = connections
        self.messageStats = messageStats
        self.errors = errors
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case status
        case components
        case config
        case connections
        case messageStats = "message_stats"
        case errors
    }
}

struct ZmqHealthResponse: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ZmqHealthData

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ZmqHealthData
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct LoginRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: LoginBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: LoginBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct LoginBody: Codable, Sendable {
    let username: String
    let password: String
    let rememberMe: Bool?

    init(
        username: String,
        password: String,
        rememberMe: Bool? = nil
    ) {
        self.username = username
        self.password = password
        self.rememberMe = rememberMe
    }

    enum CodingKeys: String, CodingKey {
        case username
        case password
        case rememberMe = "remember_me"
    }
}

struct RefreshTokenRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RefreshTokenPayload

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RefreshTokenPayload
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RefreshTokenPayload: Codable, Sendable {
    let activeWalletPublicId: String?
    let clearActiveWallet: Bool?

    init(
        activeWalletPublicId: String? = nil,
        clearActiveWallet: Bool? = nil
    ) {
        self.activeWalletPublicId = activeWalletPublicId
        self.clearActiveWallet = clearActiveWallet
    }

    enum CodingKeys: String, CodingKey {
        case activeWalletPublicId = "active_wallet_public_id"
        case clearActiveWallet = "clear_active_wallet"
    }
}

struct UpdateAuthMeRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: UpdateAuthMeBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: UpdateAuthMeBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct UpdateAuthMeBody: Codable, Sendable {
    let defaultLanguage: String?

    init(
        defaultLanguage: String? = nil
    ) {
        self.defaultLanguage = defaultLanguage
    }

    enum CodingKeys: String, CodingKey {
        case defaultLanguage = "default_language"
    }
}

struct CreateUserRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CreateUserBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CreateUserBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CreateUserBody: Codable, Sendable {
    let username: String
    let email: String?
    let password: String
    let role: UserRole
    let isActive: Bool?

    init(
        username: String,
        email: String? = nil,
        password: String,
        role: UserRole,
        isActive: Bool? = nil
    ) {
        self.username = username
        self.email = email
        self.password = password
        self.role = role
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case username
        case email
        case password
        case role
        case isActive = "is_active"
    }
}

struct UpdateUserRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: UpdateUserBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: UpdateUserBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct UpdateUserBody: Codable, Sendable {
    let email: String?
    let role: UserRole?
    let isActive: Bool?

    init(
        email: String? = nil,
        role: UserRole? = nil,
        isActive: Bool? = nil
    ) {
        self.email = email
        self.role = role
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case email
        case role
        case isActive = "is_active"
    }
}

struct DeactivateUserRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DeactivateUserBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DeactivateUserBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct DeactivateUserBody: Codable, Sendable {
    let reason: String?

    init(
        reason: String? = nil
    ) {
        self.reason = reason
    }
}

struct ChangePasswordRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ChangePasswordBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ChangePasswordBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ChangePasswordBody: Codable, Sendable {
    let currentPassword: String
    let newPassword: String

    init(
        currentPassword: String,
        newPassword: String
    ) {
        self.currentPassword = currentPassword
        self.newPassword = newPassword
    }

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

struct AdminResetPasswordRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: AdminResetPasswordBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: AdminResetPasswordBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct AdminResetPasswordBody: Codable, Sendable {
    let newPassword: String

    init(
        newPassword: String
    ) {
        self.newPassword = newPassword
    }

    enum CodingKeys: String, CodingKey {
        case newPassword = "new_password"
    }
}

struct SettingUpdate: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: SettingUpdateBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: SettingUpdateBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct SettingUpdateBody: Codable, Sendable {
    let value: String
    let category: String?
    let description: String?

    init(
        value: String,
        category: String? = nil,
        description: String? = nil
    ) {
        self.value = value
        self.category = category
        self.description = description
    }
}

struct UpdatePushBetaUsersCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: PushBetaUsersBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: PushBetaUsersBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct PushBetaUsersBody: Codable, Sendable {
    let enabled: Bool
    let userPublicIds: [String]?

    init(
        enabled: Bool,
        userPublicIds: [String]? = nil
    ) {
        self.enabled = enabled
        self.userPublicIds = userPublicIds
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case userPublicIds = "user_public_ids"
    }
}

struct RemoveSettingRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RemoveSettingBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RemoveSettingBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RemoveSettingBody: Codable, Sendable {

    init(
    ) {
    }
}

struct DelegateCreateRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DelegateCreateBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DelegateCreateBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct DelegateCreateBody: Codable, Sendable {
    let label: String
    let caps: DelegateCapsBody?
    let operatorPublicId: String?

    init(
        label: String,
        caps: DelegateCapsBody? = nil,
        operatorPublicId: String? = nil
    ) {
        self.label = label
        self.caps = caps
        self.operatorPublicId = operatorPublicId
    }

    enum CodingKeys: String, CodingKey {
        case label
        case caps
        case operatorPublicId = "operator_public_id"
    }
}

struct DelegateCapsUpdateRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DelegateCapsUpdateBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DelegateCapsUpdateBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct DelegateCapsUpdateBody: Codable, Sendable {
    let caps: DelegateCapsBody

    init(
        caps: DelegateCapsBody
    ) {
        self.caps = caps
    }
}

struct DelegateDeactivateRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DelegateDeactivateBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DelegateDeactivateBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct DelegateDeactivateBody: Codable, Sendable {
    let reason: String?

    init(
        reason: String? = nil
    ) {
        self.reason = reason
    }
}

struct AiReviewDecisionCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: AiReviewDecisionRequest

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: AiReviewDecisionRequest
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct AiReviewDecisionRequest: Codable, Sendable {
    let decision: String
    let rationale: String?

    init(
        decision: String,
        rationale: String? = nil
    ) {
        self.decision = decision
        self.rationale = rationale
    }
}

struct UpdateUserAlertDefaultCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: UserAlertDefaultBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: UserAlertDefaultBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct UserAlertDefaultBody: Codable, Sendable {
    let alertType: String
    let enabled: Bool?
    let minPriority: String?

    init(
        alertType: String,
        enabled: Bool? = nil,
        minPriority: String? = nil
    ) {
        self.alertType = alertType
        self.enabled = enabled
        self.minPriority = minPriority
    }

    enum CodingKeys: String, CodingKey {
        case alertType = "alert_type"
        case enabled
        case minPriority = "min_priority"
    }
}

struct BacktestCreateCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: BacktestCreateBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: BacktestCreateBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct BacktestCreateBody: Codable, Sendable {
    let strategyClass: String
    let instrumentPublicId: String
    let exchange: String
    let timeframe: String?
    let startDate: Date
    let endDate: Date
    let initialCash: Double?
    let strategyParams: JsonObject?
    let executionMode: String?
    let fillModel: String?
    let slippageBps: Double?
    let commissionBps: Double?
    let targetExecutionExchange: String?

    init(
        strategyClass: String,
        instrumentPublicId: String,
        exchange: String,
        timeframe: String? = nil,
        startDate: Date,
        endDate: Date,
        initialCash: Double? = nil,
        strategyParams: JsonObject? = nil,
        executionMode: String? = nil,
        fillModel: String? = nil,
        slippageBps: Double? = nil,
        commissionBps: Double? = nil,
        targetExecutionExchange: String? = nil
    ) {
        self.strategyClass = strategyClass
        self.instrumentPublicId = instrumentPublicId
        self.exchange = exchange
        self.timeframe = timeframe
        self.startDate = startDate
        self.endDate = endDate
        self.initialCash = initialCash
        self.strategyParams = strategyParams
        self.executionMode = executionMode
        self.fillModel = fillModel
        self.slippageBps = slippageBps
        self.commissionBps = commissionBps
        self.targetExecutionExchange = targetExecutionExchange
    }

    enum CodingKeys: String, CodingKey {
        case strategyClass = "strategy_class"
        case instrumentPublicId = "instrument_public_id"
        case exchange
        case timeframe
        case startDate = "start_date"
        case endDate = "end_date"
        case initialCash = "initial_cash"
        case strategyParams = "strategy_params"
        case executionMode = "execution_mode"
        case fillModel = "fill_model"
        case slippageBps = "slippage_bps"
        case commissionBps = "commission_bps"
        case targetExecutionExchange = "target_execution_exchange"
    }
}

struct BacktestCompareRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: BacktestCompareBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: BacktestCompareBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct BacktestCompareBody: Codable, Sendable {
    let mode: String
    let runAPublicId: String?
    let runBPublicId: String?
    let configHash: String?
    let anchorRunPublicId: String?

    init(
        mode: String,
        runAPublicId: String? = nil,
        runBPublicId: String? = nil,
        configHash: String? = nil,
        anchorRunPublicId: String? = nil
    ) {
        self.mode = mode
        self.runAPublicId = runAPublicId
        self.runBPublicId = runBPublicId
        self.configHash = configHash
        self.anchorRunPublicId = anchorRunPublicId
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case runAPublicId = "run_a_public_id"
        case runBPublicId = "run_b_public_id"
        case configHash = "config_hash"
        case anchorRunPublicId = "anchor_run_public_id"
    }
}

struct BacktestCancelCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: BacktestCancelBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: BacktestCancelBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct BacktestCancelBody: Codable, Sendable {
    let reason: String?

    init(
        reason: String? = nil
    ) {
        self.reason = reason
    }
}

struct CreateCredentialCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CreateCredentialBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CreateCredentialBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CreateCredentialBody: Codable, Sendable {
    let exchange: String
    let credentialType: String
    let reconciliationMethod: PortfolioReconciliationMethod
    let credentialPayload: [String: String]
    let label: String?

    init(
        exchange: String,
        credentialType: String,
        reconciliationMethod: PortfolioReconciliationMethod,
        credentialPayload: [String: String],
        label: String? = nil
    ) {
        self.exchange = exchange
        self.credentialType = credentialType
        self.reconciliationMethod = reconciliationMethod
        self.credentialPayload = credentialPayload
        self.label = label
    }

    enum CodingKeys: String, CodingKey {
        case exchange
        case credentialType = "credential_type"
        case reconciliationMethod = "reconciliation_method"
        case credentialPayload = "credential_payload"
        case label
    }
}

struct SetCredentialReconciliationMethodCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: SetCredentialReconciliationMethodBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: SetCredentialReconciliationMethodBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct SetCredentialReconciliationMethodBody: Codable, Sendable {
    let reconciliationMethod: RealPortfolioReconciliationMethod

    init(
        reconciliationMethod: RealPortfolioReconciliationMethod
    ) {
        self.reconciliationMethod = reconciliationMethod
    }

    enum CodingKeys: String, CodingKey {
        case reconciliationMethod = "reconciliation_method"
    }
}

struct RotateCredentialCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RotateCredentialBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RotateCredentialBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RotateCredentialBody: Codable, Sendable {
    let credentialPayload: [String: String]
    let label: String?

    init(
        credentialPayload: [String: String],
        label: String? = nil
    ) {
        self.credentialPayload = credentialPayload
        self.label = label
    }

    enum CodingKeys: String, CodingKey {
        case credentialPayload = "credential_payload"
        case label
    }
}

struct RegisterDeviceCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RegisterDeviceBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RegisterDeviceBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RegisterDeviceBody: Codable, Sendable {
    let deviceToken: String
    let deviceId: String
    let env: String
    let appVersion: String?
    let previewsMode: String?

    init(
        deviceToken: String,
        deviceId: String,
        env: String,
        appVersion: String? = nil,
        previewsMode: String? = nil
    ) {
        self.deviceToken = deviceToken
        self.deviceId = deviceId
        self.env = env
        self.appVersion = appVersion
        self.previewsMode = previewsMode
    }

    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case deviceId = "device_id"
        case env
        case appVersion = "app_version"
        case previewsMode = "previews_mode"
    }
}

struct UpdateDevicePrefCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: DeviceAlertPrefBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: DeviceAlertPrefBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct DeviceAlertPrefBody: Codable, Sendable {
    let alertType: String
    let operatorPublicId: String?
    let walletPublicId: String?
    let enabled: Bool?
    let minPriority: String?
    let quietHoursStartMin: Int?
    let quietHoursEndMin: Int?
    let muteUntil: Date?
    let timezone: String?

    init(
        alertType: String,
        operatorPublicId: String? = nil,
        walletPublicId: String? = nil,
        enabled: Bool? = nil,
        minPriority: String? = nil,
        quietHoursStartMin: Int? = nil,
        quietHoursEndMin: Int? = nil,
        muteUntil: Date? = nil,
        timezone: String? = nil
    ) {
        self.alertType = alertType
        self.operatorPublicId = operatorPublicId
        self.walletPublicId = walletPublicId
        self.enabled = enabled
        self.minPriority = minPriority
        self.quietHoursStartMin = quietHoursStartMin
        self.quietHoursEndMin = quietHoursEndMin
        self.muteUntil = muteUntil
        self.timezone = timezone
    }

    enum CodingKeys: String, CodingKey {
        case alertType = "alert_type"
        case operatorPublicId = "operator_public_id"
        case walletPublicId = "wallet_public_id"
        case enabled
        case minPriority = "min_priority"
        case quietHoursStartMin = "quiet_hours_start_min"
        case quietHoursEndMin = "quiet_hours_end_min"
        case muteUntil = "mute_until"
        case timezone
    }
}

struct RevokeDevicePrefCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RevokeDevicePrefBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RevokeDevicePrefBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RevokeDevicePrefBody: Codable, Sendable {
    let reason: String?

    init(
        reason: String? = nil
    ) {
        self.reason = reason
    }
}

struct BracketCreateCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: BracketCreateBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: BracketCreateBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct BracketCreateBody: Codable, Sendable {
    let positionCyclePublicId: String
    let slPrice: Double?
    let tpPrice: Double?
    let idempotencyKey: String?

    init(
        positionCyclePublicId: String,
        slPrice: Double? = nil,
        tpPrice: Double? = nil,
        idempotencyKey: String? = nil
    ) {
        self.positionCyclePublicId = positionCyclePublicId
        self.slPrice = slPrice
        self.tpPrice = tpPrice
        self.idempotencyKey = idempotencyKey
    }

    enum CodingKeys: String, CodingKey {
        case positionCyclePublicId = "position_cycle_public_id"
        case slPrice = "sl_price"
        case tpPrice = "tp_price"
        case idempotencyKey = "idempotency_key"
    }
}

struct BracketCancelCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: BracketCancelBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: BracketCancelBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct BracketCancelBody: Codable, Sendable {
    let reason: String?

    init(
        reason: String? = nil
    ) {
        self.reason = reason
    }
}

struct CreateOperatorCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CreateOperatorBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CreateOperatorBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CreateOperatorBody: Codable, Sendable {
    let label: String
    let description: String?

    init(
        label: String,
        description: String? = nil
    ) {
        self.label = label
        self.description = description
    }
}

struct CreateOrderCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CreateOrderBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CreateOrderBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CreateOrderBody: Codable, Sendable {
    let instrument: String
    let instrumentPublicId: String
    let exchange: String
    let mode: String?
    let side: String
    let orderType: String
    let quantity: Double
    let price: Double?
    let stopPrice: Double?
    let timeInForce: String?
    let postOnly: Bool?
    let leverage: Int?
    let reduceOnly: Bool?
    let walletPublicId: String?
    let operatorPublicId: String?
    let idempotencyKey: String?
    let aiReviewPublicId: String?

    init(
        instrument: String,
        instrumentPublicId: String,
        exchange: String,
        mode: String? = nil,
        side: String,
        orderType: String,
        quantity: Double,
        price: Double? = nil,
        stopPrice: Double? = nil,
        timeInForce: String? = nil,
        postOnly: Bool? = nil,
        leverage: Int? = nil,
        reduceOnly: Bool? = nil,
        walletPublicId: String? = nil,
        operatorPublicId: String? = nil,
        idempotencyKey: String? = nil,
        aiReviewPublicId: String? = nil
    ) {
        self.instrument = instrument
        self.instrumentPublicId = instrumentPublicId
        self.exchange = exchange
        self.mode = mode
        self.side = side
        self.orderType = orderType
        self.quantity = quantity
        self.price = price
        self.stopPrice = stopPrice
        self.timeInForce = timeInForce
        self.postOnly = postOnly
        self.leverage = leverage
        self.reduceOnly = reduceOnly
        self.walletPublicId = walletPublicId
        self.operatorPublicId = operatorPublicId
        self.idempotencyKey = idempotencyKey
        self.aiReviewPublicId = aiReviewPublicId
    }

    enum CodingKeys: String, CodingKey {
        case instrument
        case instrumentPublicId = "instrument_public_id"
        case exchange
        case mode
        case side
        case orderType = "order_type"
        case quantity
        case price
        case stopPrice = "stop_price"
        case timeInForce = "time_in_force"
        case postOnly = "post_only"
        case leverage
        case reduceOnly = "reduce_only"
        case walletPublicId = "wallet_public_id"
        case operatorPublicId = "operator_public_id"
        case idempotencyKey = "idempotency_key"
        case aiReviewPublicId = "ai_review_public_id"
    }
}

struct CancelOrderCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CancelOrderBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CancelOrderBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CancelOrderBody: Codable, Sendable {
    let reason: String?

    init(
        reason: String? = nil
    ) {
        self.reason = reason
    }
}

struct ProcessCreateRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessCreateBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessCreateBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessCreateBody: Codable, Sendable {
    let name: String
    let template: String
    let enabled: Bool?
    let mode: String?
    let parameters: JsonObject?
    let note: String?

    init(
        name: String,
        template: String,
        enabled: Bool? = nil,
        mode: String? = nil,
        parameters: JsonObject? = nil,
        note: String? = nil
    ) {
        self.name = name
        self.template = template
        self.enabled = enabled
        self.mode = mode
        self.parameters = parameters
        self.note = note
    }
}

struct ProcessStartRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessStartBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessStartBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessStartBody: Codable, Sendable {
    let mode: String?
    let parameters: JsonObject?

    init(
        mode: String? = nil,
        parameters: JsonObject? = nil
    ) {
        self.mode = mode
        self.parameters = parameters
    }
}

struct ProcessDesiredStateRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessDesiredStateBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessDesiredStateBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessDesiredStateBody: Codable, Sendable {
    let action: String
    let restartNonce: String?

    init(
        action: String,
        restartNonce: String? = nil
    ) {
        self.action = action
        self.restartNonce = restartNonce
    }

    enum CodingKeys: String, CodingKey {
        case action
        case restartNonce = "restart_nonce"
    }
}

struct ProcessConfigScopeRequest: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: ProcessConfigScopeBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: ProcessConfigScopeBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct ProcessConfigScopeBody: Codable, Sendable {
    let operatorPublicId: String?
    let walletPublicId: String?
    let referenceIdentityParams: [String: String]?

    init(
        operatorPublicId: String? = nil,
        walletPublicId: String? = nil,
        referenceIdentityParams: [String: String]? = nil
    ) {
        self.operatorPublicId = operatorPublicId
        self.walletPublicId = walletPublicId
        self.referenceIdentityParams = referenceIdentityParams
    }

    enum CodingKeys: String, CodingKey {
        case operatorPublicId = "operator_public_id"
        case walletPublicId = "wallet_public_id"
        case referenceIdentityParams = "reference_identity_params"
    }
}

struct CreateScopeGrantCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CreateScopeGrantBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CreateScopeGrantBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CreateScopeGrantBody: Codable, Sendable {
    let operatorPublicId: String
    let walletPublicId: String
    let scopeKind: String
    let underlyingPublicId: String?
    let instrumentPublicId: String?
    let note: String?

    init(
        operatorPublicId: String,
        walletPublicId: String,
        scopeKind: String,
        underlyingPublicId: String? = nil,
        instrumentPublicId: String? = nil,
        note: String? = nil
    ) {
        self.operatorPublicId = operatorPublicId
        self.walletPublicId = walletPublicId
        self.scopeKind = scopeKind
        self.underlyingPublicId = underlyingPublicId
        self.instrumentPublicId = instrumentPublicId
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case operatorPublicId = "operator_public_id"
        case walletPublicId = "wallet_public_id"
        case scopeKind = "scope_kind"
        case underlyingPublicId = "underlying_public_id"
        case instrumentPublicId = "instrument_public_id"
        case note
    }
}

struct HandoverScopeGrantCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: HandoverScopeGrantBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: HandoverScopeGrantBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct HandoverScopeGrantBody: Codable, Sendable {
    let fromGrantPublicId: String
    let toOperatorPublicId: String
    let reason: String?

    init(
        fromGrantPublicId: String,
        toOperatorPublicId: String,
        reason: String? = nil
    ) {
        self.fromGrantPublicId = fromGrantPublicId
        self.toOperatorPublicId = toOperatorPublicId
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case fromGrantPublicId = "from_grant_public_id"
        case toOperatorPublicId = "to_operator_public_id"
        case reason
    }
}

struct RevokeScopeGrantCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: RevokeScopeGrantBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: RevokeScopeGrantBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct RevokeScopeGrantBody: Codable, Sendable {
    let reason: String?

    init(
        reason: String? = nil
    ) {
        self.reason = reason
    }
}

struct TrailingStopCreateCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: TrailingStopCreateBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: TrailingStopCreateBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct TrailingStopCreateBody: Codable, Sendable {
    let positionCyclePublicId: String
    let trailingPct: Double
    let minLockPct: Double?
    let idempotencyKey: String?

    init(
        positionCyclePublicId: String,
        trailingPct: Double,
        minLockPct: Double? = nil,
        idempotencyKey: String? = nil
    ) {
        self.positionCyclePublicId = positionCyclePublicId
        self.trailingPct = trailingPct
        self.minLockPct = minLockPct
        self.idempotencyKey = idempotencyKey
    }

    enum CodingKeys: String, CodingKey {
        case positionCyclePublicId = "position_cycle_public_id"
        case trailingPct = "trailing_pct"
        case minLockPct = "min_lock_pct"
        case idempotencyKey = "idempotency_key"
    }
}

struct TrailingStopCancelCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: TrailingStopCancelBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: TrailingStopCancelBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct TrailingStopCancelBody: Codable, Sendable {
    let reason: String?

    init(
        reason: String? = nil
    ) {
        self.reason = reason
    }
}

struct CreateWalletCommand: Codable, Sendable {
    let type: String?
    let sequenceId: Int
    let publicId: String
    let timestamp: Date
    let sessionId: String
    let topic: String?
    let payload: CreateWalletBody

    init(
        type: String? = nil,
        sequenceId: Int,
        publicId: String,
        timestamp: Date,
        sessionId: String,
        topic: String? = nil,
        payload: CreateWalletBody
    ) {
        self.type = type
        self.sequenceId = sequenceId
        self.publicId = publicId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.topic = topic
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceId = "sequence_id"
        case publicId = "public_id"
        case timestamp
        case sessionId = "session_id"
        case topic
        case payload
    }
}

struct CreateWalletBody: Codable, Sendable {
    let label: String
    let description: String?
    let isPaper: Bool?

    init(
        label: String,
        description: String? = nil,
        isPaper: Bool? = nil
    ) {
        self.label = label
        self.description = description
        self.isPaper = isPaper
    }

    enum CodingKeys: String, CodingKey {
        case label
        case description
        case isPaper = "is_paper"
    }
}
