// This file was auto-generated from backend schemas.
// DO NOT EDIT - regenerate with: make ios-gen-types

import Foundation

struct Permission: RawRepresentable, Hashable, Codable, CaseIterable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let readMarketData = Permission(rawValue: "read:market_data")
    static let readMarketViews = Permission(rawValue: "read:market_views")
    static let submitMarketView = Permission(rawValue: "submit:market_view")
    static let submitAiReviewDecision = Permission(rawValue: "submit:ai_review_decision")
    static let readOrders = Permission(rawValue: "read:orders")
    static let createOrders = Permission(rawValue: "create:orders")
    static let cancelOrders = Permission(rawValue: "cancel:orders")
    static let readPositions = Permission(rawValue: "read:positions")
    static let managePositions = Permission(rawValue: "manage:positions")
    static let readAccountState = Permission(rawValue: "read:account_state")
    static let readStrategies = Permission(rawValue: "read:strategies")
    static let readSignals = Permission(rawValue: "read:signals")
    static let startStrategies = Permission(rawValue: "start:strategies")
    static let stopStrategies = Permission(rawValue: "stop:strategies")
    static let configureStrategies = Permission(rawValue: "configure:strategies")
    static let readSystemStatus = Permission(rawValue: "read:system_status")
    static let manageRuntimeDiagnostics = Permission(rawValue: "manage:runtime_diagnostics")
    static let readProcesses = Permission(rawValue: "read:processes")
    static let manageProcesses = Permission(rawValue: "manage:processes")
    static let readAiReviews = Permission(rawValue: "read:ai_reviews")
    static let readAiIntegration = Permission(rawValue: "read:ai_integration")
    static let manageAiIntegration = Permission(rawValue: "manage:ai_integration")
    static let readSystemSettings = Permission(rawValue: "read:system_settings")
    static let configureSystem = Permission(rawValue: "configure:system")
    static let readUsers = Permission(rawValue: "read:users")
    static let manageUsers = Permission(rawValue: "manage:users")
    static let manageSelfAccount = Permission(rawValue: "manage:self_account")
    static let readDeskMemberships = Permission(rawValue: "read:desk_memberships")
    static let manageDeskMemberships = Permission(rawValue: "manage:desk_memberships")
    static let readWalletCredentials = Permission(rawValue: "read:wallet_credentials")
    static let manageWalletCredentials = Permission(rawValue: "manage:wallet_credentials")
    static let readScopeGrants = Permission(rawValue: "read:scope_grants")
    static let manageScopeGrants = Permission(rawValue: "manage:scope_grants")
    static let readAllScopes = Permission(rawValue: "read:all_scopes")
    static let readPositionCycles = Permission(rawValue: "read:position_cycles")
    static let initializePnlAnchors = Permission(rawValue: "initialize:pnl_anchors")
    static let impersonateOperator = Permission(rawValue: "impersonate:operator")
    static let readBacktests = Permission(rawValue: "read:backtests")
    static let createBacktestComparisons = Permission(rawValue: "create:backtest_comparisons")
    static let manageBacktests = Permission(rawValue: "manage:backtests")
    static let readNotifications = Permission(rawValue: "read:notifications")
    static let manageNotificationDevices = Permission(rawValue: "manage:notification_devices")
    static let managePairedExecution = Permission(rawValue: "manage:paired_execution")

    static let allCases: [Permission] = [
        .readMarketData,
        .readMarketViews,
        .submitMarketView,
        .submitAiReviewDecision,
        .readOrders,
        .createOrders,
        .cancelOrders,
        .readPositions,
        .managePositions,
        .readAccountState,
        .readStrategies,
        .readSignals,
        .startStrategies,
        .stopStrategies,
        .configureStrategies,
        .readSystemStatus,
        .manageRuntimeDiagnostics,
        .readProcesses,
        .manageProcesses,
        .readAiReviews,
        .readAiIntegration,
        .manageAiIntegration,
        .readSystemSettings,
        .configureSystem,
        .readUsers,
        .manageUsers,
        .manageSelfAccount,
        .readDeskMemberships,
        .manageDeskMemberships,
        .readWalletCredentials,
        .manageWalletCredentials,
        .readScopeGrants,
        .manageScopeGrants,
        .readAllScopes,
        .readPositionCycles,
        .initializePnlAnchors,
        .impersonateOperator,
        .readBacktests,
        .createBacktestComparisons,
        .manageBacktests,
        .readNotifications,
        .manageNotificationDevices,
        .managePairedExecution,
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum ResourceRequirement: Sendable {
    case authenticated
    case anyPermission([Permission])
}

let rolePermissions: [UserRole: [Permission]] = [
    .aiResearcher: [.manageSelfAccount, .readMarketData, .readMarketViews, .readScopeGrants, .submitMarketView],
    .aiReviewer: [.createBacktestComparisons, .initializePnlAnchors, .manageRuntimeDiagnostics, .manageSelfAccount, .readBacktests, .readMarketData, .readMarketViews, .readOrders, .readPositions, .readScopeGrants, .readSignals, .readStrategies, .readSystemStatus, .submitAiReviewDecision],
    .aiDelegate: [.cancelOrders, .createBacktestComparisons, .createOrders, .initializePnlAnchors, .managePositions, .manageRuntimeDiagnostics, .manageSelfAccount, .readBacktests, .readMarketData, .readMarketViews, .readOrders, .readPositions, .readScopeGrants, .readSignals, .readStrategies, .readSystemStatus, .submitAiReviewDecision],
    .viewer: [.initializePnlAnchors, .manageNotificationDevices, .manageSelfAccount, .readAccountState, .readAiIntegration, .readAiReviews, .readBacktests, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositions, .readProcesses, .readScopeGrants, .readSignals, .readStrategies, .readSystemStatus],
    .auditor: [.readAccountState, .readAiIntegration, .readAiReviews, .readAllScopes, .readBacktests, .readDeskMemberships, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositionCycles, .readPositions, .readProcesses, .readScopeGrants, .readSignals, .readStrategies, .readSystemSettings, .readSystemStatus, .readUsers, .readWalletCredentials],
    .operatorRole: [.cancelOrders, .configureStrategies, .createBacktestComparisons, .createOrders, .initializePnlAnchors, .manageAiIntegration, .manageBacktests, .manageDeskMemberships, .manageNotificationDevices, .managePairedExecution, .managePositions, .manageProcesses, .manageRuntimeDiagnostics, .manageSelfAccount, .readAccountState, .readAiIntegration, .readAiReviews, .readBacktests, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositions, .readProcesses, .readScopeGrants, .readSignals, .readStrategies, .readSystemStatus, .startStrategies, .stopStrategies],
    .admin: [.cancelOrders, .configureStrategies, .configureSystem, .createBacktestComparisons, .createOrders, .impersonateOperator, .initializePnlAnchors, .manageAiIntegration, .manageBacktests, .manageDeskMemberships, .manageNotificationDevices, .managePairedExecution, .managePositions, .manageProcesses, .manageRuntimeDiagnostics, .manageScopeGrants, .manageSelfAccount, .manageUsers, .manageWalletCredentials, .readAccountState, .readAiIntegration, .readAiReviews, .readAllScopes, .readBacktests, .readDeskMemberships, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositionCycles, .readPositions, .readProcesses, .readScopeGrants, .readSignals, .readStrategies, .readSystemSettings, .readSystemStatus, .readUsers, .readWalletCredentials, .startStrategies, .stopStrategies, .submitAiReviewDecision, .submitMarketView],
]

let resourceRequirements: [String: ResourceRequirement] = [
    "overview": .authenticated,
    "market": .anyPermission([.readMarketData]),
    "processes": .anyPermission([.readProcesses]),
    "strategies": .anyPermission([.readStrategies]),
    "orders": .anyPermission([.readOrders]),
    "positions": .anyPermission([.readPositions]),
    "accounts": .anyPermission([.readAccountState]),
    "signals": .anyPermission([.readSignals]),
    "health": .anyPermission([.readSystemStatus]),
    "admin": .anyPermission([.manageDeskMemberships, .manageUsers, .readDeskMemberships, .readUsers, .readWalletCredentials]),
    "settings": .anyPermission([.configureSystem, .readSystemSettings]),
    "backtests": .anyPermission([.readBacktests]),
    "ai-integration": .anyPermission([.readAiIntegration]),
    "ai-reviews": .anyPermission([.readAiReviews, .submitAiReviewDecision]),
    "notifications": .anyPermission([.readNotifications]),
]
