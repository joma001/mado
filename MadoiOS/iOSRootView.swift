import SwiftUI

struct iOSRootView: View {
    private let authManager = AuthenticationManager.shared

    var body: some View {
        Group {
            switch authManager.status {
            case .signedIn:
                iOSMainTabView()
            case .signingIn:
                LoadingOverlay(message: "Signing in...")
            case .error(let message):
                iOSLoginView(errorMessage: message)
            default:
                iOSLoginView()
            }
        }
    }
}
