import Foundation

// MARK: - Firestore REST API Client

/// Low-level client for Firestore REST API operations.
/// Uses the existing Google OAuth access token (via AuthenticationManager) for auth.
actor FirestoreClient {
    static let shared = FirestoreClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    // MARK: - CRUD Operations

    /// Get a single document
    func getDocument(path: String) async throws -> FirestoreDocument? {
        let request = try await buildRequest(url: path, method: "GET")
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FirestoreError.invalidResponse
        }

        if http.statusCode == 404 {
            return nil
        }

        guard (200...299).contains(http.statusCode) else {
            throw FirestoreError.httpError(statusCode: http.statusCode, data: data)
        }

        return try JSONDecoder().decode(FirestoreDocument.self, from: data)
    }

    /// List documents in a collection
    func listDocuments(collectionPath: String, pageSize: Int = 300) async throws -> [FirestoreDocument] {
        var allDocs: [FirestoreDocument] = []
        var pageToken: String?

        repeat {
            var urlString = "\(collectionPath)?pageSize=\(pageSize)"
            if let token = pageToken {
                urlString += "&pageToken=\(token)"
            }

            let request = try await buildRequest(url: urlString, method: "GET")
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw FirestoreError.httpError(
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                    data: data
                )
            }

            let listResponse = try JSONDecoder().decode(FirestoreListResponse.self, from: data)
            if let docs = listResponse.documents {
                allDocs.append(contentsOf: docs)
            }
            pageToken = listResponse.nextPageToken
        } while pageToken != nil

        return allDocs
    }

    /// Create or overwrite a document at a specific path
    func setDocument(path: String, fields: [String: FirestoreValue]) async throws {
        let doc = FirestoreDocument(name: nil, fields: fields, createTime: nil, updateTime: nil)
        var request = try await buildRequest(url: path, method: "PATCH")
        request.httpBody = try JSONEncoder().encode(doc)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw FirestoreError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                data: data
            )
        }
    }

    /// Delete a document
    func deleteDocument(path: String) async throws {
        let request = try await buildRequest(url: path, method: "DELETE")
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FirestoreError.invalidResponse
        }

        // 404 is fine — already deleted
        guard (200...299).contains(http.statusCode) || http.statusCode == 404 else {
            throw FirestoreError.httpError(statusCode: http.statusCode, data: data)
        }
    }

    /// Batch write multiple documents (max 500 per batch)
    func batchWrite(writes: [FirestoreBatchWrite]) async throws {
        guard !writes.isEmpty else { return }

        let batchURL = "\(FirestoreConfig.baseURL):commit"
        var request = try await buildRequest(url: batchURL, method: "POST")

        let body = FirestoreBatchRequest(writes: writes)
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw FirestoreError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                data: data
            )
        }
    }

    // MARK: - Request Builder

    private func buildRequest(url urlString: String, method: String) async throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw FirestoreError.invalidURL
        }

        let token = try await AuthenticationManager.shared.getFreshAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

// MARK: - Firestore Document Models

struct FirestoreDocument: Codable {
    let name: String?           // Full resource path
    let fields: [String: FirestoreValue]?
    let createTime: String?
    let updateTime: String?

    /// Extract document ID from the full resource name
    var documentId: String? {
        name?.components(separatedBy: "/").last
    }
}

struct FirestoreListResponse: Codable {
    let documents: [FirestoreDocument]?
    let nextPageToken: String?
}

// MARK: - Firestore Typed Values

/// Represents a Firestore field value with its type.
/// Firestore REST API uses typed values: { "stringValue": "hello" }, { "integerValue": "42" }, etc.
enum FirestoreValue: Codable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case timestamp(String)  // ISO 8601 format
    case array([FirestoreValue])
    case map([String: FirestoreValue])
    case null

    // Convenience accessors
    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .integer(let v) = self { return v }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        return nil
    }

    var boolValue: Bool? {
        if case .boolean(let v) = self { return v }
        return nil
    }

    var arrayValue: [FirestoreValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    var mapValue: [String: FirestoreValue]? {
        if case .map(let v) = self { return v }
        return nil
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case stringValue, integerValue, doubleValue, booleanValue
        case timestampValue, arrayValue, mapValue, nullValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let v = try container.decodeIfPresent(String.self, forKey: .stringValue) {
            self = .string(v)
        } else if let v = try container.decodeIfPresent(String.self, forKey: .integerValue) {
            // Firestore sends integers as strings
            self = .integer(Int(v) ?? 0)
        } else if let v = try container.decodeIfPresent(Double.self, forKey: .doubleValue) {
            self = .double(v)
        } else if let v = try container.decodeIfPresent(Bool.self, forKey: .booleanValue) {
            self = .boolean(v)
        } else if let v = try container.decodeIfPresent(String.self, forKey: .timestampValue) {
            self = .timestamp(v)
        } else if let wrapper = try container.decodeIfPresent(FirestoreArrayWrapper.self, forKey: .arrayValue) {
            self = .array(wrapper.values ?? [])
        } else if let wrapper = try container.decodeIfPresent(FirestoreMapWrapper.self, forKey: .mapValue) {
            self = .map(wrapper.fields ?? [:])
        } else if container.contains(.nullValue) {
            self = .null
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let v):
            try container.encode(v, forKey: .stringValue)
        case .integer(let v):
            try container.encode(String(v), forKey: .integerValue)
        case .double(let v):
            try container.encode(v, forKey: .doubleValue)
        case .boolean(let v):
            try container.encode(v, forKey: .booleanValue)
        case .timestamp(let v):
            try container.encode(v, forKey: .timestampValue)
        case .array(let v):
            try container.encode(FirestoreArrayWrapper(values: v), forKey: .arrayValue)
        case .map(let v):
            try container.encode(FirestoreMapWrapper(fields: v), forKey: .mapValue)
        case .null:
            try container.encode(true, forKey: .nullValue)
        }
    }
}

// Firestore wraps arrays and maps in nested objects
struct FirestoreArrayWrapper: Codable {
    let values: [FirestoreValue]?
}

struct FirestoreMapWrapper: Codable {
    let fields: [String: FirestoreValue]?
}

// MARK: - Batch Write Models

struct FirestoreBatchRequest: Codable {
    let writes: [FirestoreBatchWrite]
}

struct FirestoreBatchWrite: Codable {
    let update: FirestoreDocument?
    let delete: String?  // Document path to delete

    static func upsert(path: String, fields: [String: FirestoreValue]) -> FirestoreBatchWrite {
        FirestoreBatchWrite(
            update: FirestoreDocument(name: path, fields: fields, createTime: nil, updateTime: nil),
            delete: nil
        )
    }

    static func remove(path: String) -> FirestoreBatchWrite {
        FirestoreBatchWrite(update: nil, delete: path)
    }
}

// MARK: - Errors

enum FirestoreError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firestore not configured. Set FirestoreConfig.projectId."
        case .invalidURL:
            return "Invalid Firestore URL"
        case .invalidResponse:
            return "Invalid response from Firestore"
        case .httpError(let code, let data):
            let msg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown"
            return "Firestore HTTP \(code): \(msg)"
        }
    }
}
