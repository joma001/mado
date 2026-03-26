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
            return "인터넷 연결 없음"
        case .authExpired:
            return "세션 만료 — 다시 로그인하세요"
        case .apiError(let service, let message):
            return "\(service): \(message)"
        case .storeError(let message):
            return "저장소 오류: \(message)"
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
        case .idle: return "동기화 안 됨"
        case .syncing: return "동기화 중..."
        case .success(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.unitsStyle = .abbreviated
            return "\(formatter.localizedString(for: date, relativeTo: Date()))에 동기화됨"
        case .error(let kind): return "동기화 오류: \(kind.displayMessage)"
        }
    }
}
