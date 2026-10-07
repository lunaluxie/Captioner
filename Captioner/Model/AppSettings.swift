import Foundation
import Observation

/// App-wide preferences, backed by UserDefaults. New videos start from these; each video in
/// the queue then keeps its own copy of the style, placement and controls.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var localeIdentifier: String {
        didSet { defaults.set(localeIdentifier, forKey: "localeIdentifier") }
    }
    var textOptions: TextOptions {
        didSet { store(textOptions, key: "textOptions") }
    }
    var style: CaptionStyle {
        didSet { store(style, key: "style") }
    }
    var placement: PlacementSettings {
        didSet { store(placement, key: "placement") }
    }
    var favoriteStyleIDs: Set<String> {
        didSet { defaults.set(Array(favoriteStyleIDs).sorted(), forKey: "favoriteStyleIDs") }
    }
    var exportCodec: ExportCodec {
        didSet { defaults.set(exportCodec.rawValue, forKey: "exportCodec") }
    }
    /// Security-scoped bookmark of the folder exports are written to.
    var exportFolderBookmark: Data? {
        didSet { defaults.set(exportFolderBookmark, forKey: "exportFolderBookmark") }
    }
    /// How long a caption stays up after its last word when nothing follows.
    var captionHold: Double {
        didSet { defaults.set(captionHold, forKey: "captionHold") }
    }
    var revealOutputInFinder: Bool {
        didSet { defaults.set(revealOutputInFinder, forKey: "revealOutputInFinder") }
    }

    private init() {
        localeIdentifier = defaults.string(forKey: "localeIdentifier") ?? Locale.current.identifier
        textOptions = Self.load(TextOptions.self, key: "textOptions", from: defaults) ?? .default
        style = Self.load(CaptionStyle.self, key: "style", from: defaults) ?? .default
        placement = Self.load(PlacementSettings.self, key: "placement", from: defaults) ?? .default
        favoriteStyleIDs = Set(defaults.stringArray(forKey: "favoriteStyleIDs") ?? [])
        exportCodec = ExportCodec(rawValue: defaults.string(forKey: "exportCodec") ?? "") ?? .h264
        exportFolderBookmark = defaults.data(forKey: "exportFolderBookmark")
        captionHold = defaults.object(forKey: "captionHold") as? Double ?? 1.0
        revealOutputInFinder = defaults.object(forKey: "revealOutputInFinder") as? Bool ?? true
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    /// The chosen export folder, or nil when none has been picked yet (or the bookmark went stale).
    var exportFolder: URL? {
        guard let bookmark = exportFolderBookmark else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            exportFolderBookmark = fresh
        }
        return url
    }

    func setExportFolder(_ url: URL) {
        exportFolderBookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    private func store<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
