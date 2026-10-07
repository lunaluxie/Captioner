import Foundation
import Observation

nonisolated enum ExportLocation: String, Codable, CaseIterable, Sendable {
    case nextToOriginal, folder

    var title: String {
        switch self {
        case .nextToOriginal: "Next to the original"
        case .folder: "A folder you choose"
        }
    }
}

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
    /// Styles the user bookmarked from the inspector; ids start with "saved-".
    var savedStyles: [CaptionStyle] {
        didSet { store(savedStyles, key: "savedStyles") }
    }
    /// The style every new video starts with. A built-in preset until the user picks one.
    var defaultStyle: CaptionStyle {
        didSet { store(defaultStyle, key: "defaultStyle") }
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
    var exportLocation: ExportLocation {
        didSet { defaults.set(exportLocation.rawValue, forKey: "exportLocation") }
    }
    /// Security-scoped bookmark of the folder exports are written to when `exportLocation` is `.folder`.
    var exportFolderBookmark: Data? {
        didSet { defaults.set(exportFolderBookmark, forKey: "exportFolderBookmark") }
    }
    /// Folders the user allowed Captioner to write into for "next to the original", by path.
    var folderGrants: [String: Data] {
        didSet { defaults.set(folderGrants, forKey: "folderGrants") }
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
        savedStyles = Self.load([CaptionStyle].self, key: "savedStyles", from: defaults) ?? []
        defaultStyle = Self.load(CaptionStyle.self, key: "defaultStyle", from: defaults) ?? .default
        placement = Self.load(PlacementSettings.self, key: "placement", from: defaults) ?? .default
        favoriteStyleIDs = Set(defaults.stringArray(forKey: "favoriteStyleIDs") ?? [])
        exportCodec = ExportCodec(rawValue: defaults.string(forKey: "exportCodec") ?? "") ?? .h264
        exportLocation = ExportLocation(rawValue: defaults.string(forKey: "exportLocation") ?? "") ?? .nextToOriginal
        exportFolderBookmark = defaults.data(forKey: "exportFolderBookmark")
        folderGrants = defaults.dictionary(forKey: "folderGrants") as? [String: Data] ?? [:]
        captionHold = defaults.object(forKey: "captionHold") as? Double ?? 1.0
        revealOutputInFinder = defaults.object(forKey: "revealOutputInFinder") as? Bool ?? true
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    // MARK: - Saved and default styles

    static let savedStylePrefix = "saved-"

    /// The preset or saved style a style was derived from, to tell whether it has been edited.
    func baseStyle(for id: String) -> CaptionStyle? {
        savedStyles.first { $0.id == id } ?? CaptionStyle.preset(id: id)
    }

    func isSavedStyle(_ id: String) -> Bool {
        savedStyles.contains { $0.id == id }
    }

    /// Whether `style` has been changed since it was picked or saved.
    func isEdited(_ style: CaptionStyle) -> Bool {
        guard let base = baseStyle(for: style.id) else { return true }
        return base != style
    }

    func isDefault(_ style: CaptionStyle) -> Bool {
        style == defaultStyle
    }

    /// Keeps a copy of `style` under `name` and returns it (with its new id) so the caller can adopt it.
    @discardableResult
    func saveStyle(_ style: CaptionStyle, name: String) -> CaptionStyle {
        var saved = style
        saved.id = Self.savedStylePrefix + UUID().uuidString
        saved.name = name
        savedStyles.append(saved)
        return saved
    }

    /// Overwrites the saved style with `style`'s id. If that style is the default, the default follows.
    func updateSavedStyle(_ style: CaptionStyle) {
        guard let index = savedStyles.firstIndex(where: { $0.id == style.id }) else { return }
        var updated = style
        updated.name = savedStyles[index].name
        savedStyles[index] = updated
        if defaultStyle.id == style.id { defaultStyle = updated }
    }

    func renameSavedStyle(id: String, to name: String) {
        guard let index = savedStyles.firstIndex(where: { $0.id == id }) else { return }
        savedStyles[index].name = name
        if defaultStyle.id == id { defaultStyle.name = name }
    }

    func deleteSavedStyle(id: String) {
        savedStyles.removeAll { $0.id == id }
        if defaultStyle.id == id { defaultStyle = .default }
    }

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

    /// Remembers that the user allowed writing into `folder`.
    func grantFolder(_ folder: URL) {
        if let data = try? folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            folderGrants[folder.standardizedFileURL.path] = data
        }
    }

    /// A folder the user already allowed that contains `url`, resolved with its security scope.
    func grantedFolder(containing url: URL) -> URL? {
        let target = url.standardizedFileURL.path
        for (path, data) in folderGrants.sorted(by: { $0.key.count > $1.key.count }) where target.hasPrefix(path + "/") {
            var stale = false
            if let folder = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
                if stale { grantFolder(folder) }
                return folder
            }
        }
        return nil
    }

    func forgetFolderGrants() {
        folderGrants = [:]
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
