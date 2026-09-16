import SwiftUI

/// Matches the real native slider used in macOS's Sound Control Center and
/// iOS Control Center: a thin track, a brighter fill up to the current
/// value, and a distinct round knob riding on top at that position — not a
/// growing filled bar where the fill itself is the thumb (an earlier
/// version got this wrong). Prototyped as an HTML/CSS mockup first and
/// screenshotted for comparison against reference photos of the real
/// control, since the native app itself isn't screenshottable here.
///
/// The knob turns to Liquid Glass, and the track fades more translucent,
/// only *while actively dragging* — verified against a screenshot of the
/// real native slider mid-drag, which shows exactly this transient
/// transparency, not a permanently-glass control. This is also why glass
/// is safe here now: the earlier rendering bug came from a glass track
/// permanently coexisting with a plain knob in the same ZStack; this drives
/// glass from `@GestureState`, so only one shape is ever glass, and only
/// for the duration of the gesture.
struct PillSlider: View {
    @Binding var value: Float
    var height: CGFloat = 20

    @Environment(\.isEnabled) private var isEnabled
    @GestureState private var isDragging = false

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
                    .opacity(isDragging ? 0.6 : 1)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isDragging ? 0.55 : 0.85))
                    .frame(width: knobX, height: trackHeight)

                Group {
                    if isDragging {
                        Circle()
                            .fill(.clear)
                            .glassEffect(.regular, in: .circle)
                    } else {
                        Circle()
                            .fill(Color.white)
                    }
                }
                .frame(width: knobDiameter, height: knobDiameter)
                .shadow(color: .black.opacity(isDragging ? 0.15 : 0.35), radius: 2, y: 1)
                .position(x: knobX, y: height / 2)
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: isDragging)
            // A tap (not a drag) still briefly toggles isDragging true→false
            // almost instantly, which triggers the animation above — and
            // without this, that swept the knob/fill *position* into the
            // same animated transition too, visibly clipping/overlapping
            // when a tap jumped the value a long way. Position must always
            // be instant; only the glass/opacity effects above should ease.
            .animation(nil, value: value)
            .gesture(
                // .disabled() alone doesn't stop a custom-drawn view's own
                // gesture — this view has to opt out of it itself.
                isEnabled ? DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
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
