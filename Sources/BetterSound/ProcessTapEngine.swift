import AudioToolbox
import CoreAudio
import Foundation

/// Captures one running app's audio via a Core Audio process tap (macOS 14.2+),
/// mutes the app at the source, and re-renders it — scaled by `volume` — to a
/// chosen physical output device. This is what makes a genuine per-app volume
/// slider possible, since macOS has no public "set this app's volume" API.
///
/// Created lazily (only once a per-app slider actually moves off 1.0, or its
/// output is redirected away from the system default) and torn down once both
/// return to default, so apps nobody touches cost nothing.
final class ProcessTapEngine {
    private let pid: pid_t
    private let name: String
    /// The actual gain applied in the render callback — 0 while muted,
    /// regardless of `storedVolume`, so unmuting restores the prior level.
    private let gain = AtomicFloat(1.0)
    private let ringBuffer = RingBuffer(capacityFrames: 48_000, channels: 2)

    private var storedVolume: Float = 1.0
    private var isMuted = false

    private var tapID: AudioObjectID = 0
    private var aggregateID: AudioObjectID = 0
    private var inputProcID: AudioDeviceIOProcID?
    private var outputProcID: AudioDeviceIOProcID?
    private var activeOutputDeviceID: AudioDeviceID?

    var volume: Float {
        get { storedVolume }
        set {
            storedVolume = max(0, min(1, newValue))
            applyGain()
        }
    }

    var muted: Bool {
        get { isMuted }
        set {
            isMuted = newValue
            applyGain()
        }
    }

    private func applyGain() {
        gain.value = isMuted ? 0 : storedVolume
    }

    /// nil means "follow the system default output device".
    var outputDeviceID: AudioDeviceID? {
        didSet {
            guard tapID != 0, outputDeviceID != oldValue else { return }
            reconnectOutput()
        }
    }

    init(pid: pid_t, name: String) {
        self.pid = pid
        self.name = name
    }

    @discardableResult
    func start() -> Bool {
        guard tapID == 0 else { return true }

        guard let processObjectID = CoreAudioController.audioProcessObjectID(forPID: pid) else {
            NSLog("BetterSound: no CoreAudio process object for \(name) (pid \(pid))")
            return false
        }

        let description = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        description.muteBehavior = .muted
        description.isPrivate = true
        description.name = "BetterSound Tap – \(name)"

        var newTapID: AudioObjectID = 0
        guard AudioHardwareCreateProcessTap(description, &newTapID) == noErr, newTapID != 0 else {
            NSLog("BetterSound: failed to create process tap for \(name)")
            return false
        }
        tapID = newTapID

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "BetterSound Tap Aggregate – \(name)",
            kAudioAggregateDeviceUIDKey: "com.fernandovandet.bettersound.tap.\(UUID().uuidString)",
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: description.uuid.uuidString]
            ]
        ]

        var newAggregateID: AudioObjectID = 0
        guard AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &newAggregateID) == noErr,
              newAggregateID != 0 else {
            NSLog("BetterSound: failed to create tap aggregate device for \(name)")
            AudioHardwareDestroyProcessTap(tapID)
            tapID = 0
            return false
        }
        aggregateID = newAggregateID

        let ring = ringBuffer
        let gainBox = gain
        var newInputProcID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&newInputProcID, aggregateID, nil) { _, inInputData, _, _, _ in
            ring.write(from: inInputData, gain: gainBox.value)
        }
        guard status == noErr, let newInputProcID, AudioDeviceStart(aggregateID, newInputProcID) == noErr else {
            NSLog("BetterSound: failed to start tap capture for \(name)")
            stop()
            return false
        }
        inputProcID = newInputProcID

        reconnectOutput()
        return activeOutputDeviceID != nil
    }

    private func reconnectOutput() {
        if let activeOutputDeviceID, let outputProcID {
            CoreAudioController.stopIOProc(outputProcID, on: activeOutputDeviceID)
        }
        outputProcID = nil
        activeOutputDeviceID = nil

        guard tapID != 0 else { return }
        guard let targetDevice = outputDeviceID ?? CoreAudioController.defaultOutputDeviceID() else { return }

        let ring = ringBuffer
        guard let newOutputProcID = CoreAudioController.startIOProc(on: targetDevice, block: { _, _, _, outOutputData, _ in
            ring.read(into: outOutputData)
        }) else {
            NSLog("BetterSound: failed to start render output for \(name)")
            return
        }
        outputProcID = newOutputProcID
        activeOutputDeviceID = targetDevice
    }

    /// Call when the system default output device changes, so apps following
    /// "default" (outputDeviceID == nil) move to the new device too.
    func followDefaultOutputDeviceChanged() {
        guard tapID != 0, outputDeviceID == nil else { return }
        reconnectOutput()
    }

    func stop() {
        if let activeOutputDeviceID, let outputProcID {
            CoreAudioController.stopIOProc(outputProcID, on: activeOutputDeviceID)
        }
        outputProcID = nil
        activeOutputDeviceID = nil

        if let inputProcID {
            AudioDeviceStop(aggregateID, inputProcID)
            AudioDeviceDestroyIOProcID(aggregateID, inputProcID)
        }
        inputProcID = nil

        if aggregateID != 0 {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = 0
        }
        if tapID != 0 {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = 0
        }
    }

    deinit {
        stop()
    }
}
