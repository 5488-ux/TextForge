import Foundation
import SwiftUI

struct DocumentImportProgress: Equatable {
    let fileName: String
    let completedFiles: Int
    let totalFiles: Int
    let fileFraction: Double
    let phase: String

    var overallFraction: Double {
        guard totalFiles > 0 else { return 0 }
        let value = (Double(completedFiles) + fileFraction) / Double(totalFiles)
        return min(1, max(0, value))
    }

    var countText: String {
        "\(min(completedFiles + 1, totalFiles)) / \(totalFiles)"
    }
}

@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var files: [TextFile] = []
    @Published private(set) var importProgress: DocumentImportProgress?
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
    func createFile(
        name rawName: String,
        extension rawExtension: String,
        content: String = ""
    ) throws -> TextFile {
        createDirectoryIfNeeded()
        let stem = sanitized(rawName.isEmpty ? "未命名" : rawName)
        let ext = sanitizedExtension(rawExtension)
        let baseName = ext.isEmpty ? stem : "\(stem).\(ext)"
        let destination = availableURL(for: baseName)
        try content.write(to: destination, atomically: true, encoding: .utf8)
        reload()
        return TextFile(url: destination)
    }

    func importFiles(from sources: [URL]) async throws -> [TextFile] {
        guard !sources.isEmpty else { return [] }
        createDirectoryIfNeeded()

        let totalFiles = sources.count
        var importedFiles: [TextFile] = []

        do {
            for (index, source) in sources.enumerated() {
                try Task.checkCancellation()

                let fileName = sanitized(source.lastPathComponent)
                let destination = availableURL(for: fileName)
                importProgress = DocumentImportProgress(
                    fileName: fileName,
                    completedFiles: index,
                    totalFiles: totalFiles,
                    fileFraction: 0,
                    phase: "正在准备"
                )

                try await Self.copyTextFile(
                    from: source,
                    to: destination
                ) { [weak self] fraction, phase in
                    Task { @MainActor [weak self] in
                        self?.importProgress = DocumentImportProgress(
                            fileName: fileName,
                            completedFiles: index,
                            totalFiles: totalFiles,
                            fileFraction: fraction,
                            phase: phase
                        )
                    }
                }

                importedFiles.append(TextFile(url: destination))
            }

            importProgress = nil
            reload()
            return importedFiles
        } catch {
            importProgress = nil
            reload()
            throw error
        }
    }

    func read(_ file: TextFile) throws -> String {
        let data = try Data(contentsOf: file.url)
        guard let text = Self.decode(data: data) else {
            throw DocumentError.binaryFile
        }
        return text
    }

    func readAsync(_ file: TextFile) async throws -> String {
        let url = file.url
        return try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            guard let text = Self.decode(data: data) else {
                throw DocumentError.binaryFile
            }
            return text
        }.value
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
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw DocumentError.fileExists
        }
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

    nonisolated static func decode(data: Data) -> String? {
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

    nonisolated private static func looksBinary(_ text: String) -> Bool {
        let sample = text.prefix(2_000)
        guard !sample.isEmpty else { return false }
        let controls = sample.filter { character in
            character.unicodeScalars.contains { scalar in
                scalar.value == 0 || scalar.value < 9 || (scalar.value > 13 && scalar.value < 32)
            }
        }
        return Double(controls.count) / Double(sample.count) > 0.02
    }

    nonisolated private static func copyTextFile(
        from source: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        let accessing = source.startAccessingSecurityScopedResource()
        defer {
            if accessing { source.stopAccessingSecurityScopedResource() }
        }

        let manager = FileManager.default
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationError: Error?

        coordinator.coordinate(
            readingItemAt: source,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try copyCoordinatedTextFile(
                    from: coordinatedURL,
                    to: destination,
                    progress: progress
                )
            } catch {
                operationError = error
            }
        }

        if let coordinationError {
            try? manager.removeItem(at: destination)
            throw coordinationError
        }
        if let operationError {
            try? manager.removeItem(at: destination)
            throw operationError
        }
    }

    nonisolated private static func copyCoordinatedTextFile(
        from source: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double, String) -> Void
    ) throws {
        let manager = FileManager.default
        let values = try source.resourceValues(forKeys: [.fileSizeKey])
        let expectedBytes = Int64(values.fileSize ?? 0)

        guard manager.createFile(atPath: destination.path, contents: nil) else {
            throw CocoaError(.fileWriteFileExists)
        }

        let input = try FileHandle(forReadingFrom: source)
        let output = try FileHandle(forWritingTo: destination)

        do {
            var copiedBytes: Int64 = 0
            var lastReportedFraction = -1.0

            while true {
                try Task.checkCancellation()
                let chunk = try input.read(upToCount: 512 * 1_024) ?? Data()
                if chunk.isEmpty { break }

                try output.write(contentsOf: chunk)
                copiedBytes += Int64(chunk.count)

                let fraction: Double
                if expectedBytes > 0 {
                    fraction = min(0.98, Double(copiedBytes) / Double(expectedBytes))
                } else {
                    fraction = 0.50
                }

                if fraction - lastReportedFraction >= 0.01 {
                    lastReportedFraction = fraction
                    progress(fraction, "正在复制")
                }
            }

            try output.synchronize()
            try input.close()
            try output.close()
        } catch {
            try? input.close()
            try? output.close()
            try? manager.removeItem(at: destination)
            throw error
        }

        progress(0.99, "正在检查文本")

        do {
            let validationHandle = try FileHandle(forReadingFrom: destination)
            let sample = try validationHandle.read(upToCount: 256 * 1_024) ?? Data()
            try validationHandle.close()

            guard decode(data: sample) != nil else {
                throw DocumentError.binaryFile
            }
        } catch {
            try? manager.removeItem(at: destination)
            throw error
        }

        progress(1, "导入完成")
    }

    private func createDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(
                at: documentsDirectory,
                withIntermediateDirectories: true
            )
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
