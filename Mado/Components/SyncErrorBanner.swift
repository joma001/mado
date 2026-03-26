import SwiftUI

struct SyncErrorBanner: View {
    private let sync = SyncEngine.shared

    var body: some View {
        if case .error(let kind) = sync.status {
            SyncErrorBannerContent(
                kind: kind,
                pendingCount: sync.pendingChangesCount
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

private struct SyncErrorBannerContent: View {
    let kind: SyncErrorKind
    let pendingCount: Int
    @State private var visible = true
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        Group {
            if visible {
                HStack(spacing: MadoTheme.Spacing.sm) {
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MadoColors.onAccent)

                    Text(labelText)
                        .font(MadoTheme.Font.captionMedium)
                        .foregroundColor(MadoColors.onAccent)
                        .lineLimit(1)

                    Spacer(minLength: MadoTheme.Spacing.xxs)

                    if case .authExpired = kind {
                        Button("재로그인") {
                            Task { await AuthenticationManager.shared.addAccount() }
                        }
                        .font(MadoTheme.Font.captionMedium)
                        .foregroundColor(MadoColors.onAccent)
                        .padding(.horizontal, MadoTheme.Spacing.sm)
                        .padding(.vertical, MadoTheme.Spacing.xxs)
                        .background(Color.white.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
                        .buttonStyle(.plain)
                    } else if case .apiError = kind {
                        Button("재시도") {
                            Task { await SyncEngine.shared.syncAll() }
                        }
                        .font(MadoTheme.Font.captionMedium)
                        .foregroundColor(MadoColors.onAccent)
                        .padding(.horizontal, MadoTheme.Spacing.sm)
                        .padding(.vertical, MadoTheme.Spacing.xxs)
                        .background(Color.white.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
                        .buttonStyle(.plain)
                    }

                    Button {
                        withAnimation(MadoTheme.Animation.dismiss) { visible = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(MadoColors.onAccent.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, MadoTheme.Spacing.lg)
                .padding(.vertical, MadoTheme.Spacing.sm)
                .background(bannerColor)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("동기화 오류: \(labelText)")
                .onAppear { scheduleAutoDismiss() }
                .onChange(of: kind) { _, _ in
                    visible = true
                    scheduleAutoDismiss()
                }
            }
        }
        .animation(MadoTheme.Animation.standard, value: visible)
    }

    private var iconName: String {
        switch kind {
        case .networkUnavailable: return "wifi.slash"
        case .authExpired:        return "person.crop.circle.badge.exclamationmark"
        case .apiError:           return "exclamationmark.triangle"
        case .storeError:         return "externaldrive.badge.exclamationmark"
        }
    }

    private var labelText: String {
        switch kind {
        case .networkUnavailable:
            if pendingCount > 0 {
                return "오프라인 — \(pendingCount)건 동기화 대기중"
            }
            return "오프라인 상태입니다"
        case .authExpired:
            return "로그인이 만료되었습니다"
        case .apiError(let service, _):
            return "동기화 오류: \(service)"
        case .storeError:
            return "데이터 저장소 오류"
        }
    }

    private var bannerColor: Color {
        switch kind {
        case .networkUnavailable: return MadoColors.textSecondary
        case .authExpired:        return MadoColors.error
        case .apiError:           return MadoColors.warning
        case .storeError:         return MadoColors.error
        }
    }

    private func scheduleAutoDismiss() {
        // Network-unavailable and auth errors stay visible until resolved
        switch kind {
        case .networkUnavailable, .authExpired:
            dismissTask?.cancel()
            dismissTask = nil
        default:
            dismissTask?.cancel()
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(MadoTheme.Animation.dismiss) { visible = false }
                }
            }
        }
    }
}
