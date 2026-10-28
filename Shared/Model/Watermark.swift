import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Where a watermark sits in the frame.
nonisolated enum WatermarkPosition: String, Codable, CaseIterable, Sendable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight

    var title: String {
        switch self {
        case .topLeft: "Top left"
        case .top: "Top"
        case .topRight: "Top right"
        case .left: "Left"
        case .center: "Center"
        case .right: "Right"
        case .bottomLeft: "Bottom left"
        case .bottom: "Bottom"
        case .bottomRight: "Bottom right"
        }
    }

    var symbolName: String {
        switch self {
        case .topLeft: "rectangle.inset.topleft.filled"
        case .top: "rectangle.topthird.inset.filled"
        case .topRight: "rectangle.inset.topright.filled"
        case .left: "rectangle.lefthalf.inset.filled"
        case .center: "rectangle.center.inset.filled"
        case .right: "rectangle.righthalf.inset.filled"
        case .bottomLeft: "rectangle.inset.bottomleft.filled"
        case .bottom: "rectangle.bottomthird.inset.filled"
        case .bottomRight: "rectangle.inset.bottomright.filled"
        }
    }

    /// 0 = left, 1 = center, 2 = right.
    var column: Int {
        switch self {
        case .topLeft, .left, .bottomLeft: 0
        case .top, .center, .bottom: 1
        case .topRight, .right, .bottomRight: 2
        }
    }

    /// 0 = top, 1 = middle, 2 = bottom.
    var row: Int {
        switch self {
        case .topLeft, .top, .topRight: 0
        case .left, .center, .right: 1
        case .bottomLeft, .bottom, .bottomRight: 2
        }
    }

    /// The grid as rows, top to bottom.
    static let grid: [[WatermarkPosition]] = [[.topLeft, .top, .topRight], [.left, .center, .right], [.bottomLeft, .bottom, .bottomRight]]
}

/// A picture (a network logo, a handle) drawn over every frame. Sizes are fractions of the
/// frame so the mark looks the same on a 1080p and a 4K export.
nonisolated struct WatermarkSettings: Codable, Hashable, Sendable {
    /// The image, by file name inside the watermark folder; nil for no watermark.
    var fileName: String?
    var opacity: Double = 0.85
    /// The mark's width as a fraction of the frame width.
    var width: Double = 0.18
    var position: WatermarkPosition = .topRight
    /// Distance from the edges as a fraction of the frame's shorter side.
    var margin: Double = 0.04

    static let `default` = WatermarkSettings()

    var isEnabled: Bool { fileName != nil }

    /// Where an image of `imageSize` lands in a frame of `size`, bottom-left origin.
    func frame(imageSize: CGSize, in size: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let w = max(1, size.width * width)
        let h = w * imageSize.height / imageSize.width
        let m = min(size.width, size.height) * margin
        let x: CGFloat = switch position.column {
        case 0: m
        case 1: (size.width - w) / 2
        default: size.width - w - m
        }
        let y: CGFloat = switch position.row {
        case 0: size.height - h - m
        case 1: (size.height - h) / 2
        default: m
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

/// Watermark images live in Application Support/Captioner/Watermarks, decoded once and shared
/// with the render thread.
nonisolated enum WatermarkLibrary {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appending(path: "Captioner/Watermarks", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static let supportedTypes: [UTType] = [.png, .jpeg, .heic, .tiff, .gif, .bmp, .webP]

    /// The largest edge an image is decoded at; logos never need more.
    static let maxPixelSize = 2048

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: CGImage] = [:]

    /// Copies an image file into the library and returns its file name.
    @discardableResult
    static func add(_ source: URL) throws -> String {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: source)
        return try add(data: data, fileExtension: source.pathExtension)
    }

    /// Stores image data (from the Photos picker, say) and returns its file name.
    @discardableResult
    static func add(data: Data, fileExtension: String = "") throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
              let image = decode(source) else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "Choose a PNG, JPEG or HEIC image. PNGs with transparency work best."])
        }
        var ext = fileExtension.lowercased()
        if ext.isEmpty, let type = CGImageSourceGetType(source) as String?, let utType = UTType(type), let preferred = utType.preferredFilenameExtension {
            ext = preferred
        }
        if ext.isEmpty { ext = "png" }
        let fileName = UUID().uuidString + "." + ext
        try data.write(to: directory.appending(path: fileName), options: .atomic)
        lock.withLock { cache[fileName] = image }
        return fileName
    }

    /// Deletes an image file that nothing refers to any more.
    static func remove(_ fileName: String) {
        try? FileManager.default.removeItem(at: directory.appending(path: fileName))
        lock.withLock { _ = cache.removeValue(forKey: fileName) }
    }

    /// The decoded image, upright, at most `maxPixelSize` on its longer edge. Safe from any thread.
    static func image(named fileName: String) -> CGImage? {
        if let cached = lock.withLock({ cache[fileName] }) { return cached }
        let url = directory.appending(path: fileName)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = decode(source) else { return nil }
        lock.withLock { cache[fileName] = image }
        return image
    }

    private static func decode(_ source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCache: false,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
