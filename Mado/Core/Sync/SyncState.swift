import Foundation

enum SyncErrorKind: Equatable {
    /// No internet connection or DNS failure
    case networkUnavailable
    /// 401 or token refresh failed
    case authExpired
    /// A specific Google API returned an error
    case apiError(service: String, message: String)
    /// SwiftData / persistence failure
    case storeError(String)

    var displayMessage: String {
        switch self {
        case .networkUnavailable:
            return "No internet connection"
        case .authExpired:
            return "Session expired — please sign in again"
        case .apiError(let service, let message):
            return "\(service): \(message)"
        case .storeError(let message):
            return "Storage error: \(message)"
        }
    }
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success(Date)
    case error(SyncErrorKind)

    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }

    var lastSyncDate: Date? {
        if case .success(let date) = self { return date }
        return nil
    }

    var displayText: String {
        switch self {
        case .idle: return "Not synced"
        case .syncing: return "Syncing..."
        case .success(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        case .error(let kind): return "Sync error: \(kind.displayMessage)"
        }
    }
}
