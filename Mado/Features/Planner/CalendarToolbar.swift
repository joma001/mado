import SwiftUI

struct CalendarToolbar: View {
    @Bindable var viewModel: CalendarViewModel

    @State private var hoveredNavButton: String?
    @State private var isSyncHovered = false
    @State private var isTodayHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Navigation arrows — grouped pill
            HStack(spacing: 0) {
                navButton("chevron.left") { viewModel.navigateBack() }
                Divider().frame(height: 14).opacity(0.3)
                navButton("chevron.right") { viewModel.navigateForward() }
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(MadoColors.surfaceSecondary)
            )

            // Date title
            Text(viewModel.headerTitle)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(MadoColors.textPrimary)
                .lineLimit(1)

            // Timezone badge
            Text(TimeZone.current.abbreviation() ?? "")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(MadoColors.textTertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(MadoColors.surfaceSecondary)
                )

            if AppSettings.shared.showWeekNumbers {
                Text("W\(Calendar.current.component(.weekOfYear, from: viewModel.selectedDate))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(MadoColors.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(MadoColors.surfaceSecondary)
                    )
            }

            // Today button
            Button { viewModel.goToToday() } label: {
                Text("Today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(MadoColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isTodayHovered ? MadoColors.accentLight : MadoColors.surfaceSecondary)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isTodayHovered = $0 }

            // Sync
            Button {
                Task { await SyncEngine.shared.syncAll() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSyncHovered ? MadoColors.textPrimary : MadoColors.textTertiary)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSyncHovered ? MadoColors.surfaceSecondary : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isSyncHovered = $0 }
            .help("Sync (⌘R)")

            Spacer()

            // View mode picker
            viewModePicker
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MadoColors.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MadoColors.divider)
                .frame(height: 1)
        }
    }

    // MARK: - Navigation Button

    @ViewBuilder
    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(hoveredNavButton == icon ? MadoColors.textPrimary : MadoColors.textSecondary)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredNavButton = $0 ? icon : nil }
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack(spacing: 2) {
            ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(MadoTheme.Animation.quick) {
                        viewModel.viewMode = mode
                        viewModel.loadEvents()
                    }
                } label: {
                    Text(mode.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(viewModel.viewMode == mode ? .white : MadoColors.textTertiary)
                        .frame(width: 26, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(viewModel.viewMode == mode ? MadoColors.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(MadoColors.surfaceSecondary)
        )
    }
}
