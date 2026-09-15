import SwiftUI

/// Matches the real native slider used in macOS's Sound Control Center and
/// iOS Control Center: a thin track, a brighter fill up to the current
/// value, and a distinct round white knob riding on top at that position —
/// not a growing filled bar where the fill itself is the thumb (an earlier
/// version got this wrong). Prototyped as an HTML/CSS mockup first and
/// screenshotted for comparison against reference photos of the real
/// control, since the native app itself isn't screenshottable here.
///
/// Deliberately not using `.glassEffect()` here. Apple's guidance says the
/// *knob* should turn to glass during interaction, not the track, but two
/// separate attempts at combining a glassEffect element with plain sibling
/// shapes in this same ZStack produced real rendering/z-order artifacts
/// (the track visibly cut through the knob). Rather than risk a third blind
/// regression in a component that can't be visually verified without a
/// screenshot from the user, this sticks to plain materials that are
/// already confirmed correct.
struct PillSlider: View {
    @Binding var value: Float
    var height: CGFloat = 20

    @Environment(\.isEnabled) private var isEnabled

    private var trackHeight: CGFloat { height <= 14 ? 4 : 6 }
    private var knobDiameter: CGFloat { height <= 14 ? 12 : 18 }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let knobRadius = knobDiameter / 2
            let knobX = knobRadius + max(0, width - knobDiameter) * CGFloat(value)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.quaternary)
                    .frame(height: trackHeight)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: knobX, height: trackHeight)

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
