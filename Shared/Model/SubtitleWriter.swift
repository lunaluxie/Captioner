import Foundation
import UniformTypeIdentifiers

/// Writes the captions out as SubRip, WebVTT or plain text, with the transcription controls
/// applied, so the file says what the video shows. Blank lines are left out of subtitle files
/// and become paragraph breaks in the text.
nonisolated enum SubtitleWriter {
    enum Format: String, CaseIterable, Identifiable, Sendable {
        case srt, vtt, txt

        var id: String { rawValue }
        var fileExtension: String { rawValue }
        var title: String {
            switch self {
            case .srt: "SubRip (.srt)"
            case .vtt: "WebVTT (.vtt)"
            case .txt: "Text (.txt)"
            }
        }
        var type: UTType {
            switch self {
            case .srt: UTType(filenameExtension: "srt") ?? .plainText
            case .vtt: UTType(filenameExtension: "vtt") ?? .plainText
            case .txt: .plainText
            }
        }
    }

    static func text(for captions: [Caption], format: Format, options: TextOptions) -> String {
        let lines = captions.map { caption in
            (caption: caption, text: caption.isBlank ? "" : TextTransforms.apply(options, to: caption.text).trimmingCharacters(in: .whitespaces))
        }
        switch format {
        case .srt:
            var cues: [String] = []
            for line in lines where !line.text.isEmpty {
                cues.append("\(cues.count + 1)\n\(TimeFormat.srt(line.caption.start)) --> \(TimeFormat.srt(line.caption.end))\n\(line.text)")
            }
            return cues.joined(separator: "\n\n") + "\n"
        case .vtt:
            let cues = lines.filter { !$0.text.isEmpty }.map { line in
                "\(TimeFormat.vtt(line.caption.start)) --> \(TimeFormat.vtt(line.caption.end))\n\(line.text)"
            }
            return "WEBVTT\n\n" + cues.joined(separator: "\n\n") + "\n"
        case .txt:
            var paragraphs: [String] = []
            var current: [String] = []
            for line in lines {
                if line.text.isEmpty {
                    if !current.isEmpty { paragraphs.append(current.joined(separator: " ")); current = [] }
                } else {
                    current.append(line.text)
                }
            }
            if !current.isEmpty { paragraphs.append(current.joined(separator: " ")) }
            return paragraphs.joined(separator: "\n\n") + "\n"
        }
    }

    /// Writes the file, replacing one that is already there.
    static func write(_ captions: [Caption], format: Format, options: TextOptions, to url: URL) throws {
        let content = text(for: captions, format: format, options: options)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
