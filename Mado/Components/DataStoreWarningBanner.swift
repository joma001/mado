import SwiftUI

struct DataStoreWarningBanner: View {
    private let dataController = DataController.shared
    @State private var showErrorAlert = false

    var body: some View {
        if dataController.isUsingFallbackStore {
            HStack(spacing: MadoTheme.Spacing.sm) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MadoColors.primary)

                Text("데이터가 임시 저장소에 저장되고 있습니다")
                    .font(MadoTheme.Font.captionMedium)
                    .foregroundColor(MadoColors.primary)
                    .lineLimit(1)

                Spacer(minLength: MadoTheme.Spacing.xxs)

                Button("자세히 보기") {
                    showErrorAlert = true
                }
                .font(MadoTheme.Font.captionMedium)
                .foregroundColor(MadoColors.primary)
                .padding(.horizontal, MadoTheme.Spacing.sm)
                .padding(.vertical, MadoTheme.Spacing.xxs)
                .background(MadoColors.primary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.sm))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, MadoTheme.Spacing.lg)
            .padding(.vertical, MadoTheme.Spacing.sm)
            .background(MadoColors.warning.opacity(0.18))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("경고: 데이터가 임시 저장소에 저장되고 있습니다")
            .alert("저장소 오류", isPresented: $showErrorAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(dataController.storeError ?? "알 수 없는 오류가 발생했습니다.")
            }
        }
    }
}
