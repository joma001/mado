import Foundation

/// Configuration for Firestore REST API access.
/// Set `projectId` to your Firebase project ID after creating the project.
enum FirestoreConfig {
    /// Firebase project ID — set this after creating the Firebase project.
    /// Find it at: https://console.firebase.google.com/ → Project Settings → General → Project ID
    static let projectId = "mado-ba266"

    /// Firestore REST API base URL
    static var baseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents"
    }

    /// Whether Firestore sync is configured and ready to use
    static var isConfigured: Bool {
        !projectId.isEmpty
    }

    /// User-scoped collection path
    static func userPath(userId: String) -> String {
        "\(baseURL)/users/\(userId)"
    }

    /// Sanitize email into a safe Firestore document ID
    static func sanitizeUserId(_ email: String) -> String {
        email.replacingOccurrences(of: "@", with: "_at_")
            .replacingOccurrences(of: ".", with: "_")
    }
}
