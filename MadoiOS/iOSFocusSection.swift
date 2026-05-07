import SwiftUI

struct iOSFocusSection: View {
    private let focusVM = FocusTimerViewModel.shared

    var body: some View {
        VStack(spacing: 0) {
            if focusVM.timerState != .idle {
                activeSessionView
            } else {
                idleView
            }
        }
    }

    private var activeSessionView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MadoColors.accent)

                Text(focusVM.formattedTime)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundColor(MadoColors.textPrimary)
                    .contentTransition(.numericText())

                Spacer()

                if focusVM.timerState == .breakTime {
                    Text("Break")
                        .font(MadoTheme.Font.captionMedium)
                        .foregroundColor(MadoColors.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MadoColors.success.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("Session \(focusVM.currentSessionNumber)")
                        .font(MadoTheme.Font.caption)
                        .foregroundColor(MadoColors.textTertiary)
                }
            }

            if let taskTitle = focusVM.linkedTaskTitle {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.system(size: 10))
                    Text(taskTitle)
                        .font(MadoTheme.Font.callout)
                        .lineLimit(1)
                }
                .foregroundColor(MadoColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Progress bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(MadoColors.surfaceTertiary)
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(focusVM.timerState == .breakTime ? MadoColors.success : MadoColors.accent)
                            .frame(width: geo.size.width * focusVM.progress, height: 6)
                            .animation(MadoTheme.Animation.smooth, value: focusVM.progress)
                    }
            }
            .frame(height: 6)

            HStack(spacing: 16) {
                if focusVM.timerState == .running {
                    Button { focusVM.pause() } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .font(MadoTheme.Font.bodyMedium)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MadoColors.accent)
                } else if focusVM.timerState == .paused {
                    Button { focusVM.resume() } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(MadoTheme.Font.bodyMedium)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MadoColors.accent)
                } else if focusVM.timerState == .breakTime {
                    Button { focusVM.skipBreak() } label: {
                        Text("Skip Break")
                            .font(MadoTheme.Font.bodyMedium)
                    }
                    .buttonStyle(.bordered)
                }

                Button { focusVM.stop() } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(MadoTheme.Font.bodyMedium)
                }
                .buttonStyle(.bordered)
                .tint(MadoColors.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MadoColors.accentLight.opacity(0.3))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var idleView: some View {
        HStack {
            Button {
                focusVM.start()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 18))
                    Text("Start Focus")
                        .font(MadoTheme.Font.bodyMedium)
                }
                .foregroundColor(MadoColors.accent)
            }

            Spacer()

            if focusVM.todaySessionCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                    Text("\(focusVM.todaySessionCount) sessions")
                        .font(MadoTheme.Font.caption)
                    Text("·")
                    Text("\(focusVM.todayFocusMinutes)m")
                        .font(MadoTheme.Font.caption)
                }
                .foregroundColor(MadoColors.accent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
