import SwiftUI

/// A scrubber drawn in SwiftUI. Reports the time under the pointer while dragging and once more
/// with `ended` when the drag finishes.
struct ScrubberView: View {
    let duration: TimeInterval
    let time: TimeInterval
    let onScrub: (TimeInterval, Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fraction = duration > 0 ? min(1, max(0, time / duration)) : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.3))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(0, width * fraction), height: 4)
                Circle()
                    .fill(.white)
                    .shadow(radius: 1)
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, width * fraction - 6))
            }
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in onScrub(timeAt(value.location.x, width: width), false) }
                    .onEnded { value in onScrub(timeAt(value.location.x, width: width), true) }
            )
        }
        .frame(height: 20)
    }

    private func timeAt(_ x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        return min(duration, max(0, Double(x / width) * duration))
    }
}
