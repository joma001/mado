import SwiftUI

struct iOSLoginView: View {
    var errorMessage: String? = nil
    private let authManager = AuthenticationManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(MadoColors.accent)

                Text("mado")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(MadoColors.textPrimary)

                Text("Your unified planner")
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textSecondary)
            }

            Spacer()

            // Error
            if let error = errorMessage {
                Text(error)
                    .font(MadoTheme.Font.caption)
                    .foregroundColor(MadoColors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Sign in button
            Button {
                Task { await authManager.signIn() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Sign in with Google")
                        .font(MadoTheme.Font.bodyMedium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(MadoColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(MadoColors.surface)
    }
}
