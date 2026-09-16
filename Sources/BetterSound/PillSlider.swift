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
/// transparency, not a permanently-glass control.
struct PillSlider: View {
    @Binding var value: Float
    var height: CGFloat = 20

    @Environment(\.isEnabled) private var isEnabled
    // Plain @State, not @GestureState: this needs to be set/cleared inside
    // explicit withAnimation blocks below, which @GestureState's automatic
    // (and not fully controllable) reset-on-gesture-end animation doesn't
    // allow. A blanket `.animation(_:value:)` modifier on the view tree was
    // tried first and didn't work — it implicitly animates *any* state
    // change that happens in the same update, not just the one it names, so
    // a tap (which still toggles this true→false almost instantly even
    // with zero drag distance) was sweeping the knob's position into the
    // same animated transition, clipping/overlapping on a large jump.
    // Explicit withAnimation blocks around only the drag-state mutations,
    // with the position (`value`) mutation always outside of one, is the
    // only way to guarantee position changes are never animated.
    @State private var isDragging = false

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
            .gesture(
                // .disabled() alone doesn't stop a custom-drawn view's own
                // gesture — this view has to opt out of it itself.
                isEnabled ? DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            withAnimation(.easeOut(duration: 0.15)) {
                                isDragging = true
                            }
                        }
                        // Never inside withAnimation — position must always
                        // be instant, however far the value jumps.
                        update(with: drag.location.x, width: width)
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            isDragging = false
                        }
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
