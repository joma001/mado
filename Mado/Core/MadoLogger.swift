import os

/// Centralized logging for the Mado app, replacing mixed print()/NSLog() usage.
enum MadoLogger {
    static let sync = Logger(subsystem: "com.mado", category: "sync")
    static let auth = Logger(subsystem: "com.mado", category: "auth")
    static let notifications = Logger(subsystem: "com.mado", category: "notifications")
    static let general = Logger(subsystem: "com.mado", category: "general")
}
