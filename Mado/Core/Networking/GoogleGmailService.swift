import Foundation

struct GoogleGmailService {
    private let baseURL = "https://gmail.googleapis.com/gmail/v1"
    private let client = APIClient.shared

    // MARK: - List Starred Messages


    func listStarredMessages() async throws -> [GmailMessageRef] {
        var allRefs: [GmailMessageRef] = []
        var pageToken: String?
        repeat {
            var query: [URLQueryItem] = [
                URLQueryItem(name: "q", value: "is:starred"),
                URLQueryItem(name: "maxResults", value: "100"),
                URLQueryItem(name: "fields", value: "messages(id,threadId),nextPageToken"),
            ]
            if let pageToken {
                query.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            let response: GmailListResponse = try await client.get(
                url: "\(baseURL)/users/me/messages",
                queryItems: query
            )
            allRefs.append(contentsOf: response.messages ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return allRefs
    }

    // MARK: - Get Message Metadata


    func getMessageMetadata(messageId: String) async throws -> GmailMessageDTO {
        let query: [URLQueryItem] = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
            URLQueryItem(name: "fields", value: "id,threadId,snippet,labelIds,payload(headers)"),
        ]
        return try await client.get(
            url: "\(baseURL)/users/me/messages/\(messageId)",
            queryItems: query
        )
    }

    // MARK: - Modify Labels (Star / Unstar)


    func starMessage(messageId: String) async throws {
        let body = GmailModifyRequest(addLabelIds: ["STARRED"], removeLabelIds: [])
        let _: GmailModifyResponse = try await client.post(
            url: "\(baseURL)/users/me/messages/\(messageId)/modify",
            body: body
        )
    }


    func unstarMessage(messageId: String) async throws {
        let body = GmailModifyRequest(addLabelIds: [], removeLabelIds: ["STARRED"])
        let _: GmailModifyResponse = try await client.post(
            url: "\(baseURL)/users/me/messages/\(messageId)/modify",
            body: body
        )
    }
}

// MARK: - DTOs

struct GmailListResponse: Codable {
    let messages: [GmailMessageRef]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageRef: Codable {
    let id: String
    let threadId: String?
}

struct GmailMessageDTO: Codable {
    let id: String
    let threadId: String?
    let snippet: String?
    let labelIds: [String]?
    let payload: GmailPayload?


    var subject: String? {
        payload?.headers?.first(where: { $0.name.lowercased() == "subject" })?.value
    }


    var from: String? {
        payload?.headers?.first(where: { $0.name.lowercased() == "from" })?.value
    }

    /// Extracts a clean sender name from the From header.
    /// "John Doe <john@example.com>" → "John Doe"
    var senderName: String? {
        guard let from else { return nil }
        if let angleBracket = from.firstIndex(of: "<") {
            let name = from[from.startIndex..<angleBracket].trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name.replacingOccurrences(of: "\"", with: "")
        }
        return from
    }
}

struct GmailPayload: Codable {
    let headers: [GmailHeader]?
}

struct GmailHeader: Codable {
    let name: String
    let value: String
}

struct GmailModifyRequest: Codable {
    let addLabelIds: [String]
    let removeLabelIds: [String]
}

struct GmailModifyResponse: Codable {
    let id: String
    let threadId: String?
    let labelIds: [String]?
}
