import SwiftUI

struct FocusTimerView: View {
    let viewModel: FocusTimerViewModel
    var compact: Bool = false

    private var ringSize: CGFloat { compact ? 100 : 160 }
    private var ringLineWidth: CGFloat { compact ? 6 : 8 }
    private var timeFont: Font { compact ? .system(size: 24, weight: .medium, design: .monospaced) : .system(size: 36, weight: .medium, design: .monospaced) }

    var body: some View {
        VStack(spacing: MadoTheme.Spacing.md) {
            // Circular progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(MadoColors.surfaceTertiary, lineWidth: ringLineWidth)

                // Progress ring
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(MadoTheme.Animation.smooth, value: viewModel.progress)

                // Time display
                VStack(spacing: MadoTheme.Spacing.xxxs) {
                    Text(viewModel.formattedTime)
                        .font(timeFont)
                        .foregroundColor(MadoColors.textPrimary)
                        .contentTransition(.numericText())

                    if viewModel.timerState == .breakTime {
                        Text("Break")
                            .font(MadoTheme.Font.caption)
                            .foregroundColor(MadoColors.success)
                    } else if viewModel.timerState != .idle {
                        Text("Session \(viewModel.currentSessionNumber)")
                            .font(MadoTheme.Font.caption)
                            .foregroundColor(MadoColors.textTertiary)
                    }
                }
            }
            .frame(width: ringSize, height: ringSize)

            // Linked task name
            if let taskTitle = viewModel.linkedTaskTitle {
                HStack(spacing: MadoTheme.Spacing.xxs) {
                    Image(systemName: "target")
                        .font(.system(size: 10))
                    Text(taskTitle)
                        .font(MadoTheme.Font.caption)
                        .lineLimit(1)
                }
                .foregroundColor(MadoColors.textSecondary)
            }

            // Controls
            controlButtons
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlButtons: some View {
        switch viewModel.timerState {
        case .idle:
            if viewModel.suggestsLongBreak {
                VStack(spacing: MadoTheme.Spacing.sm) {
                    Text(viewModel.isBreakLong ? "Time for a long break!" : "Take a break")
                        .font(MadoTheme.Font.callout)
                        .foregroundColor(MadoColors.textSecondary)

                    HStack(spacing: MadoTheme.Spacing.sm) {
                        Button("Start Break") {
                            viewModel.startBreak()
                        }
                        .buttonStyle(MadoButtonStyle(variant: .primary))

                        Button("Skip") {
                            viewModel.skipBreak()
                        }
                        .buttonStyle(MadoButtonStyle(variant: .ghost))
                    }
                }
            } else {
                Button {
                    viewModel.start()
                } label: {
                    HStack(spacing: MadoTheme.Spacing.xxs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("Start Focus")
                    }
                }
                .buttonStyle(MadoButtonStyle(variant: .primary))
                .accessibilityLabel("Start focus session")
            }

        case .running:
            HStack(spacing: MadoTheme.Spacing.sm) {
                Button {
                    viewModel.pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(MadoButtonStyle(variant: .secondary))
                .accessibilityLabel("Pause session")

                Button {
                    viewModel.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(MadoButtonStyle(variant: .ghost))
                .accessibilityLabel("Stop session")
            }

        case .paused:
            HStack(spacing: MadoTheme.Spacing.sm) {
                Button {
                    viewModel.resume()
                } label: {
                    HStack(spacing: MadoTheme.Spacing.xxs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                        Text("Resume")
                    }
                }
                .buttonStyle(MadoButtonStyle(variant: .primary))
                .accessibilityLabel("Resume session")

                Button {
                    viewModel.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(MadoButtonStyle(variant: .ghost))
                .accessibilityLabel("Stop session")
            }

        case .breakTime:
            Button {
                viewModel.skipBreak()
            } label: {
                Text("Skip Break")
            }
            .buttonStyle(MadoButtonStyle(variant: .ghost))
            .accessibilityLabel("Skip break")
        }
    }

    // MARK: - Helpers

    private var ringColor: Color {
        switch viewModel.timerState {
        case .idle: return MadoColors.accent
        case .running: return MadoColors.accent
        case .paused: return MadoColors.warning
        case .breakTime: return MadoColors.success
        }
    }
}
