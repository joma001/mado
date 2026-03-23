import Foundation
import SwiftUI

// MARK: - Account (represents a signed-in Google account)

struct Account: Identifiable, Equatable, Codable {
    let email: String
    let name: String
    let photoURLString: String?
    var isPrimary: Bool

    var id: String { email }

    var photoURL: URL? {
        photoURLString.flatMap { URL(string: $0) }
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Auth Status

enum AuthStatus: Equatable {
    case unknown
    case signedOut
    case signingIn
    case signedIn(email: String, name: String, photoURL: URL?)
    case error(String)

    var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }

    var userEmail: String? {
        if case .signedIn(let email, _, _) = self { return email }
        return nil
    }

    var userName: String? {
        if case .signedIn(_, let name, _) = self { return name }
        return nil
    }

    var userPhotoURL: URL? {
        if case .signedIn(_, _, let url) = self { return url }
        return nil
    }
}
