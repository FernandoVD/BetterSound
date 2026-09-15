import SwiftUI

/// Matches Apple's own Control Center volume slider: a full-width translucent
/// capsule track with a solid capsule "fill" growing from the left — the fill
/// itself is the thumb, draggable anywhere along its length, and tappable to
/// jump straight to a position. SwiftUI's stock `Slider` doesn't render this
/// way on macOS, which is why it looked "not native" — this is a from-scratch
/// replica of the real control instead of an approximation of one.
///
/// `useGlass` defaults to true, but per Apple's Liquid Glass guidance
/// ("limit these effects to the most important functional elements... avoid
/// overusing Liquid Glass... in multiple custom controls"), only the
/// primary sliders (master Sound, Input) should use it — pass `false` for
/// secondary/repeated controls like a per-app row, of which there can be many.
struct PillSlider: View {
    @Binding var value: Float
    var height: CGFloat = 20
    var useGlass: Bool = true

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fillWidth = max(height, width * CGFloat(value))

            ZStack(alignment: .leading) {
                if useGlass {
                    Capsule(style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: .capsule)
                } else {
                    Capsule(style: .continuous)
                        .fill(.quaternary)
                }

                Capsule(style: .continuous)
                    .fill(.primary.opacity(0.85))
                    .frame(width: fillWidth)
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(
                // .disabled() alone doesn't stop a custom-drawn view's own
                // gesture — this view has to opt out of it itself.
                isEnabled ? DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        update(with: drag.location.x, width: width)
                    } : nil
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
