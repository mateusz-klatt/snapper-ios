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
    case manageProcesses = "manage:processes"
    case configureSystem = "configure:system"
    case manageUsers = "manage:users"
    case readWalletCredentials = "read:wallet_credentials"
    case manageWalletCredentials = "manage:wallet_credentials"
    case manageScopeGrants = "manage:scope_grants"
    case impersonateOperator = "impersonate:operator"
    case readBacktests = "read:backtests"
    case manageBacktests = "manage:backtests"
    case readNotifications = "read:notifications"
    case manageNotificationDevices = "manage:notification_devices"
    case managePairedExecution = "manage:paired_execution"
}

let rolePermissions: [UserRole: [Permission]] = [
    .aiResearcher: [.readMarketData, .readMarketViews, .submitMarketView],
    .aiReviewer: [.readBacktests, .readMarketData, .readMarketViews, .readOrders, .readPositions, .readSignals, .readStrategies, .readSystemStatus, .submitAiReviewDecision],
    .aiDelegate: [.cancelOrders, .createOrders, .managePositions, .readBacktests, .readMarketData, .readMarketViews, .readOrders, .readPositions, .readSignals, .readStrategies, .readSystemStatus, .submitAiReviewDecision],
    .viewer: [.manageNotificationDevices, .readAccountState, .readBacktests, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositions, .readSignals, .readStrategies, .readSystemStatus],
    .operatorRole: [.cancelOrders, .createOrders, .manageBacktests, .manageNotificationDevices, .managePairedExecution, .managePositions, .manageProcesses, .readAccountState, .readBacktests, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositions, .readSignals, .readStrategies, .readSystemStatus, .startStrategies, .stopStrategies],
    .admin: [.cancelOrders, .configureStrategies, .configureSystem, .createOrders, .impersonateOperator, .manageBacktests, .manageNotificationDevices, .managePairedExecution, .managePositions, .manageProcesses, .manageScopeGrants, .manageUsers, .manageWalletCredentials, .readAccountState, .readBacktests, .readMarketData, .readMarketViews, .readNotifications, .readOrders, .readPositions, .readSignals, .readStrategies, .readSystemStatus, .readWalletCredentials, .startStrategies, .stopStrategies, .submitAiReviewDecision, .submitMarketView],
]

let resourceAccess: [String: [UserRole]] = [
    "overview": [.aiResearcher, .aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin],
    "market": [.aiResearcher, .aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin],
    "processes": [.operatorRole, .admin],
    "strategies": [.aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin],
    "orders": [.aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin],
    "positions": [.aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin],
    "accounts": [.viewer, .operatorRole, .admin],
    "signals": [.aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin],
    "health": [.aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin],
    "admin": [.admin],
    "settings": [.admin],
    "backtests": [.aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin],
    "ai-integration": [.operatorRole, .admin],
    "ai-reviews": [.aiReviewer, .aiDelegate, .viewer, .operatorRole, .admin],
    "notifications": [.viewer, .operatorRole, .admin],
]
