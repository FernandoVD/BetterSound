import SwiftUI

/// Matches Apple's own Control Center volume slider: a full-width translucent
/// capsule track with a solid capsule "fill" growing from the left — the fill
/// itself is the thumb, draggable anywhere along its length, and tappable to
/// jump straight to a position. SwiftUI's stock `Slider` doesn't render this
/// way on macOS, which is why it looked "not native" — this is a from-scratch
/// replica of the real control instead of an approximation of one.
struct PillSlider: View {
    @Binding var value: Float
    var height: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fillWidth = max(height, width * CGFloat(value))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.quaternary)

                Capsule(style: .continuous)
                    .fill(.primary.opacity(0.85))
                    .frame(width: fillWidth)
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        update(with: drag.location.x, width: width)
                    }
            )
        }
        .frame(height: height)
    }

    private func update(with x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        let fraction = Float(max(0, min(1, x / width)))
        value = fraction
    }
}
