import SwiftUI

/// The watermark's opacity, size, position and margin. The image itself is chosen by the
/// platform's own picker around these.
struct WatermarkControls: View {
    @Binding var settings: WatermarkSettings

    var body: some View {
        Group {
            LabeledContent("Opacity") {
                HStack {
                    Slider(value: $settings.opacity, in: 0.05...1)
                    percent(settings.opacity)
                }
            }
            LabeledContent("Size") {
                HStack {
                    Slider(value: $settings.width, in: 0.04...0.6)
                    percent(settings.width)
                }
            }
            LabeledContent("Margin") {
                HStack {
                    Slider(value: $settings.margin, in: 0...0.15)
                    percent(settings.margin)
                }
            }
            LabeledContent("Position") {
                WatermarkPositionGrid(position: $settings.position)
            }
        }
        .disabled(!settings.isEnabled)
    }

    private func percent(_ value: Double) -> some View {
        Text("\(Int((value * 100).rounded()))%")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 40, alignment: .trailing)
    }
}

/// Nine spots in the frame, as a small grid of buttons.
struct WatermarkPositionGrid: View {
    @Binding var position: WatermarkPosition

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(WatermarkPosition.grid, id: \.first!.rawValue) { row in
                GridRow {
                    ForEach(row, id: \.self) { spot in
                        Button {
                            position = spot
                        } label: {
                            Image(systemName: spot.symbolName)
                                .font(.system(size: 15))
                                .frame(width: 30, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .tint(spot == position ? Color.accentColor : nil)
                        .help(spot.title)
                        .accessibilityLabel(spot.title)
                    }
                }
            }
        }
    }
}

/// The chosen image on a checkerboard, so transparency shows.
struct WatermarkThumbnail: View {
    let fileName: String?

    var body: some View {
        ZStack {
            Checkerboard()
            if let fileName, let image = WatermarkLibrary.image(named: fileName) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.quaternary))
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 6
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.55)))
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = row % 2 == 0 ? 0 : cell
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: .color(Color(white: 0.7)))
                    x += cell * 2
                }
                y += cell
                row += 1
            }
        }
    }
}

/// A colored dot naming a caption's speaker, with a menu to change it.
struct SpeakerChip: View {
    let caption: Caption
    let style: CaptionStyle
    let onChange: (Int?) -> Void

    var body: some View {
        Menu {
            Button {
                onChange(nil)
            } label: {
                if caption.speaker == nil { Label("No speaker", systemImage: "checkmark") } else { Text("No speaker") }
            }
            ForEach(1...CaptionStyle.maxSpeakers, id: \.self) { number in
                Button {
                    onChange(number)
                } label: {
                    if caption.speaker == number { Label("Speaker \(number)", systemImage: "checkmark") } else { Text("Speaker \(number)") }
                }
            }
        } label: {
            SpeakerDot(speaker: caption.speaker, style: style)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(caption.speaker.map { "Speaker \($0)" } ?? "No speaker")
        .accessibilityLabel(caption.speaker.map { "Speaker \($0)" } ?? "No speaker")
    }
}

struct SpeakerDot: View {
    let speaker: Int?
    let style: CaptionStyle

    var body: some View {
        ZStack {
            if let speaker {
                Circle().fill(Color(cgColor: style.textColor(forSpeaker: speaker).cgColor))
                Text("\(speaker)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black.opacity(0.75))
            } else {
                Circle().strokeBorder(.secondary, lineWidth: 1.2)
                Text("–")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 18, height: 18)
        .contentShape(Circle())
    }
}
