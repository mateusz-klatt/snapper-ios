import Foundation

/// Single source of truth for the WebSocket topic-root prefixes the iOS
/// client subscribes to by default.
///
/// Format mirrors the backend ``TOPIC_REGISTRY`` roots in
/// `src/snapper/messaging/topics/schemas.py`. Each value is a trailing-dot
/// prefix; the backend fans concrete topics out beneath the root and gates
/// delivery by the authenticated session's ``availableTopics`` capability
/// envelope. Named here — rather than inlined into
/// ``WebSocketManager``'s preferred-defaults list — so the prefixes live in
/// one place and read intent-first, mirroring the ``MarketTopic`` precedent
/// for market channels.
///
/// The strategies channel is deliberately ``strategies.events.list.`` — the
/// registry root — and NOT the web client's stale ``strategy.`` prefix,
/// which is not a registry root and yields a dead subscription.
enum WSTopicRoot {
    static let heartbeats = "system.heartbeats."
    static let orderEvents = "orders.events."
    static let signals = "signals."
    static let aiReviews = "ai_reviews."
    static let processSummary = "processes.events.summary."
    static let processConfigured = "processes.events.configured."
    static let processRuns = "processes.events.runs."
    static let strategyList = "strategies.events.list."
}
