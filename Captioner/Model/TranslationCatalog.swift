import Foundation
import Observation
import Translation

/// The languages Apple's on-device translation can produce on this Mac, with display names,
/// loaded once.
@MainActor @Observable
final class TranslationCatalog {
    static let shared = TranslationCatalog()

    private(set) var languages: [Locale.Language] = []
    private(set) var isLoaded = false
    @ObservationIgnored private var loading: Task<Void, Never>?

    func load() {
        guard loading == nil else { return }
        loading = Task {
            let supported = await LanguageAvailability().supportedLanguages
            languages = supported.sorted { Self.name($0) < Self.name($1) }
            isLoaded = true
        }
    }

    /// Languages a video can be translated into: everything but the one it is spoken in.
    func targets(excluding source: Locale.Language) -> [Locale.Language] {
        languages.filter { language in
            guard language.languageCode == source.languageCode else { return true }
            // Same language, different script (Simplified vs Traditional Chinese) still counts as a translation.
            if let script = language.script, let sourceScript = source.script, script != sourceScript { return true }
            return false
        }
    }

    /// "Spanish (Spain)", "Chinese (Simplified)".
    nonisolated static func name(_ language: Locale.Language) -> String {
        let display = Locale.current
        var name = language.languageCode.flatMap { display.localizedString(forLanguageCode: $0.identifier) } ?? language.minimalIdentifier
        var qualifiers: [String] = []
        if let script = language.script?.identifier {
            if script == "Hans" { qualifiers.append("Simplified") } else if script == "Hant" { qualifiers.append("Traditional") }
        }
        // Only a region the identifier spells out ("pt-BR"); plain "pt" would otherwise read as Brazil too.
        let subtags = language.minimalIdentifier.split(separator: "-").dropFirst().map(String.init)
        if let region = subtags.first(where: { ($0.count == 2 && $0 == $0.uppercased()) || ($0.count == 3 && $0.allSatisfy(\.isNumber)) }),
           let regionName = display.localizedString(forRegionCode: region) {
            qualifiers.append(regionName)
        }
        if !qualifiers.isEmpty { name += " (" + qualifiers.joined(separator: ", ") + ")" }
        return name
    }
}
