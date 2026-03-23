import Foundation

enum APIError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    case rateLimited
    case conflict(etag: String?)
    case notFound
    case gone

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated. Please sign in."
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg ?? "Unknown error")"
        case .decodingError(let error): return "Data error: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .rateLimited: return "Too many requests. Please wait."
        case .conflict: return "Data conflict. The item was modified elsewhere."
        case .notFound: return "Resource not found"
        case .gone: return "Resource no longer exists"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .rateLimited, .networkError: return true
        default: return false
        }
    }

    var isConflict: Bool {
        if case .conflict = self { return true }
        return false
    }
}
