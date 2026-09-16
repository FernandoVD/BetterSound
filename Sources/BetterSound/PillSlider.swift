import SwiftUI

/// Matches the real native slider used in macOS's Sound Control Center and
/// iOS Control Center: a thin track, a brighter fill up to the current
/// value, and a distinct round knob riding on top at that position — not a
/// growing filled bar where the fill itself is the thumb (an earlier
/// version got this wrong). Prototyped as an HTML/CSS mockup first and
/// screenshotted for comparison against reference photos of the real
/// control, since the native app itself isn't screenshottable here.
///
/// The knob is a plain white circle at all times — not conditionally
/// swapped for a Liquid Glass version while dragging. That was tried twice:
/// a permanently-glass track caused a real compositing bug (a visible line
/// cut through the knob), and a `.glassEffect()` applied only while
/// dragging caused a *different* bug — swapping between two distinct view
/// trees triggers SwiftUI's insertion/removal transition. Three bugs from
/// the same effect in the same component was the signal to drop it.
struct PillSlider: View {
    @Binding var value: Float
    var height: CGFloat = 20

    @Environment(\.isEnabled) private var isEnabled
    @State private var isDragging = false
    // Where the gesture started, so a tap can be told apart from a real
    // drag. A plain tap still delivers onChanged (DragGesture's
    // minimumDistance is 0, to support tap-to-jump), but it should never
    // enter the "dragging" visual state at all — that state's dim/undim is
    // itself animated, and a tap presses it in then releases it out almost
    // instantly, two competing animations racing on top of each other,
    // which reads as a jitter/flash even though there's no bug in the
    // animation logic itself (verified: entering and leaving the dragging
    // state cleanly did not, on their own, cause any layout or
    // view-identity issue — only firing back-to-back on a tap did). Only a
    // sustained movement past a small threshold should ever trigger it.
    @State private var dragStartX: CGFloat?
    // Frozen for the duration of one gesture. Found via frame-by-frame
    // video analysis: the displayed value can snap to a position that
    // doesn't match the cursor at all, specifically on the Sound/Input
    // sliders (never seen on per-app ones, which are unaffected). Sound
    // and Input both live in AudioEngine, whose refresh() reassigns the
    // devices/inputDevices arrays — new array instances, so @Published
    // re-renders — any time CoreAudio's system-wide device-list
    // notification fires, which can happen for reasons that have nothing
    // to do with this slider at all (e.g. a per-app ProcessTapEngine
    // creating its own aggregate device elsewhere). If that re-render's
    // layout pass recomputes this slider's GeometryReader width mid-drag,
    // fraction = cursorX / width goes wrong for that one frame even though
    // the cursor hasn't moved. Freezing the width for the gesture's
    // duration makes an in-progress drag immune to that, regardless of
    // what's re-rendering elsewhere.
    @State private var gestureWidth: CGFloat?

    private var trackHeight: CGFloat { height <= 14 ? 4 : 6 }
    private var knobDiameter: CGFloat { height <= 14 ? 12 : 18 }
    private let dragThreshold: CGFloat = 3

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

                Circle()
                    .fill(Color.white)
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
                        if dragStartX == nil {
                            dragStartX = drag.location.x
                        }
                        if gestureWidth == nil {
                            gestureWidth = width
                        }
                        let moved = abs(drag.location.x - (dragStartX ?? drag.location.x))
                        if !isDragging, moved > dragThreshold {
                            withAnimation(.easeOut(duration: 0.15)) {
                                isDragging = true
                            }
                        }
                        // Never inside withAnimation — position must always
                        // be instant, however far the value jumps.
                        update(with: drag.location.x, width: gestureWidth ?? width)
                    }
                    .onEnded { _ in
                        dragStartX = nil
                        gestureWidth = nil
                        if isDragging {
                            withAnimation(.easeOut(duration: 0.15)) {
                                isDragging = false
                            }
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
