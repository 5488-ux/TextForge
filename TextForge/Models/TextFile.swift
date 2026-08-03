import CoreFoundation
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

    var isSubtitle: Bool {
        fileExtension == "srt"
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

enum DocumentLineEnding: String, CaseIterable, Sendable {
    case lf = "LF"
    case crlf = "CRLF"
    case cr = "CR"

    var separator: String {
        switch self {
        case .lf: "\n"
        case .crlf: "\r\n"
        case .cr: "\r"
        }
    }
}

enum DocumentTextEncoding: String, CaseIterable, Sendable {
    case utf8 = "UTF-8"
    case utf8BOM = "UTF-8 BOM"
    case utf16LittleEndian = "UTF-16 LE"
    case utf16BigEndian = "UTF-16 BE"
    case utf32LittleEndian = "UTF-32 LE"
    case utf32BigEndian = "UTF-32 BE"
    case gb18030 = "GB18030 / GBK"
    case isoLatin1 = "ISO Latin-1"

    var foundationEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8BOM: .utf8
        case .utf16LittleEndian: .utf16LittleEndian
        case .utf16BigEndian: .utf16BigEndian
        case .utf32LittleEndian: .utf32LittleEndian
        case .utf32BigEndian: .utf32BigEndian
        case .gb18030:
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0632)))
        case .isoLatin1: .isoLatin1
        }
    }
}

struct DocumentContent: Sendable {
    static let largeFileThreshold: Int64 = 1_048_576

    let text: String
    let encoding: DocumentTextEncoding
    let lineEnding: DocumentLineEnding
    let byteCount: Int64

    var isLargeFile: Bool {
        byteCount >= Self.largeFileThreshold
    }
}
