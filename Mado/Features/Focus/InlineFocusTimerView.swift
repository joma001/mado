import SwiftUI

/// Compact inline focus timer shown in the task panel when a session is active.
struct InlineFocusTimerView: View {
    let viewModel: FocusTimerViewModel
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: MadoTheme.Spacing.sm) {
                // Progress ring (mini)
                ZStack {
                    Circle()
                        .stroke(MadoColors.surfaceTertiary, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(MadoTheme.Animation.smooth, value: viewModel.progress)
                }
                .frame(width: 28, height: 28)

                // Time + status
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.formattedTime)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(MadoColors.textPrimary)
                        .contentTransition(.numericText())

                    if let taskTitle = viewModel.linkedTaskTitle {
                        Text(taskTitle)
                            .font(MadoTheme.Font.tiny)
                            .foregroundColor(MadoColors.textTertiary)
                            .lineLimit(1)
                    } else {
                        Text(statusLabel)
                            .font(MadoTheme.Font.tiny)
                            .foregroundColor(statusColor)
                    }
                }

                Spacer()

                // Inline controls
                HStack(spacing: MadoTheme.Spacing.xs) {
                    if viewModel.timerState == .running {
                        controlButton(icon: "pause.fill") { viewModel.pause() }
                    } else if viewModel.timerState == .paused {
                        controlButton(icon: "play.fill") { viewModel.resume() }
                    } else if viewModel.timerState == .breakTime {
                        controlButton(icon: "forward.fill") { viewModel.skipBreak() }
                    }

                    if viewModel.timerState != .idle {
                        controlButton(icon: "stop.fill") { viewModel.stop() }
                    }
                }
            }
            .padding(.horizontal, MadoTheme.Spacing.md)
            .padding(.vertical, MadoTheme.Spacing.sm)
            .background(ringColor.opacity(0.06))
            .overlay(alignment: .bottom) {
                Divider().foregroundColor(MadoColors.divider)
            }
        }
        .buttonStyle(.plain)
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(MadoColors.textSecondary)
                .frame(width: 26, height: 26)
                .background(MadoColors.surfaceSecondary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var ringColor: Color {
        switch viewModel.timerState {
        case .idle: return MadoColors.accent
        case .running: return MadoColors.accent
        case .paused: return MadoColors.warning
        case .breakTime: return MadoColors.success
        }
    }

    private var statusLabel: String {
        switch viewModel.timerState {
        case .idle: return ""
        case .running: return "Focusing — Session \(viewModel.currentSessionNumber)"
        case .paused: return "Paused"
        case .breakTime: return viewModel.isBreakLong ? "Long Break" : "Short Break"
        }
    }

    private var statusColor: Color {
        switch viewModel.timerState {
        case .paused: return MadoColors.warning
        case .breakTime: return MadoColors.success
        default: return MadoColors.textTertiary
        }
    }
}
