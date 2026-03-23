import Foundation

// MARK: - Note File Item

struct NoteFileItem: Identifiable, Hashable {
    let id: String           // relative path from vault root
    let name: String         // filename
    let url: URL
    let isFolder: Bool
    let modifiedDate: Date
    var children: [NoteFileItem]?

    var displayName: String {
        if isFolder { return name }
        return name.hasSuffix(".md") ? String(name.dropLast(3)) : name
    }
}

// MARK: - Note File Manager

@MainActor
@Observable
final class NoteFileManager {
    static let shared = NoteFileManager()

    var items: [NoteFileItem] = []
    var vaultURL: URL

    private let fm = FileManager.default

    private init() {
        #if os(macOS)
        // macOS: ~/Documents/mado/
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        vaultURL = docs.appendingPathComponent("mado", conformingTo: .folder)
        #else
        // iOS: App Documents/mado/
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        vaultURL = docs.appendingPathComponent("mado", conformingTo: .folder)
        #endif

        ensureVaultExists()
        loadFiles()
    }

    // MARK: - Directory Setup

    private func ensureVaultExists() {
        if !fm.fileExists(atPath: vaultURL.path) {
            try? fm.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Load Files

    func loadFiles() {
        items = scanDirectory(vaultURL)
    }

    private func scanDirectory(_ url: URL) -> [NoteFileItem] {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [NoteFileItem] = []

        for itemURL in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            let isDir = resourceValues?.isDirectory ?? false
            let modified = resourceValues?.contentModificationDate ?? Date()
            let relativePath = itemURL.path.replacingOccurrences(of: vaultURL.path + "/", with: "")

            if isDir {
                let children = scanDirectory(itemURL)
                result.append(NoteFileItem(
                    id: relativePath,
                    name: itemURL.lastPathComponent,
                    url: itemURL,
                    isFolder: true,
                    modifiedDate: modified,
                    children: children
                ))
            } else if itemURL.pathExtension == "md" {
                result.append(NoteFileItem(
                    id: relativePath,
                    name: itemURL.lastPathComponent,
                    url: itemURL,
                    isFolder: false,
                    modifiedDate: modified
                ))
            }
        }

        // Folders first, then files sorted by modified date (newest first)
        return result.sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            return a.modifiedDate > b.modifiedDate
        }
    }

    // MARK: - CRUD

    func readFile(_ item: NoteFileItem) -> String {
        (try? String(contentsOf: item.url, encoding: .utf8)) ?? ""
    }

    func writeFile(_ item: NoteFileItem, content: String) {
        try? content.write(to: item.url, atomically: true, encoding: .utf8)
    }

    func createFile(name: String, inFolder: URL? = nil) -> NoteFileItem? {
        let sanitized = sanitizeFilename(name)
        let fileName = sanitized.hasSuffix(".md") ? sanitized : "\(sanitized).md"
        let parent = inFolder ?? vaultURL
        let fileURL = parent.appendingPathComponent(fileName)

        guard !fm.fileExists(atPath: fileURL.path) else { return nil }

        // Start with empty content — user fills in the body
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        loadFiles()

        let relativePath = fileURL.path.replacingOccurrences(of: vaultURL.path + "/", with: "")
        return NoteFileItem(
            id: relativePath,
            name: fileName,
            url: fileURL,
            isFolder: false,
            modifiedDate: Date()
        )
    }

    func createFolder(name: String, inFolder: URL? = nil) {
        let parent = inFolder ?? vaultURL
        let folderURL = parent.appendingPathComponent(sanitizeFilename(name))
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        loadFiles()
    }

    func deleteItem(_ item: NoteFileItem) {
        try? fm.removeItem(at: item.url)
        loadFiles()
    }

    func renameItem(_ item: NoteFileItem, to newName: String) {
        let sanitized = sanitizeFilename(newName)
        let newFileName = item.isFolder ? sanitized : (sanitized.hasSuffix(".md") ? sanitized : "\(sanitized).md")
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newFileName)
        try? fm.moveItem(at: item.url, to: newURL)
        loadFiles()
    }

    // MARK: - Search

    func search(query: String) -> [NoteFileItem] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        return flatFiles().filter { item in
            if item.displayName.lowercased().contains(lowered) { return true }
            let content = readFile(item)
            return content.lowercased().contains(lowered)
        }
    }

    func flatFiles() -> [NoteFileItem] {
        flattenItems(items)
    }

    private func flattenItems(_ items: [NoteFileItem]) -> [NoteFileItem] {
        var result: [NoteFileItem] = []
        for item in items {
            if item.isFolder {
                if let children = item.children {
                    result.append(contentsOf: flattenItems(children))
                }
            } else {
                result.append(item)
            }
        }
        return result
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: illegal).joined(separator: "-").trimmingCharacters(in: .whitespaces)
    }
}
