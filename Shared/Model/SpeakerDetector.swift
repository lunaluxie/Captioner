import AVFoundation
import Foundation
import SpeakerDiarization

/// Whether a video's captions are colored by who is speaking, and how many voices to look for.
nonisolated enum SpeakerMode: Codable, Hashable, Sendable {
    case off
    /// Finds the number of voices itself, up to four.
    case automatic
    /// Exactly this many voices, 2…4.
    case count(Int)

    static let choices: [SpeakerMode] = [.off, .automatic, .count(2), .count(3), .count(4)]

    var title: String {
        switch self {
        case .off: "Off"
        case .automatic: "Detect automatically"
        case .count(let n): "\(n) speakers"
        }
    }

    var isOn: Bool { self != .off }

    /// How many voices the detector may return; nil when detection is off.
    var maxSpeakers: Int? {
        switch self {
        case .off: nil
        case .automatic: CaptionStyle.maxSpeakers
        case .count(let n): max(1, min(n, CaptionStyle.maxSpeakers))
        }
    }

    /// The exact number of voices asked for, or nil to decide from the audio.
    var fixedCount: Int? {
        if case .count(let n) = self { return max(1, min(n, CaptionStyle.maxSpeakers)) }
        return nil
    }
}

/// Works out who is speaking when, so captions can be colored by voice.
///
/// The audio is decoded to 16 kHz mono and handed to the speaker diarization pipeline in
/// `Packages/SpeakerDiarization` (FluidAudio's Core ML conversion of pyannote's community-1
/// models). Its turns are then laid over the transcript: each word takes the voice that covers
/// it, words in the gaps follow their neighbours, and voices are numbered in order of first
/// appearance. Automatic detection can miss a voice that only says a few words; asking for an
/// exact count fixes that, and any caption's speaker can be changed by hand.
nonisolated enum SpeakerDetector {
    enum Phase: Sendable {
        case downloading(Double)
        case preparing
        case listening(Double)
    }

    enum DetectionError: LocalizedError {
        case noWords

        var errorDescription: String? {
            switch self {
            case .noWords: "There are no words to assign to speakers yet."
            }
        }
    }

    /// Whether the speaker models still have to be downloaded (about 22 MB, once).
    static var needsModelDownload: Bool { !SpeakerDiarizer.modelsAreInstalled }

    /// One speaker number (1-based) per word in `words`, in the same order; nil for blanks.
    static func detect(url: URL, words: [TranscriptWord], mode: SpeakerMode,
                       progress: (@Sendable (Phase) -> Void)? = nil) async throws -> [Int?] {
        guard mode.isOn, let maxSpeakers = mode.maxSpeakers else { return words.map { _ in nil } }
        let spoken = words.filter { !$0.text.isEmpty }
        guard !spoken.isEmpty else { throw DetectionError.noWords }

        let asset = AVURLAsset(url: url)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: SpeakerDiarizer.sampleRate, channels: 1, interleaved: false) else {
            throw TranscriptionError.noAudioFormat
        }
        let reader = try await MediaAudioReader(asset: asset, targetFormat: format)
        let until = (spoken.map(\.end).max() ?? 0) + 1
        let samples = try await Task.detached(priority: .userInitiated) {
            try readSamples(reader, until: until)
        }.value
        try Task.checkCancellation()

        let turns = try await SpeakerDiarizer.diarize(samples: samples, numSpeakers: mode.fixedCount, maxSpeakers: maxSpeakers) { phase in
            switch phase {
            case .downloading(let fraction): progress?(.downloading(fraction))
            case .preparing: progress?(.preparing)
            case .listening(let fraction): progress?(.listening(fraction))
            }
        }
        try Task.checkCancellation()
        return assign(words: words, turns: turns, maxSpeakers: maxSpeakers)
    }

    /// Decodes the audio up to `until` seconds into one mono 16 kHz buffer.
    static func readSamples(_ reader: MediaAudioReader, until: TimeInterval) throws -> [Float] {
        var samples: [Float] = []
        samples.reserveCapacity(Int(until * SpeakerDiarizer.sampleRate))
        let limit = Int(until * SpeakerDiarizer.sampleRate)
        while let buffer = try reader.next() {
            try Task.checkCancellation()
            let count = Int(buffer.frameLength)
            guard count > 0, let data = buffer.floatChannelData?[0] else { continue }
            samples.append(contentsOf: UnsafeBufferPointer(start: data, count: count))
            if samples.count >= limit { break }
        }
        return samples
    }

    /// Lays the turns over the words: each word takes the turn that covers most of it, a word
    /// no turn covers takes the nearest turn within a beat, and anything still unknown follows
    /// the word before it when the two run together.
    static func assign(words: [TranscriptWord], turns: [SpeakerTurn], maxSpeakers: Int) -> [Int?] {
        let turns = turns.filter { $0.speaker >= 1 && $0.speaker <= maxSpeakers }.sorted { $0.start < $1.start }
        var labels: [Int?] = Array(repeating: nil, count: words.count)
        for (index, word) in words.enumerated() where !word.text.isEmpty {
            var best: Int?
            var bestOverlap: TimeInterval = 0
            var nearest: Int?
            var nearestGap = TimeInterval.greatestFiniteMagnitude
            for turn in turns {
                if turn.start > word.end + 0.75 { break }
                let overlap = min(turn.end, word.end) - max(turn.start, word.start)
                if overlap > bestOverlap {
                    bestOverlap = overlap
                    best = turn.speaker
                }
                let gap = max(turn.start - word.end, word.start - turn.end, 0)
                if gap < nearestGap {
                    nearestGap = gap
                    nearest = turn.speaker
                }
            }
            labels[index] = best ?? (nearestGap <= 0.75 ? nearest : nil)
        }
        // Fill the gaps from the neighbour the word runs on from.
        for index in words.indices where labels[index] == nil && !words[index].text.isEmpty {
            if index > 0, let previous = labels[index - 1], words[index].start - words[index - 1].end < 0.6 {
                labels[index] = previous
            } else if let next = (index + 1..<words.count).first(where: { labels[$0] != nil }),
                      words[next].start - words[index].end < 0.6 {
                labels[index] = labels[next]
            }
        }
        // A lone short word wedged between two of the same voice is that voice.
        for index in 1..<max(1, words.count - 1) where words[index].duration < 0.5 {
            if let before = labels[index - 1], before == labels[index + 1], labels[index] != before {
                labels[index] = before
            }
        }
        return labels
    }
}
