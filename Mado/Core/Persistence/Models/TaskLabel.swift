import Foundation
import SwiftData
import SwiftUI

// MARK: - Preset Label Colors
enum LabelColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, gray

    var background: Color {
        switch self {
        case .red: return MadoColors.labelRed
        case .orange: return MadoColors.labelOrange
        case .yellow: return MadoColors.labelYellow
        case .green: return MadoColors.labelGreen
        case .blue: return MadoColors.labelBlue
        case .purple: return MadoColors.labelPurple
        case .pink: return MadoColors.labelPink
        case .gray: return MadoColors.labelGray
        }
    }

    var foreground: Color {
        switch self {
        case .red: return MadoColors.labelRedText
        case .orange: return MadoColors.labelOrangeText
        case .yellow: return MadoColors.labelYellowText
        case .green: return MadoColors.labelGreenText
        case .blue: return MadoColors.labelBlueText
        case .purple: return MadoColors.labelPurpleText
        case .pink: return MadoColors.labelPinkText
        case .gray: return MadoColors.labelGrayText
        }
    }
}

// MARK: - TaskLabel SwiftData Model
@Model
final class TaskLabel {
    @Attribute(.unique) var id: String = UUID().uuidString
    var name: String = ""
    var colorRaw: String = "gray"
    var position: Int = 0
    var color: LabelColor {
        get { LabelColor(rawValue: colorRaw) ?? .gray }
        set { colorRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        color: LabelColor = .gray,
        position: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorRaw = color.rawValue
        self.position = position
    }
}
