import Foundation

struct TextFile: Identifiable, Hashable {
    let url: URL

    var id: String { url.standardizedFileURL.path }
    var name: String { url.lastPathComponent }
    var stem: String { url.deletingPathExtension().lastPathComponent }
    var fileExtension: String { url.pathExtension.lowercased() }

    var isMarkdown: Bool {
        ["md", "markdown", "mdown", "mkd"].contains(fileExtension)
    }

    var typeLabel: String {
        fileExtension.isEmpty ? "文本" : fileExtension.uppercased()
    }

    var modifiedAt: Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    var byteCount: Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
}
