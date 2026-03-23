import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var buttonTitle: String?
    var onAction: (() -> Void)?

    var body: some View {
        VStack(spacing: MadoTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(MadoColors.textTertiary)
                .padding(.bottom, MadoTheme.Spacing.xs)

            VStack(spacing: MadoTheme.Spacing.xs) {
                Text(title)
                    .font(MadoTheme.Font.headline)
                    .foregroundColor(MadoColors.textPrimary)

                Text(subtitle)
                    .font(MadoTheme.Font.body)
                    .foregroundColor(MadoColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if let buttonTitle, let onAction {
                Button(action: onAction) {
                    Text(buttonTitle)
                }
                .buttonStyle(MadoButtonStyle(variant: .primary))
                .padding(.top, MadoTheme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MadoColors.surface)
    }
}
