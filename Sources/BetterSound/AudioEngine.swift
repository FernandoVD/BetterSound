import Combine
import CoreAudio
import Foundation

@MainActor
final class AudioEngine: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var defaultDeviceID: AudioDeviceID?
    @Published private(set) var masterVolume: Float = 0
    @Published private(set) var isMuted: Bool = false

    @Published private(set) var inputDevices: [AudioDevice] = []
    @Published private(set) var defaultInputDeviceID: AudioDeviceID?
    @Published private(set) var inputVolume: Float = 0

    private let listenerQueue = DispatchQueue(label: "com.fernandovandet.volumemixer.listener")
    private var observedDeviceID: AudioDeviceID?
    private var observedInputDeviceID: AudioDeviceID?
    private var pendingVolumeWrite: DispatchWorkItem?
    private var pendingInputVolumeWrite: DispatchWorkItem?

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
        masterVolume = CoreAudioController.volume(of: current) ?? masterVolume
        isMuted = CoreAudioController.isMuted(current)
    }

    private func refreshCurrentInputDeviceState() {
        guard let current = defaultInputDeviceID else { return }
        inputVolume = CoreAudioController.inputVolume(of: current) ?? inputVolume
    }

    func setMasterVolume(_ volume: Float) {
        guard let current = defaultDeviceID else { return }
        masterVolume = volume // instant visual feedback, cheap
        if volume > 0, isMuted {
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

        pendingInputVolumeWrite?.cancel()
        let work = DispatchWorkItem {
            CoreAudioController.setInputVolume(current, volume)
        }
        pendingInputVolumeWrite = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: work)
    }

    func selectInputDevice(_ device: AudioDevice) {
        CoreAudioController.setDefaultInputDevice(device.id)
        refresh()
    }
}
