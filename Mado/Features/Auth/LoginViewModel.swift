import Foundation
import SwiftUI

@MainActor
@Observable
final class LoginViewModel {
    var isSigningIn = false
    var errorMessage: String?

    func signIn() async {
        isSigningIn = true
        errorMessage = nil
        await AuthenticationManager.shared.signIn()

        if case .error(let message) = AuthenticationManager.shared.status {
            errorMessage = message
        }
        isSigningIn = false
    }
}
