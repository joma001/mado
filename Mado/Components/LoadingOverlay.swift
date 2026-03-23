import SwiftUI

struct LoadingOverlay: View {
    var message: String? = nil

    var body: some View {
        ZStack {
            MadoColors.surface
                .ignoresSafeArea()

            VStack(spacing: MadoTheme.Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(MadoColors.accent)

                if let message {
                    Text(message)
                        .font(MadoTheme.Font.body)
                        .foregroundColor(MadoColors.textSecondary)
                }
            }
        }
    }
}
