import Foundation

struct GoogleTasksService {
    private let baseURL = "https://tasks.googleapis.com/tasks/v1"
    private let client = APIClient.shared

    func listTaskLists() async throws -> GoogleTaskListsResponse {
        try await client.get(url: "\(baseURL)/users/@me/lists")
    }

    func listTasks(
        listId: String,
        showCompleted: Bool = true,
        updatedMin: Date? = nil,
        pageToken: String? = nil
    ) async throws -> GoogleTasksResponse {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "showCompleted", value: String(showCompleted)),
            URLQueryItem(name: "showHidden", value: "true"),
            URLQueryItem(name: "maxResults", value: "100"),
        ]
        if let updatedMin {
            query.append(URLQueryItem(name: "updatedMin", value: ISO8601DateFormatter().string(from: updatedMin)))
        }
        if let pageToken {
            query.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        return try await client.get(
            url: "\(baseURL)/lists/\(listId)/tasks",
            queryItems: query
        )
    }

    func listAllTasks(listId: String, updatedMin: Date? = nil) async throws -> [GoogleTaskDTO] {
        var all: [GoogleTaskDTO] = []
        var pageToken: String?
        repeat {
            let response = try await listTasks(listId: listId, updatedMin: updatedMin, pageToken: pageToken)
            all.append(contentsOf: response.items ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil
        return all
    }

    func createTask(listId: String, task: GoogleTaskDTO) async throws -> GoogleTaskDTO {
        try await client.post(url: "\(baseURL)/lists/\(listId)/tasks", body: task)
    }

    func updateTask(listId: String, taskId: String, task: GoogleTaskDTO) async throws -> GoogleTaskDTO {
        try await client.put(url: "\(baseURL)/lists/\(listId)/tasks/\(taskId)", body: task)
    }

    func deleteTask(listId: String, taskId: String) async throws {
        try await client.delete(url: "\(baseURL)/lists/\(listId)/tasks/\(taskId)")
    }
}

struct GoogleTaskListsResponse: Codable {
    let kind: String?
    let items: [GoogleTaskListDTO]?
}

struct GoogleTaskListDTO: Codable, Identifiable {
    let id: String
    let title: String?
    let updated: Date?
}

struct GoogleTasksResponse: Codable {
    let kind: String?
    let items: [GoogleTaskDTO]?
    let nextPageToken: String?
}

struct GoogleTaskDTO: Codable, Identifiable {
    var id: String?
    var title: String?
    var notes: String?
    var status: String? // "needsAction" or "completed"
    var due: String? // RFC 3339 date string
    var updated: Date?
    var parent: String?
    var position: String?
    var deleted: Bool?

    var isDone: Bool {
        status == "completed"
    }

    static func from(task: MadoTask) -> GoogleTaskDTO {
        var dto = GoogleTaskDTO()
        dto.id = task.googleTaskId
        dto.title = task.title
        dto.notes = task.notes
        dto.status = task.isCompleted ? "completed" : "needsAction"
        if let due = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'00:00:00.000'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
            dto.due = formatter.string(from: due)
        }
        dto.parent = task.parentTaskId
        return dto
    }
}
