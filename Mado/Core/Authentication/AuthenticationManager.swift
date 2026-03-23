import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif
import GoogleSignIn

@MainActor
@Observable
final class AuthenticationManager {
    static let shared = AuthenticationManager()

    private(set) var status: AuthStatus = .unknown
    private(set) var accessToken: String?
    private(set) var accounts: [Account] = []

    private var usingStoredToken = false
    private var tokenCache: [String: String] = [:]

    private let scopes = [
        "https://www.googleapis.com/auth/tasks",
        "https://www.googleapis.com/auth/calendar",
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/datastore"
    ]
    private let tokenStore = TokenStore.shared

    private init() {}

    var primaryAccount: Account? {
        accounts.first { $0.isPrimary } ?? accounts.first
    }

    // MARK: - Restore Previous Sign-In

    func restorePreviousSignIn() async {
        let store = tokenStore.loadStore()
        let primaryEmail = store.primaryEmail

        if store.accounts.isEmpty {
            status = .signedOut
            return
        }

        var restoredAccounts: [Account] = []

        for creds in store.accounts {
            do {
                let result = try await tokenStore.refreshAccessToken(using: creds.refreshToken)
                tokenCache[creds.email] = result.accessToken
                restoredAccounts.append(Account(
                    email: creds.email,
                    name: creds.name,
                    photoURLString: creds.photoURLString,
                    isPrimary: creds.email == primaryEmail
                ))
            } catch {
                print("[Auth] Failed to restore \(creds.email): \(error.localizedDescription)")
            }
        }

        if restoredAccounts.isEmpty {
            // Also try GIDSignIn SDK restore
            do {
                let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                try await ensureScopes(for: user)
                persistCredentials(from: user)
                let email = user.profile?.email ?? "Unknown"
                tokenCache[email] = user.accessToken.tokenString
                restoredAccounts.append(Account(
                    email: email,
                    name: user.profile?.name ?? "Unknown",
                    photoURLString: user.profile?.imageURL(withDimension: 96)?.absoluteString,
                    isPrimary: true
                ))
            } catch {
                print("[Auth] GIDSignIn restore also failed: \(error.localizedDescription)")
                tokenStore.clear()
                status = .signedOut
                return
            }
        }

        if restoredAccounts.first(where: { $0.isPrimary }) == nil, !restoredAccounts.isEmpty {
            restoredAccounts[0].isPrimary = true
        }

        accounts = restoredAccounts
        usingStoredToken = true

        if let primary = primaryAccount {
            accessToken = tokenCache[primary.email]
            status = .signedIn(email: primary.email, name: primary.name, photoURL: primary.photoURL)
        }

        print("[Auth] Restored \(accounts.count) account(s)")
    }

    // MARK: - Add Account

    func addAccount() async {
        #if os(macOS)
        guard let window = NSApplication.shared.windows.first else {
            status = .error("No window available for sign-in")
            return
        }
        let presenting = window
        #elseif os(iOS)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            status = .error("No window available for sign-in")
            return
        }
        let presenting = root
        #endif

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenting,
                hint: nil,
                additionalScopes: scopes
            )
            let user = result.user
            let email = user.profile?.email ?? "Unknown"
            let name = user.profile?.name ?? "Unknown"
            let photoURL = user.profile?.imageURL(withDimension: 96)

            let isFirst = accounts.isEmpty
            persistCredentials(from: user)
            tokenCache[email] = user.accessToken.tokenString

            if let idx = accounts.firstIndex(where: { $0.email == email }) {
                accounts[idx] = Account(
                    email: email, name: name,
                    photoURLString: photoURL?.absoluteString,
                    isPrimary: accounts[idx].isPrimary
                )
            } else {
                accounts.append(Account(
                    email: email, name: name,
                    photoURLString: photoURL?.absoluteString,
                    isPrimary: isFirst
                ))
            }

            if isFirst || primaryAccount?.email == email {
                accessToken = user.accessToken.tokenString
                status = .signedIn(email: email, name: name, photoURL: photoURL)
            }

            usingStoredToken = false
        } catch {
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                if accounts.isEmpty { status = .signedOut }
            } else {
                status = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Sign In (first account — wraps addAccount)

    func signIn() async {
        status = .signingIn
        await addAccount()
    }

    // MARK: - Remove Account

    func removeAccount(_ email: String) {
        tokenCache.removeValue(forKey: email)
        tokenStore.removeAccount(email: email)
        accounts.removeAll { $0.email == email }

        if accounts.isEmpty {
            GIDSignIn.sharedInstance.signOut()
            accessToken = nil
            status = .signedOut
        } else {
            if !accounts.contains(where: { $0.isPrimary }) {
                accounts[0].isPrimary = true
                tokenStore.setPrimaryAccount(email: accounts[0].email)
            }
            if let primary = primaryAccount {
                accessToken = tokenCache[primary.email]
                status = .signedIn(email: primary.email, name: primary.name, photoURL: primary.photoURL)
            }
        }
    }

    // MARK: - Sign Out All

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        tokenStore.clear()
        tokenCache.removeAll()
        accounts.removeAll()
        accessToken = nil
        usingStoredToken = false
        status = .signedOut
    }

    // MARK: - Set Primary

    func setPrimaryAccount(_ email: String) {
        for i in accounts.indices {
            accounts[i].isPrimary = (accounts[i].email == email)
        }
        tokenStore.setPrimaryAccount(email: email)
        if let primary = primaryAccount {
            accessToken = tokenCache[primary.email]
            status = .signedIn(email: primary.email, name: primary.name, photoURL: primary.photoURL)
        }
    }

    // MARK: - Get Fresh Access Token

    func getFreshAccessToken() async throws -> String {
        guard let primary = primaryAccount else {
            throw AuthError.notSignedIn
        }
        return try await getFreshAccessToken(for: primary.email)
    }

    func getFreshAccessToken(for email: String) async throws -> String {
        // Path A: GIDSignIn SDK manages this account
        if !usingStoredToken, let currentUser = GIDSignIn.sharedInstance.currentUser,
           currentUser.profile?.email == email {
            let user = try await currentUser.refreshTokensIfNeeded()
            let token = user.accessToken.tokenString
            tokenCache[email] = token
            if email == primaryAccount?.email { accessToken = token }
            return token
        }

        // Path B: Stored refresh token
        guard let creds = tokenStore.credentials(for: email) else {
            throw AuthError.notSignedIn
        }

        let result = try await tokenStore.refreshAccessToken(using: creds.refreshToken)
        tokenCache[email] = result.accessToken
        if email == primaryAccount?.email { accessToken = result.accessToken }
        return result.accessToken
    }

    // MARK: - Handle URL

    func handle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Private

    private func ensureScopes(for user: GIDGoogleUser) async throws {
        let grantedScopes = user.grantedScopes ?? []
        let missingScopes = scopes.filter { !grantedScopes.contains($0) }

        if !missingScopes.isEmpty {
            #if os(macOS)
            guard let window = NSApplication.shared.windows.first else { return }
            let _ = try await user.addScopes(missingScopes, presenting: window)
            #elseif os(iOS)
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return }
            let _ = try await user.addScopes(missingScopes, presenting: root)
            #endif
        }
    }

    private func persistCredentials(from user: GIDGoogleUser) {
        let email = user.profile?.email ?? "Unknown"
        let name = user.profile?.name ?? "Unknown"
        let photoURL = user.profile?.imageURL(withDimension: 96)
        let refreshToken = user.refreshToken.tokenString
        tokenStore.saveAccount(refreshToken: refreshToken, email: email, name: name, photoURL: photoURL)
    }
}

enum AuthError: LocalizedError {
    case notSignedIn
    case tokenRefreshFailed
    case scopesDenied

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in to Google"
        case .tokenRefreshFailed: return "Failed to refresh access token"
        case .scopesDenied: return "Required permissions were denied"
        }
    }
}
