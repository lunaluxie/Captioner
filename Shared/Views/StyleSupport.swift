import CoreGraphics
import SwiftUI

/// A rendered preview of a style on a dark tile.
struct StyleSampleView: View {
    let style: CaptionStyle

    var body: some View {
        GeometryReader { geometry in
            if let image = StyleSampleRenderer.image(for: style, size: geometry.size) {
                Image(decorative: image, scale: StyleSampleRenderer.scale)
                    .resizable()
                    .interpolation(.high)
            }
        }
        .background(Color(red: 0.16, green: 0.165, blue: 0.18))
    }
}

/// Renders style samples for the gallery, cached by style.
enum StyleSampleRenderer {
    private struct Key: Hashable {
        let style: CaptionStyle
        let width: Int
        let height: Int
    }

    private static var cache: [Key: CGImage] = [:]
    static let scale: CGFloat = 2

    static func image(for style: CaptionStyle, size: CGSize) -> CGImage? {
        let pixels = CGSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
        let key = Key(style: style, width: Int(pixels.width), height: Int(pixels.height))
        if let cached = cache[key] { return cached }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        CaptionRenderer.drawSample(style, size: pixels, in: context)
        guard let image = context.makeImage() else { return nil }
        if cache.count > 200 { cache.removeAll() }
        cache[key] = image
        return image
    }
}

/// A small pill marking the style new videos start with.
struct DefaultBadge: View {
    var body: some View {
        Text("Default")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.18), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }
}
