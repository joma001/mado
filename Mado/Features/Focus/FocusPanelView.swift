import SwiftUI

struct FocusPanelView: View {
    let focusVM: FocusTimerViewModel

    var body: some View {
        VStack(spacing: MadoTheme.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MadoColors.accent)
                Text("Focus")
                    .font(MadoTheme.Font.headline)
                    .foregroundColor(MadoColors.textPrimary)
                Spacer()

                // Today's stats
                if focusVM.todaySessionCount > 0 {
                    HStack(spacing: MadoTheme.Spacing.xxs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(MadoColors.accent)
                        Text("\(focusVM.todaySessionCount)")
                            .font(MadoTheme.Font.captionMedium)
                            .foregroundColor(MadoColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, MadoTheme.Spacing.lg)
            .padding(.top, MadoTheme.Spacing.md)

            Divider().foregroundColor(MadoColors.divider)

            // Timer
            FocusTimerView(viewModel: focusVM)
                .padding(.vertical, MadoTheme.Spacing.md)

            // Today summary
            if focusVM.todaySessionCount > 0 {
                Divider().foregroundColor(MadoColors.divider)

                HStack(spacing: MadoTheme.Spacing.lg) {
                    VStack(spacing: MadoTheme.Spacing.xxxs) {
                        Text("\(focusVM.todaySessionCount)")
                            .font(MadoTheme.Font.title2)
                            .foregroundColor(MadoColors.textPrimary)
                        Text("Sessions")
                            .font(MadoTheme.Font.tiny)
                            .foregroundColor(MadoColors.textTertiary)
                    }

                    VStack(spacing: MadoTheme.Spacing.xxxs) {
                        Text("\(focusVM.todayFocusMinutes)m")
                            .font(MadoTheme.Font.title2)
                            .foregroundColor(MadoColors.textPrimary)
                        Text("Focus time")
                            .font(MadoTheme.Font.tiny)
                            .foregroundColor(MadoColors.textTertiary)
                    }
                }
                .padding(.bottom, MadoTheme.Spacing.md)
            }

            // Weekly heatmap
            if focusVM.todaySessionCount > 0 {
                Divider().foregroundColor(MadoColors.divider)

                FocusHeatmapView()
                    .padding(.horizontal, MadoTheme.Spacing.lg)
                    .padding(.bottom, MadoTheme.Spacing.md)
            }

            Spacer()
        }
        .background(MadoColors.surface)
        .overlay {
            if focusVM.showSessionNote, let session = focusVM.completedSessionForNote {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { focusVM.dismissSessionNote() }

                SessionNoteView(
                    session: session,
                    onDismiss: { focusVM.dismissSessionNote() },
                    onSave: { focusVM.saveSessionNote($0) }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(MadoTheme.Animation.standard, value: focusVM.showSessionNote)
    }
}
