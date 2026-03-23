import Foundation

/// Reads shared widget data written by the main app via App Group container.
struct WidgetDataReader {
    static let appGroupID = "group.io.mado.mobile"
    
    static func read() -> WidgetSharedData {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return .empty
        }
        
        let fileURL = containerURL.appendingPathComponent("widget_data.json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data) else {
            return .empty
        }
        
        return decoded
    }
}
