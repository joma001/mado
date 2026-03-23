import Foundation

actor APIClient {
    static let shared = APIClient()

    private enum Constants {
        static let requestTimeout: TimeInterval = 30
        static let resourceTimeout: TimeInterval = 60
        static let maxRetries = 3
    }

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.requestTimeout
        config.timeoutIntervalForResource = Constants.resourceTimeout
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // 1. ISO8601 with fractional seconds and timezone offset
            //    e.g. "2026-02-24T09:00:00.000+09:00", "2026-02-24T00:00:00Z"
            let iso8601Full = ISO8601DateFormatter()
            iso8601Full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Full.date(from: dateString) {
                return date
            }

            // 2. ISO8601 without fractional seconds (with timezone offset)
            //    e.g. "2026-02-24T09:00:00+09:00", "2026-02-24T00:00:00Z"
            let iso8601Basic = ISO8601DateFormatter()
            iso8601Basic.formatOptions = [.withInternetDateTime]
            if let date = iso8601Basic.date(from: dateString) {
                return date
            }

            // 3. Fractional seconds with Z suffix (Google Tasks updated field)
            //    e.g. "2026-02-24T00:00:00.000Z"
            let fractionalZ = DateFormatter()
            fractionalZ.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            fractionalZ.timeZone = TimeZone(identifier: "UTC")
            fractionalZ.locale = Locale(identifier: "en_US_POSIX")
            if let date = fractionalZ.date(from: dateString) {
                return date
            }

            // 4. Date-only format (used by Google Tasks for due dates, Google Calendar all-day events)
            //    e.g. "2026-02-24"
            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"
            dateOnly.timeZone = TimeZone(identifier: "UTC")
            dateOnly.locale = Locale(identifier: "en_US_POSIX")
            if let date = dateOnly.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - GET

    func get<T: Decodable>(
        url: String,
        queryItems: [URLQueryItem]? = nil,
        accountEmail: String? = nil
    ) async throws -> T {
        let request = try await buildRequest(url: url, method: "GET", queryItems: queryItems, accountEmail: accountEmail)
        return try await performWithRetry(request: request, accountEmail: accountEmail)
    }

    // MARK: - POST

    func post<T: Decodable, B: Encodable>(
        url: String,
        body: B,
        accountEmail: String? = nil
    ) async throws -> T {
        var request = try await buildRequest(url: url, method: "POST", accountEmail: accountEmail)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await performWithRetry(request: request, accountEmail: accountEmail)
    }

    // MARK: - PUT

    func put<T: Decodable, B: Encodable>(
        url: String,
        body: B,
        etag: String? = nil,
        accountEmail: String? = nil
    ) async throws -> T {
        var request = try await buildRequest(url: url, method: "PUT", accountEmail: accountEmail)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-Match")
        }
        return try await performWithRetry(request: request, accountEmail: accountEmail)
    }

    // MARK: - PATCH

    func patch<T: Decodable, B: Encodable>(
        url: String,
        body: B,
        etag: String? = nil,
        accountEmail: String? = nil
    ) async throws -> T {
        var request = try await buildRequest(url: url, method: "PATCH", accountEmail: accountEmail)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-Match")
        }
        return try await performWithRetry(request: request, accountEmail: accountEmail)
    }

    // MARK: - DELETE

    func delete(url: String, accountEmail: String? = nil) async throws {
        let request = try await buildRequest(url: url, method: "DELETE", accountEmail: accountEmail)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299, 204:
            return // Success
        case 404, 410:
            // Already deleted or gone — treat as success for idempotency
            return
        case 401:
            // Try refreshing token once
            let freshRequest = try await refreshAndRebuildRequest(from: request, accountEmail: accountEmail)
            let (_, retryResponse) = try await session.data(for: freshRequest)
            if let retryHttp = retryResponse as? HTTPURLResponse,
               (200...299).contains(retryHttp.statusCode) || retryHttp.statusCode == 404 || retryHttp.statusCode == 410 {
                return
            }
            throw APIError.notAuthenticated
        default:
            throw mapHTTPError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    // MARK: - Private

    private func buildRequest(
        url urlString: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        accountEmail: String? = nil
    ) async throws -> URLRequest {
        guard var components = URLComponents(string: urlString) else {
            throw APIError.invalidURL
        }
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let token: String
        if let accountEmail {
            token = try await AuthenticationManager.shared.getFreshAccessToken(for: accountEmail)
        } else {
            token = try await AuthenticationManager.shared.getFreshAccessToken()
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// Refresh token and rebuild the request with the new Authorization header
    private func refreshAndRebuildRequest(from original: URLRequest, accountEmail: String? = nil) async throws -> URLRequest {
        let freshToken: String
        if let accountEmail {
            freshToken = try await AuthenticationManager.shared.getFreshAccessToken(for: accountEmail)
        } else {
            freshToken = try await AuthenticationManager.shared.getFreshAccessToken()
        }
        var request = original
        request.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func performWithRetry<T: Decodable>(
        request: URLRequest,
        maxRetries: Int = Constants.maxRetries,
        accountEmail: String? = nil
    ) async throws -> T {
        var currentRequest = request
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(for: currentRequest)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return try decoder.decode(T.self, from: data)
                case 401:
                    // Token expired — refresh once and retry
                    if attempt == 0 {
                        currentRequest = try await refreshAndRebuildRequest(from: currentRequest, accountEmail: accountEmail)
                        continue
                    }
                    throw APIError.notAuthenticated
                case 404:
                    throw APIError.notFound
                case 409, 412:
                    let etag = httpResponse.value(forHTTPHeaderField: "ETag")
                    throw APIError.conflict(etag: etag)
                case 410:
                    throw APIError.gone
                case 429:
                    if attempt < maxRetries - 1 {
                        let delay = pow(2.0, Double(attempt)) + Double.random(in: 0...1)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw APIError.rateLimited
                case 500...599:
                    if attempt < maxRetries - 1 {
                        let delay = pow(2.0, Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw mapHTTPError(statusCode: httpResponse.statusCode, data: data)
                default:
                    throw mapHTTPError(statusCode: httpResponse.statusCode, data: data)
                }
            } catch let error as APIError {
                if !error.isRetryable { throw error }
                lastError = error
            } catch {
                if attempt < maxRetries - 1 {
                    lastError = error
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    throw APIError.networkError(error)
                }
            }
        }
        throw lastError ?? APIError.invalidResponse
    }

    private func mapHTTPError(statusCode: Int, data: Data?) -> APIError {
        var message: String?
        if let data {
            message = String(data: data, encoding: .utf8)
        }
        return .httpError(statusCode: statusCode, message: message)
    }
}
