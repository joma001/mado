import SwiftUI

struct LoginView: View {
    var errorMessage: String? = nil

    @State private var viewModel = LoginViewModel()
    @State private var isHoveredButton = false

    var body: some View {
        VStack(spacing: MadoTheme.Spacing.xxxl) {
            Spacer()

            // Logo area
            VStack(spacing: MadoTheme.Spacing.lg) {
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: MadoTheme.Spacing.sm) {
                    Text("mado")
                        .font(MadoTheme.Font.largeTitle)
                        .foregroundColor(MadoColors.textPrimary)

                    Text("Organize your tasks and calendar\nin one place")
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            // Sign in button
            VStack(spacing: MadoTheme.Spacing.md) {
                Button {
                    Task { await viewModel.signIn() }
                } label: {
                    HStack(spacing: MadoTheme.Spacing.sm) {
                        Image(systemName: "globe")
                            .font(.system(size: 16))
                        Text("Sign in with Google")
                            .font(MadoTheme.Font.bodyMedium)
                    }
                    .frame(width: 240)
                }
                .buttonStyle(MadoButtonStyle(variant: .primary))
                .disabled(viewModel.isSigningIn)
                .onHover { isHoveredButton = $0 }

                if viewModel.isSigningIn {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(MadoColors.accent)
                }

                // Error message
                if let error = errorMessage ?? viewModel.errorMessage {
                    HStack(spacing: MadoTheme.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text(error)
                            .font(MadoTheme.Font.caption)
                    }
                    .foregroundColor(MadoColors.error)
                    .padding(.horizontal, MadoTheme.Spacing.lg)
                    .padding(.vertical, MadoTheme.Spacing.sm)
                    .background(MadoColors.error.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.md))
                }
            }

            Spacer()

            // Footer
            Text("Your data stays synced with Google Tasks & Calendar")
                .font(MadoTheme.Font.caption)
                .foregroundColor(MadoColors.textTertiary)
                .padding(.bottom, MadoTheme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MadoColors.surface)
    }
}
