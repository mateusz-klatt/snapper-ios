// This file was auto-generated from backend schemas.
// DO NOT EDIT - regenerate with: make ios-gen-types

import Foundation

enum Permission: String, CaseIterable, Codable, Sendable {
    case readMarketData = "read:market_data"
    case readMarketViews = "read:market_views"
    case submitMarketView = "submit:market_view"
    case submitAiReviewDecision = "submit:ai_review_decision"
    case readOrders = "read:orders"
    case createOrders = "create:orders"
    case cancelOrders = "cancel:orders"
    case readPositions = "read:positions"
    case managePositions = "manage:positions"
    case readAccountState = "read:account_state"
    case readStrategies = "read:strategies"
    case readSignals = "read:signals"
    case startStrategies = "start:strategies"
    case stopStrategies = "stop:strategies"
    case configureStrategies = "configure:strategies"
    case readSystemStatus = "read:system_status"
    case manageRuntimeDiagnostics = "manage:runtime_diagnostics"
    case readProcesses = "read:processes"
    case manageProcesses = "manage:processes"
    case readAiReviews = "read:ai_reviews"
    case readAiIntegration = "read:ai_integration"
    case manageAiIntegration = "manage:ai_integration"
    case configureSystem = "configure:system"
    case manageUsers = "manage:users"
    case manageDeskMemberships = "manage:desk_memberships"
    case readWalletCredentials = "read:wallet_credentials"
    case manageWalletCredentials = "manage:wallet_credentials"
    case manageScopeGrants = "manage:scope_grants"
    case impersonateOperator = "impersonate:operator"
    case readBacktests = "read:backtests"
    case createBacktestComparisons = "create:backtest_comparisons"
    case manageBacktests = "manage:backtests"
    case readNotifications = "read:notifications"
    case manageNotificationDevices = "manage:notification_devices"
    case managePairedExecution = "manage:paired_execution"
}

enum ResourceRequirement: Sendable {
    case authenticated
    case anyPermission([Permission])
}

let rolePermissions: [UserRole: [Permission]] = [
    .aiResearcher: [.readMarketData, .readMarketViews, .submitMarketView],
    .aiReviewer: [.createBacktestComparisons, .manageRuntimeDiagnostics, .readBacktests, .readMarketData, .readMarketViews, .readOrders, .readPositions, .readSignals, .readStrategies, .readSystemStatus, .submitAiReviewDecision],
    .aiDelegate: [.cancelOrders, .createBacktestComparisons, .createOrders, .managePositions, .manageRuntimeDiagnostics, .readBacktests, .readMarketData, .readMarketViews, .readOrders, .readPositions, .readSignals, .readStrategies, .readSystemStatus, .submitAiReviewDecision],
    .viewer: [.manageNotificationDevices, .readAccountState, .readAiIntegration, .readAiReviews, .readBacktests, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositions, .readProcesses, .readSignals, .readStrategies, .readSystemStatus],
    .operatorRole: [.cancelOrders, .configureStrategies, .createBacktestComparisons, .createOrders, .manageAiIntegration, .manageBacktests, .manageDeskMemberships, .manageNotificationDevices, .managePairedExecution, .managePositions, .manageProcesses, .manageRuntimeDiagnostics, .readAccountState, .readAiIntegration, .readAiReviews, .readBacktests, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositions, .readProcesses, .readSignals, .readStrategies, .readSystemStatus, .startStrategies, .stopStrategies],
    .admin: [.cancelOrders, .configureStrategies, .configureSystem, .createBacktestComparisons, .createOrders, .impersonateOperator, .manageAiIntegration, .manageBacktests, .manageDeskMemberships, .manageNotificationDevices, .managePairedExecution, .managePositions, .manageProcesses, .manageRuntimeDiagnostics, .manageScopeGrants, .manageUsers, .manageWalletCredentials, .readAccountState, .readAiIntegration, .readAiReviews, .readBacktests, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositions, .readProcesses, .readSignals, .readStrategies, .readSystemStatus, .readWalletCredentials, .startStrategies, .stopStrategies, .submitAiReviewDecision, .submitMarketView],
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
    "admin": .anyPermission([.manageUsers]),
    "settings": .anyPermission([.configureSystem]),
    "backtests": .anyPermission([.readBacktests]),
    "ai-integration": .anyPermission([.readAiIntegration]),
    "ai-reviews": .anyPermission([.readAiReviews, .submitAiReviewDecision]),
    "notifications": .anyPermission([.readNotifications]),
]
