import SwiftUI

struct PriorityBadge: View {
    let priority: TaskPriority

    private var label: String? {
        switch priority {
        case .high: return "1"
        case .medium: return "2"
        case .low: return "3"
        case .none: return nil
        }
    }

    private var color: Color {
        switch priority {
        case .high: return MadoColors.priorityHigh
        case .medium: return MadoColors.priorityMedium
        case .low: return MadoColors.priorityLow
        case .none: return .clear
        }
    }

    var body: some View {
        if let label {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.xs))
        }
    }
}
