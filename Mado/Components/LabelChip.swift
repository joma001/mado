import SwiftUI

struct LabelChip: View {
    let label: TaskLabel
    var onRemove: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: MadoTheme.Spacing.xxs) {
            Text(label.name)
                .font(MadoTheme.Font.caption)
                .foregroundColor(label.color.foreground)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(label.color.foreground.opacity(0.7))
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding(.horizontal, MadoTheme.Spacing.sm)
        .padding(.vertical, MadoTheme.Spacing.xxxs + 1)
        .background(label.color.background)
        .clipShape(Capsule())
        .onHover { isHovered = $0 }
    }
}
