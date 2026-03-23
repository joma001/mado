import Foundation

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success(Date)
    case error(String)

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
        case .error(let msg): return "Sync error: \(msg)"
        }
    }
}
