import Foundation

struct SRTInspection: Sendable {
    let cueCount: Int
    let invalidTimecodes: Int
    let overlaps: Int
    let emptyCues: Int

    var summary: String {
        if cueCount == 0 {
            return "没识别到字幕块，请检查 SRT 格式。"
        }
        if invalidTimecodes == 0 && overlaps == 0 && emptyCues == 0 {
            return "\(cueCount) 条字幕，时间轴正常，没有重叠或空字幕。"
        }
        return "\(cueCount) 条字幕 · 无效时间 \(invalidTimecodes) · 重叠 \(overlaps) · 空字幕 \(emptyCues)"
    }
}

enum SRTTools {
    private struct Cue {
        var index: Int
        var start: Int64
        var end: Int64
        var lines: [String]
    }

    static func inspect(_ source: String) -> SRTInspection {
        let cues = parse(source)
        var invalid = invalidTimecodeCount(source)
        var overlaps = 0
        var empty = 0
        var previousEnd: Int64?

        for cue in cues {
            if cue.end <= cue.start { invalid += 1 }
            if cue.lines.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                empty += 1
            }
            if let previousEnd, cue.start < previousEnd { overlaps += 1 }
            previousEnd = cue.end
        }

        return SRTInspection(
            cueCount: cues.count,
            invalidTimecodes: invalid,
            overlaps: overlaps,
            emptyCues: empty
        )
    }

    private static func invalidTimecodeCount(_ source: String) -> Int {
        let normalized = normalize(source)
        var invalid = 0

        for block in normalized.components(separatedBy: "\n\n") {
            guard let line = block.components(separatedBy: "\n").first(where: { $0.contains("-->") }) else {
                continue
            }
            let parts = line.components(separatedBy: "-->")
            if parts.count != 2 || milliseconds(parts[0]) == nil || milliseconds(parts[1]) == nil {
                invalid += 1
            }
        }
        return invalid
    }

    static func renumber(_ source: String) -> String {
        let normalized = normalize(source)
        var nextIndex = 1
        return normalized.components(separatedBy: "\n\n").map { block in
            var lines = block.components(separatedBy: "\n")
            guard lines.contains(where: { $0.contains("-->") }) else { return block }

            if let firstContent = lines.firstIndex(where: {
                !$0.trimmingCharacters(in: .whitespaces).isEmpty
            }), Int(lines[firstContent].trimmingCharacters(in: .whitespaces)) != nil {
                lines[firstContent] = "\(nextIndex)"
            } else if let timecodeIndex = lines.firstIndex(where: { $0.contains("-->") }) {
                lines.insert("\(nextIndex)", at: timecodeIndex)
            }
            nextIndex += 1
            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    static func shifted(_ source: String, milliseconds offset: Int64) -> String {
        normalize(source).components(separatedBy: "\n").map { line in
            guard line.contains("-->") else { return line }
            let parts = line.components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = milliseconds(parts[0]),
                  let end = milliseconds(parts[1]) else { return line }

            let shiftedStart = max(0, start + offset)
            let shiftedEnd = max(shiftedStart + 1, end + offset)
            return "\(timecode(shiftedStart)) --> \(timecode(shiftedEnd))"
        }
        .joined(separator: "\n")
    }

    private static func normalize(_ source: String) -> String {
        source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func parse(_ source: String) -> [Cue] {
        let normalized = normalize(source)
        let blocks = normalized.components(separatedBy: "\n\n")
        var cues: [Cue] = []

        for block in blocks {
            let lines = block
                .components(separatedBy: "\n")
                .drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
            guard lines.count >= 2 else { continue }

            let values = Array(lines)
            let index: Int
            let timecodeLineIndex: Int
            if let parsedIndex = Int(values[0].trimmingCharacters(in: .whitespaces)) {
                index = parsedIndex
                timecodeLineIndex = 1
            } else {
                index = cues.count + 1
                timecodeLineIndex = 0
            }

            guard values.indices.contains(timecodeLineIndex) else { continue }
            let parts = values[timecodeLineIndex].components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = milliseconds(parts[0]),
                  let end = milliseconds(parts[1]) else { continue }

            let textStart = timecodeLineIndex + 1
            let textLines = textStart < values.count ? Array(values[textStart...]) : []
            cues.append(Cue(index: index, start: start, end: end, lines: textLines))
        }
        return cues
    }

    private static func milliseconds(_ raw: String) -> Int64? {
        let clean = raw.trimmingCharacters(in: .whitespaces)
        let components = clean
            .replacingOccurrences(of: ".", with: ",")
            .split(whereSeparator: { $0 == ":" || $0 == "," })
        guard components.count == 4,
              let hours = Int64(components[0]),
              let minutes = Int64(components[1]),
              let seconds = Int64(components[2]),
              let milliseconds = Int64(components[3]),
              minutes < 60,
              seconds < 60,
              milliseconds < 1_000 else { return nil }
        return (((hours * 60) + minutes) * 60 + seconds) * 1_000 + milliseconds
    }

    private static func timecode(_ milliseconds: Int64) -> String {
        let safe = max(0, milliseconds)
        let hours = safe / 3_600_000
        let minutes = (safe % 3_600_000) / 60_000
        let seconds = (safe % 60_000) / 1_000
        let millis = safe % 1_000
        return String(format: "%02lld:%02lld:%02lld,%03lld", hours, minutes, seconds, millis)
    }
}
