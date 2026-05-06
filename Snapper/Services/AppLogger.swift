import os

enum AppLogger {
    static func make(category: String) -> Logger {
        return Logger(subsystem: "Snapper", category: category)
    }
}
