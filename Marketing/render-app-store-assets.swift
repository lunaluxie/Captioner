import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// App Store product page header (3840x1646) and search results (3840x2560) artwork for
// Captioner and Leveler, in the house style set by Kan Do and Stash: the app's own gradient,
// one bold headline, an iPhone and an iPad in Apple's bezels running off the bottom edge.
// The Canvas and bezel code is Kan Do's (Marketing/render-app-store-assets.swift).
// Usage: swift Marketing/render-app-store-assets.swift

// MARK: - Canvas helpers (top-left coordinates, opaque RGB output)

final class Canvas {
    let w: Int, h: Int
    let ctx: CGContext
    init(_ w: Int, _ h: Int) {
        self.w = w; self.h = h
        ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.interpolationQuality = .high
    }
    /// Convert a top-left rect into CoreGraphics coordinates.
    func cg(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: CGFloat(h) - r.maxY, width: r.width, height: r.height) }

    func fillGradient(_ c1: NSColor, _ c2: NSColor, from p1: CGPoint, to p2: CGPoint) {
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [c1.cgColor, c2.cgColor] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: cg(CGRect(origin: p1, size: .zero)).origin,
                               end: cg(CGRect(origin: p2, size: .zero)).origin, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    func draw(_ image: CGImage, in r: CGRect, radius: CGFloat = 0, shadow: Bool = false) {
        ctx.saveGState()
        if shadow {
            ctx.setShadow(offset: CGSize(width: 0, height: -40), blur: 110, color: NSColor.black.withAlphaComponent(0.38).cgColor)
            // Shadow needs an opaque fill shaped like the image.
            ctx.addPath(CGPath(roundedRect: cg(r), cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            ctx.restoreGState(); ctx.saveGState()
        }
        if radius > 0 {
            ctx.addPath(CGPath(roundedRect: cg(r), cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.clip()
        }
        ctx.draw(image, in: cg(r))
        ctx.restoreGState()
    }

    func fillRounded(_ r: CGRect, radius: CGFloat, color: NSColor, shadow: Bool = false) {
        ctx.saveGState()
        if shadow { ctx.setShadow(offset: CGSize(width: 0, height: -40), blur: 110, color: NSColor.black.withAlphaComponent(0.38).cgColor) }
        ctx.addPath(CGPath(roundedRect: cg(r), cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    /// A screenshot inside a thin dark bezel with rounded corners. `topPad`
    /// adds screen above the capture (the capture's own top row, stretched)
    /// so the status bar isn't jammed against the bezel.
    func device(_ image: CGImage, screen r: CGRect, bezel: CGFloat, radius: CGFloat, topPad: CGFloat = 0) {
        let full = CGRect(x: r.minX, y: r.minY - topPad, width: r.width, height: r.height + topPad)
        let outer = full.insetBy(dx: -bezel, dy: -bezel)
        fillRounded(outer, radius: radius + bezel, color: NSColor(white: 0.08, alpha: 1), shadow: true)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: cg(full), cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.clip()
        if topPad > 0, let row = image.cropping(to: CGRect(x: 0, y: 0, width: image.width, height: 1)) {
            ctx.saveGState(); ctx.interpolationQuality = .none
            ctx.draw(row, in: cg(CGRect(x: r.minX, y: full.minY, width: r.width, height: topPad + 2)))
            ctx.restoreGState()
        }
        ctx.draw(image, in: cg(r))
        ctx.restoreGState()
    }


    /// iPhone 17 Pro, portrait, drawn to the device's proportions: a
    /// titanium rim, the black glass border, the Dynamic Island cut into the
    /// status bar, Action/volume buttons on the left, power and Camera
    /// Control on the right. `screen` is where the capture goes.
    func iPhoneFrame(_ image: CGImage, screen r: CGRect) {
        let w = r.width
        let bezel = w * 0.028            // black glass border
        let rim = w * 0.018              // metal edge
        let glass = r.insetBy(dx: -bezel, dy: -bezel)
        let body = glass.insetBy(dx: -rim, dy: -rim)
        let bodyRadius = w * 0.165
        // Buttons first, so they sit behind the body edge.
        let btn = NSColor(srgbRed: 0.30, green: 0.30, blue: 0.32, alpha: 1)
        let out = w * 0.009
        func button(_ x: CGFloat, _ y: CGFloat, _ h: CGFloat) {
            fillRounded(CGRect(x: x, y: body.minY + y, width: out * 1.6, height: h), radius: out * 0.5, color: btn)
        }
        button(body.minX - out, body.height * 0.195, body.height * 0.040)      // Action
        button(body.minX - out, body.height * 0.262, body.height * 0.072)      // Volume up
        button(body.minX - out, body.height * 0.352, body.height * 0.072)      // Volume down
        button(body.maxX - out * 0.6, body.height * 0.29, body.height * 0.115) // Side button
        button(body.maxX - out * 0.6, body.height * 0.58, body.height * 0.058) // Camera Control
        // Body: brushed-metal gradient rim with a soft shadow.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -40), blur: 110, color: NSColor.black.withAlphaComponent(0.40).cgColor)
        ctx.addPath(CGPath(roundedRect: cg(body), cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil))
        ctx.setFillColor(NSColor(white: 0.20, alpha: 1).cgColor); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: cg(body), cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil)); ctx.clip()
        fillGradient(NSColor(white: 0.52, alpha: 1), NSColor(white: 0.26, alpha: 1), from: CGPoint(x: body.minX, y: body.minY), to: CGPoint(x: body.maxX, y: body.maxY))
        ctx.restoreGState()
        // Thin highlight line on the rim's inner edge.
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: cg(body.insetBy(dx: rim * 0.35, dy: rim * 0.35)), cornerWidth: bodyRadius - rim * 0.35, cornerHeight: bodyRadius - rim * 0.35, transform: nil))
        ctx.setStrokeColor(NSColor(white: 0.70, alpha: 0.55).cgColor); ctx.setLineWidth(w * 0.003); ctx.strokePath()
        ctx.restoreGState()
        // Glass border and screen.
        fillRounded(glass, radius: bodyRadius - rim, color: NSColor(white: 0.03, alpha: 1))
        draw(image, in: r, radius: bodyRadius - rim - bezel)
        // Dynamic Island: 126×37pt on a 393pt screen, 11pt from the top.
        let iw = w * 126 / 393, ih = w * 37 / 393
        let island = CGRect(x: r.midX - iw / 2, y: r.minY + w * 11 / 393, width: iw, height: ih)
        fillRounded(island, radius: ih / 2, color: NSColor(white: 0.02, alpha: 1))
        // Front camera, right end of the island.
        ctx.saveGState()
        ctx.setFillColor(NSColor(srgbRed: 0.10, green: 0.11, blue: 0.16, alpha: 1).cgColor)
        ctx.fillEllipse(in: cg(CGRect(x: island.maxX - ih * 0.85, y: island.minY + ih * 0.22, width: ih * 0.56, height: ih * 0.56)))
        ctx.restoreGState()
    }

    /// iPad Pro 13-inch, portrait: thin aluminum edge, even black border,
    /// front camera centered on the long right edge (landscape top).
    func iPadFrame(_ image: CGImage, screen r: CGRect) {
        let w = r.width
        let bezel = w * 0.038
        let rim = w * 0.009
        let glass = r.insetBy(dx: -bezel, dy: -bezel)
        let body = glass.insetBy(dx: -rim, dy: -rim)
        let bodyRadius = w * 0.062
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -40), blur: 110, color: NSColor.black.withAlphaComponent(0.40).cgColor)
        ctx.addPath(CGPath(roundedRect: cg(body), cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil))
        ctx.setFillColor(NSColor(white: 0.22, alpha: 1).cgColor); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: cg(body), cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil)); ctx.clip()
        fillGradient(NSColor(white: 0.60, alpha: 1), NSColor(white: 0.32, alpha: 1), from: CGPoint(x: body.minX, y: body.minY), to: CGPoint(x: body.maxX, y: body.maxY))
        ctx.restoreGState()
        fillRounded(glass, radius: bodyRadius - rim, color: NSColor(white: 0.03, alpha: 1))
        draw(image, in: r, radius: bodyRadius - rim - bezel * 0.5)
        ctx.saveGState()
        ctx.setFillColor(NSColor(srgbRed: 0.10, green: 0.11, blue: 0.16, alpha: 1).cgColor)
        let cam = bezel * 0.30
        ctx.fillEllipse(in: cg(CGRect(x: glass.maxX - bezel / 2 - cam / 2, y: glass.midY - cam / 2, width: cam, height: cam)))
        ctx.restoreGState()
    }


    /// Apple's official Product Bezel (developer.apple.com/design/resources,
    /// PNG with a transparent screen cutout) over a capture. `cutout` is the
    /// screen area in the bezel's own pixels; `rect` is where the whole
    /// bezel lands. The capture is drawn first, the bezel on top, so the
    /// Dynamic Island and corner masks come from Apple's artwork.
    func appleDevice(bezel: CGImage, capture: CGImage, cutout: CGRect, screenRadius: CGFloat, in rect: CGRect, bodyInset: CGFloat, bodyRadius: CGFloat) {
        let k = rect.width / CGFloat(bezel.width)
        let body = rect.insetBy(dx: bodyInset * k, dy: bodyInset * k)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -40), blur: 110, color: NSColor.black.withAlphaComponent(0.40).cgColor)
        ctx.addPath(CGPath(roundedRect: cg(body), cornerWidth: bodyRadius * k, cornerHeight: bodyRadius * k, transform: nil))
        ctx.setFillColor(NSColor(white: 0.1, alpha: 1).cgColor); ctx.fillPath()
        ctx.restoreGState()
        let screen = CGRect(x: rect.minX + cutout.minX * k, y: rect.minY + cutout.minY * k,
                            width: cutout.width * k, height: cutout.height * k)
        // The iPhone bezel's cutout is a plain rectangle; the display's
        // rounded corners come from clipping the capture (62pt on iPhone
        // 17 Pro). The iPad cutout is already rounded; clipping matches it.
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: cg(screen), cornerWidth: screenRadius * k, cornerHeight: screenRadius * k, transform: nil))
        ctx.clip()
        ctx.draw(capture, in: cg(screen))
        ctx.restoreGState()
        ctx.draw(bezel, in: cg(rect))
    }

    /// Stretch a 1px edge of `image` (as drawn in `drawn`) over `area`, so a
    /// marketing shot's own background continues seamlessly.
    func extendEdge(_ image: CGImage, drawn: CGRect, area: CGRect, edge: NSRectEdge) {
        let sx = CGFloat(image.width) / drawn.width, sy = CGFloat(image.height) / drawn.height
        let strip: CGRect
        switch edge {
        case .minX: strip = CGRect(x: 0, y: 0, width: 1, height: image.height)
        case .maxX: strip = CGRect(x: image.width - 1, y: 0, width: 1, height: image.height)
        case .minY: strip = CGRect(x: 0, y: 0, width: image.width, height: 1)          // top row (image coords are top-down)
        default:    strip = CGRect(x: 0, y: image.height - 1, width: image.width, height: 1)
        }
        _ = (sx, sy)
        guard let piece = image.cropping(to: strip) else { return }
        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.draw(piece, in: cg(area))
        ctx.restoreGState()
    }

    func text(_ s: String, font: NSFont, color: NSColor, at origin: CGPoint, align: NSTextAlignment = .left, maxWidth: CGFloat = 10_000, lineSpacing: CGFloat = 0) -> CGSize {
        let para = NSMutableParagraphStyle(); para.alignment = align; para.lineSpacing = lineSpacing
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
        let str = NSAttributedString(string: s, attributes: attrs)
        let size = str.boundingRect(with: CGSize(width: maxWidth, height: 5000), options: [.usesLineFragmentOrigin]).size
        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
        var x = origin.x
        if align == .center { x = origin.x - size.width / 2 }
        let rect = CGRect(x: x, y: origin.y, width: size.width, height: size.height)
        str.draw(with: cg(rect), options: [.usesLineFragmentOrigin])
        NSGraphicsContext.restoreGraphicsState()
        return size
    }

    func save(_ path: String) {
        let img = ctx.makeImage()!
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
        print("wrote \(path) \(img.width)x\(img.height) alpha=\(img.alphaInfo.rawValue)")
    }
}

func load(_ path: String) -> CGImage {
    guard let img = NSImage(contentsOfFile: path) else { fatalError("missing \(path)") }
    var rect = CGRect(origin: .zero, size: img.size)
    // Rasterize at native pixel size (SVGs rasterize at the requested size).
    if path.hasSuffix(".svg") {
        let size = 1024
        let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let ns = NSGraphicsContext(cgContext: c, flipped: false)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
        img.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()
        return c.makeImage()!
    }
    return img.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
}


/// Rotates a bezel 90° counter-clockwise: Apple ships the 13" iPad Pro bezel in landscape, and
/// in portrait its camera sits on the long edge, which is exactly what rotating gives.
func rotatedCCW(_ image: CGImage) -> CGImage {
    let w = image.height, h = image.width
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: CGFloat(h))
    c.rotate(by: -.pi / 2)
    c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return c.makeImage()!
}

let kd = "/Users/ssrobles/Movies/Apps/kan-do"
let apps = "/Users/ssrobles/Movies/Apps"
let scratch = "/private/tmp/claude-501/-Users-ssrobles-Movies-Apps-Captioner/990570f8-4f99-427b-8b99-732bbaa8e7b7/scratchpad"
let white = NSColor.white
func display(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont { NSFont.systemFont(ofSize: size, weight: weight) }

let bezelPhone = load("\(kd)/Marketing/Bezels/iphone17pro-silver-portrait.png")   // 1350x2760, screen at (72,69) 1206x2622
let phoneCut = CGRect(x: 72, y: 69, width: 1206, height: 2622)
let bezelPad13 = rotatedCCW(load("\(kd)/Marketing/Bezels/ipadpro13-silver-landscape.png")) // 2300x3000, screen at (118,124) 2064x2752
let pad13Cut = CGRect(x: 118, y: 124, width: 2064, height: 2752)

struct Brand {
    let name: String, folder: String, headline: String, searchHeadline: String
    let phone: CGImage, pad: CGImage, g1: NSColor, g2: NSColor
}

func render(_ b: Brand) {
    do { // Header 21:9: headline left, iPad behind on the right, iPhone in front, both off the bottom.
        let c = Canvas(3840, 1646)
        c.fillGradient(b.g1, b.g2, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 3840, y: 1646))
        c.ctx.saveGState()
        c.ctx.setFillColor(NSColor(white: 1, alpha: 0.06).cgColor)
        c.ctx.fillEllipse(in: c.cg(CGRect(x: 1500, y: -300, width: 2600, height: 2400)))
        c.ctx.restoreGState()
        _ = c.text(b.headline, font: display(150, .bold), color: white, at: CGPoint(x: 400, y: 640), maxWidth: 1300, lineSpacing: 4)
        let padW: CGFloat = 1500
        c.appleDevice(bezel: bezelPad13, capture: b.pad, cutout: pad13Cut, screenRadius: 54,
                      in: CGRect(x: 2300, y: 230, width: padW, height: padW * 3000 / 2300), bodyInset: 28, bodyRadius: 160)
        let phW: CGFloat = 840
        c.appleDevice(bezel: bezelPhone, capture: b.phone, cutout: phoneCut, screenRadius: 186,
                      in: CGRect(x: 1760, y: 380, width: phW, height: phW * 2760 / 1350), bodyInset: 16, bodyRadius: 215)
        c.save("\(apps)/\(b.folder)/Marketing/AppStore/\(b.name)-ProductPageHeader-3840x1646.png")
    }
    do { // Search results 3:2: centered headline, devices rising from the bottom.
        let W = 3840, H = 2560
        let c = Canvas(W, H)
        let w = CGFloat(W), h = CGFloat(H)
        c.fillGradient(b.g1, b.g2, from: CGPoint(x: 0, y: 0), to: CGPoint(x: w, y: h))
        c.ctx.saveGState()
        c.ctx.setFillColor(NSColor(white: 1, alpha: 0.06).cgColor)
        c.ctx.fillEllipse(in: c.cg(CGRect(x: w * 0.135, y: h * 0.35, width: w * 0.73, height: h * 1.02)))
        c.ctx.restoreGState()
        _ = c.text(b.searchHeadline, font: display(w * 0.0406, .bold), color: white, at: CGPoint(x: w / 2, y: h * 0.12), align: .center)
        let padW = w * 0.58
        c.appleDevice(bezel: bezelPad13, capture: b.pad, cutout: pad13Cut, screenRadius: 54,
                      in: CGRect(x: w * 0.33, y: h * 0.30, width: padW, height: padW * 3000 / 2300), bodyInset: 28, bodyRadius: 160)
        let phW = w * 0.30
        c.appleDevice(bezel: bezelPhone, capture: b.phone, cutout: phoneCut, screenRadius: 186,
                      in: CGRect(x: w * 0.10, y: h * 0.40, width: phW, height: phW * 2760 / 1350), bodyInset: 16, bodyRadius: 215)
        c.save("\(apps)/\(b.folder)/Marketing/AppStore/\(b.name)-SearchResults-3840x2560.png")
    }
}

// Captioner: the icon's magenta-to-violet.
render(Brand(name: "Captioner", folder: "Captioner",
             headline: "Captions that\nfollow every word.",
             searchHeadline: "Animated captions, made on your device",
             phone: load("\(scratch)/shots/ios_2_editor.png"),   // 1320x2868, scaled into the 1206x2622 cutout (same aspect)
             pad: load("\(scratch)/shots/ipad_1_editor.png"),    // 2064x2752
             g1: NSColor(srgbRed: 0.886, green: 0.231, blue: 0.788, alpha: 1),
             g2: NSColor(srgbRed: 0.290, green: 0.102, blue: 0.620, alpha: 1)))

// Leveler: the site's blue.
render(Brand(name: "Leveler", folder: "Leveler",
             headline: "Even audio,\nevery episode.",
             searchHeadline: "Auto-level your podcast and video audio",
             phone: load("\(scratch)/leveler/iphone-1-list.png"),  // 1206x2622, from the current App Store listing
             pad: load("\(scratch)/leveler/ipad-1-list.png"),      // 2064x2752
             g1: NSColor(srgbRed: 0.33, green: 0.56, blue: 1.0, alpha: 1),
             g2: NSColor(srgbRed: 0.09, green: 0.29, blue: 0.78, alpha: 1)))
