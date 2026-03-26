import SwiftUI

struct PriorityBadge: View {
    let priority: TaskPriority

    private var iconName: String? {
        switch priority {
        case .high: return "exclamationmark.3"
        case .medium: return "exclamationmark.2"
        case .low: return "minus"
        case .none: return nil
        }
    }

    private var accessibilityLabel: String? {
        switch priority {
        case .high: return "높은 우선순위"
        case .medium: return "중간 우선순위"
        case .low: return "낮은 우선순위"
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
        if let iconName, let label = accessibilityLabel {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .frame(width: 18, height: 18)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: MadoTheme.Radius.xs))
                .accessibilityLabel(label)
        }
    }
}
