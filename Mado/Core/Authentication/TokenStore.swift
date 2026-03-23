import Foundation
import os

final class TokenStore {
    static let shared = TokenStore()

    private let fileURL: URL
    let clientID = "102145055155-a3jdtpgj1ig53a3vqoe0qf5v170qruq7.apps.googleusercontent.com"
    private let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    struct StoredCredentials: Codable {
        let refreshToken: String
        let email: String
        let name: String
        let photoURLString: String?
    }

    struct MultiAccountStore: Codable {
        var accounts: [StoredCredentials]
        var primaryEmail: String?
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = appSupport.appendingPathComponent("Mado", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("credentials.json")
    }

    // MARK: - Multi-Account Save / Load / Clear

    func saveAccount(refreshToken: String, email: String, name: String, photoURL: URL?) {
        var store = loadStore()
        let creds = StoredCredentials(
            refreshToken: refreshToken,
            email: email,
            name: name,
            photoURLString: photoURL?.absoluteString
        )

        if let idx = store.accounts.firstIndex(where: { $0.email == email }) {
            store.accounts[idx] = creds
        } else {
            store.accounts.append(creds)
        }

        if store.primaryEmail == nil {
            store.primaryEmail = email
        }

        writeStore(store)
    }

    func removeAccount(email: String) {
        var store = loadStore()
        store.accounts.removeAll { $0.email == email }
        if store.primaryEmail == email {
            store.primaryEmail = store.accounts.first?.email
        }
        writeStore(store)
    }

    func setPrimaryAccount(email: String) {
        var store = loadStore()
        store.primaryEmail = email
        writeStore(store)
    }

    func loadStore() -> MultiAccountStore {
        guard let data = try? Data(contentsOf: fileURL) else {
            // Try legacy single-account format migration
            return migrateLegacyIfNeeded()
        }

        if let store = try? JSONDecoder().decode(MultiAccountStore.self, from: data) {
            return store
        }

        return migrateLegacyIfNeeded()
    }

    func loadAllAccounts() -> [StoredCredentials] {
        loadStore().accounts
    }

    func loadPrimaryEmail() -> String? {
        loadStore().primaryEmail
    }

    func credentials(for email: String) -> StoredCredentials? {
        loadStore().accounts.first { $0.email == email }
    }

    // Legacy compatibility
    func load() -> StoredCredentials? {
        let store = loadStore()
        if let primary = store.primaryEmail {
            return store.accounts.first { $0.email == primary }
        }
        return store.accounts.first
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Legacy Migration

    private func migrateLegacyIfNeeded() -> MultiAccountStore {
        guard let data = try? Data(contentsOf: fileURL),
              let legacy = try? JSONDecoder().decode(StoredCredentials.self, from: data) else {
            return MultiAccountStore(accounts: [], primaryEmail: nil)
        }

        let store = MultiAccountStore(accounts: [legacy], primaryEmail: legacy.email)
        writeStore(store)
        return store
    }

    private func writeStore(_ store: MultiAccountStore) {
        do {
            let data = try JSONEncoder().encode(store)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            MadoLogger.auth.error("Failed to save credentials: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Save / Load legacy helpers (kept for backward compat)

    func save(refreshToken: String, email: String, name: String, photoURL: URL?) {
        saveAccount(refreshToken: refreshToken, email: email, name: name, photoURL: photoURL)
    }

    // MARK: - Refresh Access Token via REST

    func refreshAccessToken(using refreshToken: String) async throws -> (accessToken: String, expiresIn: Int) {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id=\(clientID)",
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TokenStoreError.invalidResponse
        }

        guard http.statusCode == 200 else {
            if http.statusCode == 400 || http.statusCode == 401 {
                // Don't clear all — just this token is bad
            }
            throw TokenStoreError.refreshFailed(statusCode: http.statusCode)
        }

        let result = try JSONDecoder().decode(TokenResponse.self, from: data)
        return (result.access_token, result.expires_in)
    }

    private struct TokenResponse: Codable {
        let access_token: String
        let expires_in: Int
        let token_type: String
    }
}

enum TokenStoreError: LocalizedError {
    case invalidResponse
    case refreshFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from token endpoint"
        case .refreshFailed(let code):
            return "Token refresh failed with status \(code)"
        }
    }
}
