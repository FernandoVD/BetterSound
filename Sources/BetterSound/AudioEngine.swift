import Combine
import CoreAudio
import Foundation

@MainActor
final class AudioEngine: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var defaultDeviceID: AudioDeviceID?
    @Published private(set) var masterVolume: Float = 0
    @Published private(set) var isMuted: Bool = false
    /// False for devices with no single volume level — e.g. a Multi-Output
    /// Device, which is really several physical devices at once. Each real
    /// device's volume is independent (verified directly against CoreAudio);
    /// this only covers the case where there's no one number to show at all.
    @Published private(set) var supportsMasterVolume: Bool = true

    @Published private(set) var inputDevices: [AudioDevice] = []
    @Published private(set) var defaultInputDeviceID: AudioDeviceID?
    @Published private(set) var inputVolume: Float = 0
    @Published private(set) var isInputMuted: Bool = false

    private let listenerQueue = DispatchQueue(label: "com.fernandovandet.volumemixer.listener")
    private var observedDeviceID: AudioDeviceID?
    private var observedInputDeviceID: AudioDeviceID?
    private var pendingVolumeWrite: DispatchWorkItem?
    private var pendingInputVolumeWrite: DispatchWorkItem?

    // The debounced CoreAudio write we do on every drag tick means the
    // volume this listener reads back can be several ticks stale relative
    // to what the user's cursor is doing *right now* — the write itself
    // only lands ~16ms after the tick that scheduled it, and the listener
    // echo for it arrives some further, unpredictable delay after that. If
    // the user is still actively dragging when that echo finally arrives,
    // it can overwrite the already-newer, already-correct value from a
    // *later* tick with this older one, which reads as the slider
    // snapping to a value the cursor is nowhere near. Every write we make
    // pushes this deadline forward; the listener is only trusted to apply
    // its value once we've been quiet for a bit, i.e. once a change is
    // actually likely to have come from somewhere else (keyboard keys,
    // another app) rather than being an echo of our own recent write.
    private var ignoreVolumeEchoUntil: Date = .distantPast
    private var ignoreInputVolumeEchoUntil: Date = .distantPast

    init() {
        refresh()
        CoreAudioController.addSystemListener(queue: listenerQueue) { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
    }

    var menuBarIcon: String {
        if isMuted { return "speaker.slash.fill" }
        switch masterVolume {
        case ..<0.01: return "speaker.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    func refresh() {
        devices = CoreAudioController.outputDeviceIDs().map(AudioDevice.load)
        let current = CoreAudioController.defaultOutputDeviceID()
        defaultDeviceID = current

        if let current, current != observedDeviceID {
            observedDeviceID = current
            CoreAudioController.addDeviceListener(current, queue: listenerQueue) { [weak self] in
                Task { @MainActor in self?.refreshCurrentDeviceState() }
            }
        }
        refreshCurrentDeviceState()

        inputDevices = CoreAudioController.inputDeviceIDs().map(AudioDevice.loadInput)
        let currentInput = CoreAudioController.defaultInputDeviceID()
        defaultInputDeviceID = currentInput

        if let currentInput, currentInput != observedInputDeviceID {
            observedInputDeviceID = currentInput
            CoreAudioController.addInputDeviceListener(currentInput, queue: listenerQueue) { [weak self] in
                Task { @MainActor in self?.refreshCurrentInputDeviceState() }
            }
        }
        refreshCurrentInputDeviceState()
    }

    private func refreshCurrentDeviceState() {
        guard let current = defaultDeviceID else { return }
        if let volume = CoreAudioController.volume(of: current) {
            supportsMasterVolume = true
            // @Published republishes on every assignment even when the new
            // value equals the old one, which forces a SwiftUI re-render
            // each time. This listener fires shortly after our own writes
            // (echoing back what we just set, to also catch changes made
            // elsewhere, like the keyboard volume keys) — without this
            // guard, that echo was re-publishing an unchanged value right
            // after our own instant update, and the resulting back-to-back
            // renders were the jitter reported on tap.
            if Date() > ignoreVolumeEchoUntil, abs(volume - masterVolume) > 0.0005 {
                masterVolume = volume
            }
        } else {
            // No single volume level for this device (e.g. Multi-Output
            // Device) — don't silently keep showing the previous device's
            // number, which read as "every device is stuck at one synced
            // volume." The UI disables the slider when this is false.
            supportsMasterVolume = false
        }
        let muted = CoreAudioController.isMuted(current)
        if muted != isMuted {
            isMuted = muted
        }
    }

    private func refreshCurrentInputDeviceState() {
        guard let current = defaultInputDeviceID else { return }
        if let volume = CoreAudioController.inputVolume(of: current),
           Date() > ignoreInputVolumeEchoUntil, abs(volume - inputVolume) > 0.0005 {
            inputVolume = volume
        }
        let muted = CoreAudioController.isInputMuted(current)
        if muted != isInputMuted {
            isInputMuted = muted
        }
    }

    func setMasterVolume(_ volume: Float) {
        guard let current = defaultDeviceID else { return }
        masterVolume = volume // instant visual feedback, cheap
        ignoreVolumeEchoUntil = Date().addingTimeInterval(0.3)

        // The volume scalar and the mute flag are separate CoreAudio
        // properties — 0.0 volume scales the gain down but doesn't
        // guarantee hardware silence the way the dedicated mute property
        // does (this is exactly why Apple ships mute as its own control
        // instead of just "slider at minimum"). Dragging to 0 should still
        // mean silent, so engage real mute there and clear it once you
        // drag back up.
        if volume <= 0, !isMuted {
            setMuted(true)
        } else if volume > 0, isMuted {
            setMuted(false)
        }

        // A drag can fire this many times a second; each CoreAudio write is an
        // IPC round-trip to coreaudiod, which is what made dragging feel
        // choppy. Coalesce bursts into one write every ~16ms (still reads as
        // live) instead of writing on every pixel of movement.
        pendingVolumeWrite?.cancel()
        let work = DispatchWorkItem {
            CoreAudioController.setVolume(current, volume)
        }
        pendingVolumeWrite = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: work)
    }

    func toggleMute() {
        setMuted(!isMuted)
    }

    func setMuted(_ muted: Bool) {
        guard let current = defaultDeviceID else { return }
        isMuted = muted
        CoreAudioController.setMuted(current, muted)
    }

    func selectDevice(_ device: AudioDevice) {
        CoreAudioController.setDefaultOutputDevice(device.id)
        refresh()
    }

    func setInputVolume(_ volume: Float) {
        guard let current = defaultInputDeviceID else { return }
        inputVolume = volume // instant visual feedback, cheap
        ignoreInputVolumeEchoUntil = Date().addingTimeInterval(0.3)

        // Same reasoning as setMasterVolume: 0% should look and behave like
        // mute, not just display the same number.
        if volume <= 0, !isInputMuted {
            setInputMuted(true)
        } else if volume > 0, isInputMuted {
            setInputMuted(false)
        }

        pendingInputVolumeWrite?.cancel()
        let work = DispatchWorkItem {
            CoreAudioController.setInputVolume(current, volume)
        }
        pendingInputVolumeWrite = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: work)
    }

    func toggleInputMute() {
        setInputMuted(!isInputMuted)
    }

    func setInputMuted(_ muted: Bool) {
        guard let current = defaultInputDeviceID else { return }
        isInputMuted = muted
        CoreAudioController.setInputMuted(current, muted)
    }

    func selectInputDevice(_ device: AudioDevice) {
        CoreAudioController.setDefaultInputDevice(device.id)
        refresh()
    }
}
