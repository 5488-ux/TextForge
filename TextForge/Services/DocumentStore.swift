import Foundation
import SwiftUI

@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var files: [TextFile] = []
    @Published var errorMessage: String?

    private let fileManager = FileManager.default

    let supportedExtensions = [
        "srt", "txt", "md", "markdown", "json", "jsonl", "csv", "tsv",
        "yaml", "yml", "xml", "html", "htm", "css", "js", "mjs", "ts",
        "swift", "py", "java", "kt", "c", "h", "cpp", "hpp", "cs", "go",
        "rs", "php", "rb", "sh", "sql", "log", "ini", "conf", "toml"
    ]

    private var documentsDirectory: URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TextForgeFiles", isDirectory: true)
    }

    init() {
        createDirectoryIfNeeded()
        reload()
    }

    func reload() {
        createDirectoryIfNeeded()
        do {
            let urls = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            files = urls
                .filter { !$0.hasDirectoryPath }
                .map(TextFile.init)
                .sorted { $0.modifiedAt > $1.modifiedAt }
        } catch {
            report(error)
        }
    }

    @discardableResult
    func createFile(name rawName: String, extension rawExtension: String, content: String = "") throws -> TextFile {
        createDirectoryIfNeeded()
        let stem = sanitized(rawName.isEmpty ? "未命名" : rawName)
        let ext = sanitizedExtension(rawExtension)
        let baseName = ext.isEmpty ? stem : "\(stem).\(ext)"
        let destination = availableURL(for: baseName)
        try content.write(to: destination, atomically: true, encoding: .utf8)
        reload()
        return TextFile(url: destination)
    }

    @discardableResult
    func importFile(from source: URL) throws -> TextFile {
        createDirectoryIfNeeded()
        let accessing = source.startAccessingSecurityScopedResource()
        defer {
            if accessing { source.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: source)
        guard Self.decode(data: data) != nil else {
            throw DocumentError.binaryFile
        }

        let destination = availableURL(for: sanitized(source.lastPathComponent))
        try data.write(to: destination, options: .atomic)
        reload()
        return TextFile(url: destination)
    }

    func read(_ file: TextFile) throws -> String {
        let data = try Data(contentsOf: file.url)
        guard let text = Self.decode(data: data) else {
            throw DocumentError.binaryFile
        }
        return text
    }

    func save(_ text: String, to file: TextFile) throws {
        try text.write(to: file.url, atomically: true, encoding: .utf8)
        reload()
    }

    @discardableResult
    func rename(_ file: TextFile, to rawName: String) throws -> TextFile {
        let cleanName = sanitized(rawName)
        guard !cleanName.isEmpty else { throw DocumentError.invalidName }
        let destination = file.url.deletingLastPathComponent().appendingPathComponent(cleanName)
        guard destination != file.url else { return file }
        guard !fileManager.fileExists(atPath: destination.path) else { throw DocumentError.fileExists }
        try fileManager.moveItem(at: file.url, to: destination)
        reload()
        return TextFile(url: destination)
    }

    func delete(_ file: TextFile) throws {
        try fileManager.removeItem(at: file.url)
        reload()
    }

    func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    static func decode(data: Data) -> String? {
        if data.isEmpty { return "" }
        let encodings: [String.Encoding] = [
            .utf8, .utf16, .utf16LittleEndian, .utf16BigEndian,
            .utf32, .unicode, .ascii, .isoLatin1
        ]
        for encoding in encodings {
            if let value = String(data: data, encoding: encoding), !looksBinary(value) {
                return value
            }
        }
        return nil
    }

    private static func looksBinary(_ text: String) -> Bool {
        let sample = text.prefix(2_000)
        guard !sample.isEmpty else { return false }
        let controls = sample.filter { character in
            character.unicodeScalars.contains { scalar in
                scalar.value == 0 || (scalar.value < 9) || (scalar.value > 13 && scalar.value < 32)
            }
        }
        return Double(controls.count) / Double(sample.count) > 0.02
    }

    private func createDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        } catch {
            report(error)
        }
    }

    private func availableURL(for fileName: String) -> URL {
        let safeName = fileName.isEmpty ? "未命名.txt" : fileName
        let original = documentsDirectory.appendingPathComponent(safeName)
        guard fileManager.fileExists(atPath: original.path) else { return original }

        let ext = original.pathExtension
        let stem = original.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let candidateName = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            let candidate = documentsDirectory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private func sanitized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
    }

    private func sanitizedExtension(_ value: String) -> String {
        sanitized(value)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

enum DocumentError: LocalizedError {
    case binaryFile
    case invalidName
    case fileExists

    var errorDescription: String? {
        switch self {
        case .binaryFile: "这个文件像是二进制文件，不能当文本硬啃。"
        case .invalidName: "文件名不能为空。"
        case .fileExists: "同名文件已经存在。"
        }
    }
}
