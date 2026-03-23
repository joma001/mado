import Foundation

// MARK: - Shared Data Models (used by both main app and widget extension)

struct WidgetSharedData: Codable {
    let events: [WidgetEvent]
    let tasks: [WidgetTask]
    let lastUpdated: Date
}

struct WidgetEvent: Codable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let colorHex: String
    let hasConference: Bool
    
    var timeString: String {
        if isAllDay { return "All day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "\(fmt.string(from: startDate)) – \(fmt.string(from: endDate))"
    }
    
    var shortTimeString: String {
        if isAllDay { return "All day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: startDate)
    }
}

struct WidgetTask: Codable, Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let isCompleted: Bool
}

extension WidgetSharedData {
    static let empty = WidgetSharedData(events: [], tasks: [], lastUpdated: .distantPast)
}
