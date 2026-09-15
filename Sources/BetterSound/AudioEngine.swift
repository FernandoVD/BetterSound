import Combine
import CoreAudio
import Foundation

@MainActor
final class AudioEngine: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var defaultDeviceID: AudioDeviceID?
    @Published private(set) var masterVolume: Float = 0
    @Published private(set) var isMuted: Bool = false

    private let listenerQueue = DispatchQueue(label: "com.fernandovandet.volumemixer.listener")
    private var observedDeviceID: AudioDeviceID?

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
    }

    private func refreshCurrentDeviceState() {
        guard let current = defaultDeviceID else { return }
        masterVolume = CoreAudioController.volume(of: current) ?? masterVolume
        isMuted = CoreAudioController.isMuted(current)
    }

    func setMasterVolume(_ volume: Float) {
        guard let current = defaultDeviceID else { return }
        masterVolume = volume
        CoreAudioController.setVolume(current, volume)
        if volume > 0, isMuted {
            setMuted(false)
        }
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

    func setVolume(_ volume: Float, for device: AudioDevice) {
        CoreAudioController.setVolume(device.id, volume)
        if device.id == defaultDeviceID {
            masterVolume = volume
        }
    }

    func volume(for device: AudioDevice) -> Float {
        CoreAudioController.volume(of: device.id) ?? 0
    }
}
