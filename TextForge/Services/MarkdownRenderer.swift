import Foundation

struct MarkdownBlock: Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case heading(Int)
        case paragraph
        case bullet
        case numbered(String)
        case quote
        case code
        case separator
        case spacer
    }

    let id: Int
    let kind: Kind
    let content: String
    let attributed: AttributedString
}

enum MarkdownRenderer {
    nonisolated static func parse(_ source: String) -> [MarkdownBlock] {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)

        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var isInsideCodeBlock = false

        func inline(_ text: String) -> AttributedString {
            let options = AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
            return (try? AttributedString(markdown: text, options: options))
                ?? AttributedString(text)
        }

        func append(_ kind: MarkdownBlock.Kind, _ content: String) {
            blocks.append(
                MarkdownBlock(
                    id: blocks.count,
                    kind: kind,
                    content: content,
                    attributed: inline(content)
                )
            )
        }

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            append(.paragraph, paragraphLines.joined(separator: "\n"))
            paragraphLines.removeAll(keepingCapacity: true)
        }

        for (index, rawLine) in lines.enumerated() {
            if index.isMultiple(of: 200), Task.isCancelled { break }

            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isInsideCodeBlock {
                if trimmed.hasPrefix("```") {
                    append(.code, codeLines.joined(separator: "\n"))
                    codeLines.removeAll(keepingCapacity: true)
                    isInsideCodeBlock = false
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if trimmed.hasPrefix("```") {
                flushParagraph()
                isInsideCodeBlock = true
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                if blocks.last?.kind != .spacer {
                    append(.spacer, "")
                }
                continue
            }

            if ["---", "***", "___"].contains(trimmed) {
                flushParagraph()
                append(.separator, "")
                continue
            }

            let headingLevel = trimmed.prefix { $0 == "#" }.count
            if headingLevel > 0,
               headingLevel <= 6,
               trimmed.dropFirst(headingLevel).first == " " {
                flushParagraph()
                let content = String(trimmed.dropFirst(headingLevel + 1))
                append(.heading(headingLevel), content)
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                let content = String(trimmed.dropFirst())
                    .trimmingCharacters(in: .whitespaces)
                append(.quote, content)
                continue
            }

            if let bulletContent = unorderedListContent(from: trimmed) {
                flushParagraph()
                append(.bullet, bulletContent)
                continue
            }

            if let numbered = numberedListContent(from: trimmed) {
                flushParagraph()
                append(.numbered(numbered.marker), numbered.content)
                continue
            }

            paragraphLines.append(line)
        }

        flushParagraph()
        if isInsideCodeBlock || !codeLines.isEmpty {
            append(.code, codeLines.joined(separator: "\n"))
        }

        while blocks.last?.kind == .spacer {
            blocks.removeLast()
        }

        return blocks
    }

    nonisolated private static func unorderedListContent(from line: String) -> String? {
        for prefix in ["- ", "* ", "+ "] where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count))
        }
        return nil
    }

    nonisolated private static func numberedListContent(
        from line: String
    ) -> (marker: String, content: String)? {
        guard let dot = line.firstIndex(of: "."), dot != line.startIndex else { return nil }
        let number = line[..<dot]
        guard number.allSatisfy(\.isNumber) else { return nil }

        let contentStart = line.index(after: dot)
        guard contentStart < line.endIndex, line[contentStart] == " " else { return nil }

        let content = line[line.index(after: contentStart)...]
        return ("\(number).", String(content))
    }
}
