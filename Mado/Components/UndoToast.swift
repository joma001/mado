import SwiftUI

struct UndoToastOverlay: View {
    private let engine = UndoEngine.shared

    var body: some View {
        VStack {
            Spacer()
            if let toast = engine.currentToast {
                UndoToastView(data: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
        .animation(.spring(duration: 0.3), value: engine.currentToast)
    }
}

private struct UndoToastView: View {
    let data: UndoToastData
    private let engine = UndoEngine.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Text(data.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                engine.undoLast()
            } label: {
                Text("Undo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MadoColors.accent)
            }
            .buttonStyle(.plain)

            Button {
                engine.hideToast()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(MadoColors.primary)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .frame(maxWidth: 400)
        .padding(.horizontal, 20)
    }

    private var iconName: String {
        switch data.kind {
        case .taskCreated, .eventCreated: return "plus.circle"
        case .taskDeleted, .eventDeleted: return "trash"
        case .taskCompleted: return "checkmark.circle"
        case .taskUncompleted: return "circle"
        case .taskEdited, .eventEdited: return "pencil"
        case .taskMoved: return "arrow.right"
        case .rsvpChanged: return "envelope"
        }
    }
}
