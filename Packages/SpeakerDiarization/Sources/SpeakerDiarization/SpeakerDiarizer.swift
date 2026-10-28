import FluidAudio
import Foundation

/// One stretch of speech by one voice. Voices are numbered from 1 in order of first appearance.
public struct SpeakerTurn: Sendable, Hashable {
    public let speaker: Int
    public let start: TimeInterval
    public let end: TimeInterval

    public init(speaker: Int, start: TimeInterval, end: TimeInterval) {
        self.speaker = speaker
        self.start = start
        self.end = end
    }
}

/// Who spoke when, from FluidAudio's offline pipeline: pyannote's community-1 segmentation and
/// embedding models (Core ML conversions by Fluid Inference) with VBx clustering. The models
/// (about 22 MB) download from Hugging Face the first time and are kept in Application Support.
public enum SpeakerDiarizer {
    /// The sample rate the models expect: mono Float32 at 16 kHz.
    public static let sampleRate: Double = 16_000

    public enum Phase: Sendable {
        /// Fetching the models, 0…1.
        case downloading(Double)
        /// Compiling or loading the models.
        case preparing
        /// Working through the audio, 0…1.
        case listening(Double)
    }

    /// Whether the models are already on this device, so no download is needed.
    public static var modelsAreInstalled: Bool {
        let directory = OfflineDiarizerModels.defaultModelsDirectory()
            .appendingPathComponent(Repo.diarizer.folderName, isDirectory: true)
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent(ModelNames.OfflineDiarizer.segmentationPath).path)
            && FileManager.default.fileExists(atPath: directory.appendingPathComponent(ModelNames.OfflineDiarizer.embeddingPath).path)
    }

    /// Diarizes `samples` (mono, 16 kHz). `numSpeakers` forces an exact count; otherwise the
    /// pipeline decides, up to `maxSpeakers`.
    public static func diarize(samples: [Float], numSpeakers: Int?, maxSpeakers: Int,
                               progress: @escaping @Sendable (Phase) -> Void) async throws -> [SpeakerTurn] {
        var config = OfflineDiarizerConfig.default
        if let numSpeakers {
            config.clustering.numSpeakers = numSpeakers
        } else {
            config.clustering.maxSpeakers = maxSpeakers
        }
        progress(.preparing)
        let models = try await OfflineDiarizerModels.load { update in
            switch update.phase {
            case .downloading: progress(.downloading(update.fractionCompleted))
            default: progress(.preparing)
            }
        }
        let manager = OfflineDiarizerManager(config: config)
        manager.initialize(models: models)
        progress(.listening(0))
        let result = try await manager.process(audio: samples) { done, total in
            progress(.listening(total > 0 ? Double(done) / Double(total) : 0))
        }
        var numbers: [String: Int] = [:]
        var turns: [SpeakerTurn] = []
        for segment in result.segments.sorted(by: { $0.startTimeSeconds < $1.startTimeSeconds }) {
            let number: Int
            if let known = numbers[segment.speakerId] {
                number = known
            } else {
                number = numbers.count + 1
                numbers[segment.speakerId] = number
            }
            turns.append(SpeakerTurn(speaker: number, start: TimeInterval(segment.startTimeSeconds), end: TimeInterval(segment.endTimeSeconds)))
        }
        return turns
    }
}
