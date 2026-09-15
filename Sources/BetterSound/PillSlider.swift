import SwiftUI

/// Matches the real native slider used in macOS's Sound Control Center and
/// iOS Control Center: a thin full-width track with a distinct round white
/// knob riding on top of it — not a growing filled bar. (An earlier version
/// of this view used a filled-capsule design; verified against reference
/// screenshots of the actual native control that this was wrong — the fill
/// isn't the thumb, a separate circular knob is.) SwiftUI's stock `Slider`
/// doesn't render this way in a MenuBarExtra popover, which is why this is
/// a from-scratch replica instead.
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

    private var trackHeight: CGFloat { height <= 14 ? 4 : 6 }
    private var knobDiameter: CGFloat { height <= 14 ? 12 : 18 }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let knobRadius = knobDiameter / 2
            let knobX = knobRadius + max(0, width - knobDiameter) * CGFloat(value)

            ZStack(alignment: .leading) {
                Group {
                    if useGlass {
                        Capsule(style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular, in: .capsule)
                    } else {
                        Capsule(style: .continuous)
                            .fill(.quaternary)
                    }
                }
                .frame(height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .position(x: knobX, y: height / 2)
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
