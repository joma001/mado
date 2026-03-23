import Foundation
import SwiftData
import SwiftUI

// MARK: - Project Color
enum ProjectColor: String, Codable, CaseIterable {
    case blue, purple, green, orange, red, pink, yellow, gray

    var color: Color {
        switch self {
        case .blue: return Color(hex: "2383E2")
        case .purple: return Color(hex: "7B68EE")
        case .green: return Color(hex: "27AE60")
        case .orange: return Color(hex: "E67E22")
        case .red: return Color(hex: "EB5757")
        case .pink: return Color(hex: "E84393")
        case .yellow: return Color(hex: "F2994A")
        case .gray: return Color(hex: "9B9A97")
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

// MARK: - Project SwiftData Model
@Model
final class Project {
    @Attribute(.unique) var id: String = UUID().uuidString
    var googleTaskListId: String?

    var name: String = ""
    var colorRaw: String = "blue"
    var iconName: String = "folder.fill"
    var position: Int = 0
    var isExpanded: Bool = true
    var createdAt: Date = Date()
    var isDeleted: Bool = false
    var color: ProjectColor {
        get { ProjectColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }

    var displayColor: Color {
        color.color
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        color: ProjectColor = .blue,
        iconName: String = "folder.fill",
        position: Int = 0,
        googleTaskListId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorRaw = color.rawValue
        self.iconName = iconName
        self.position = position
        self.isExpanded = true
        self.createdAt = Date()
        self.isDeleted = false
        self.googleTaskListId = googleTaskListId
    }
}
