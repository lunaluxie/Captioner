import Foundation
import NaturalLanguage

/// What a translated video remembers about its original captions, so it can go back.
nonisolated struct TranslationInfo: Hashable, Sendable {
    /// The target language's identifier ("es", "zh-Hans", "pt-BR").
    var targetIdentifier: String
    var originalWords: [TranscriptWord]
    var originalCaptions: [Caption]
}

/// Prepares captions for translation and fits translated text back onto the timeline.
///
/// Captions are fragments ("Do you have a" / "lot of alarms"), which translate badly on their
/// own, so whole sentences go to the translator. The translated sentence is then shared out over
/// the captions it came from in proportion to their text, so pauses and pacing survive, and each
/// caption's words share its span by length as they do after an edit.
nonisolated enum CaptionTranslator {
    /// Runs of caption indices that make up one sentence: cut after sentence-ending punctuation
    /// and at pauses.
    static func sentenceGroups(_ captions: [Caption], pauseBreak: TimeInterval = 1.0) -> [[Int]] {
        var groups: [[Int]] = []
        var current: [Int] = []
        for (index, caption) in captions.enumerated() {
            if caption.isBlank {
                // Blank lines are their own group and are never sent for translation.
                if !current.isEmpty { groups.append(current); current = [] }
                groups.append([index])
                continue
            }
            if let previousIndex = current.last {
                let previous = captions[previousIndex]
                if caption.start - previous.end >= pauseBreak || CaptionBuilder.endsSentence(previous.words.last?.text ?? "") {
                    groups.append(current)
                    current = []
                }
            }
            current.append(index)
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    static func sentenceText(_ captions: [Caption], group: [Int]) -> String {
        group.map { captions[$0].text }.joined(separator: " ")
    }

    /// Timed words for a translated sentence, laid over the captions in `group`.
    static func words(for captions: [Caption], group: [Int], translation: String) -> [TranscriptWord] {
        let tokens = tokenize(translation)
        guard !group.isEmpty else { return [] }
        guard !tokens.isEmpty else { return group.flatMap { captions[$0].words } }
        let lengths = group.map { max(1, captions[$0].text.count) }
        let total = Double(lengths.reduce(0, +))
        let ideal = lengths.map { Double(tokens.count) * Double($0) / total }
        // Largest-remainder rounding keeps the total exact and favors the captions that lost the most.
        var counts = ideal.map { Int($0.rounded(.down)) }
        var remainder = tokens.count - counts.reduce(0, +)
        for index in ideal.indices.sorted(by: { ideal[$0] - ideal[$0].rounded(.down) > ideal[$1] - ideal[$1].rounded(.down) }) where remainder > 0 {
            counts[index] += 1
            remainder -= 1
        }
        var result: [TranscriptWord] = []
        var offset = 0
        for (slot, index) in group.enumerated() {
            let count = counts[slot]
            guard count > 0 else { continue }
            let text = tokens[offset..<(offset + count)].joined(separator: " ")
            offset += count
            result += captions[index].replacingText(text).words
        }
        return result
    }

    /// Splits translated text into words. Spaced scripts split on whitespace; Chinese, Japanese
    /// and Thai go through the system tokenizer, with punctuation kept on the word before it.
    static func tokenize(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if trimmed.contains(where: { $0.isWhitespace }) {
            return trimmed.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init)
        }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = trimmed
        var tokens: [String] = []
        var lastEnd = trimmed.startIndex
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            if range.lowerBound > lastEnd, !tokens.isEmpty {
                tokens[tokens.count - 1] += String(trimmed[lastEnd..<range.lowerBound])
            }
            tokens.append(String(trimmed[range]))
            lastEnd = range.upperBound
            return true
        }
        if lastEnd < trimmed.endIndex, !tokens.isEmpty {
            tokens[tokens.count - 1] += String(trimmed[lastEnd...])
        }
        return tokens.isEmpty ? [trimmed] : tokens
    }
}
