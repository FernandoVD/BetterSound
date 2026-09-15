import CoreAudio
import Foundation

enum AudioKind {
    case builtInSpeakers
    case builtInHeadphones
    case airpods
    case bluetooth
    case usb
    case hdmi
    case other

    var symbolName: String {
        switch self {
        case .builtInSpeakers: return "hifispeaker.fill"
        case .builtInHeadphones: return "headphones"
        case .airpods: return "airpods"
        case .bluetooth: return "headphones"
        case .usb: return "hifispeaker.2.fill"
        case .hdmi: return "tv"
        case .other: return "speaker.wave.2.fill"
        }
    }

    /// Simpler icon set for the Input section — a generic mic covers most
    /// cases; AirPods keeps its distinct glyph since it's instantly recognizable.
    var inputSymbolName: String {
        switch self {
        case .airpods: return "airpods"
        default: return "mic.fill"
        }
    }
}

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let kind: AudioKind
    let supportsVolume: Bool
    /// False for devices that can't be set as the system default (e.g. some
    /// virtual drivers like Microsoft Teams' audio device) — such devices
    /// are still valid targets for per-app output routing, just not for the
    /// main Output/Input picker.
    let canBeDefault: Bool

    static func load(_ id: AudioDeviceID) -> AudioDevice {
        let name = CoreAudioController.name(of: id)
        return AudioDevice(
            id: id,
            uid: CoreAudioController.uid(of: id),
            name: name,
            kind: Self.classify(id: id, name: name),
            supportsVolume: CoreAudioController.hasVolume(id),
            canBeDefault: CoreAudioController.canBeDefaultOutput(id)
        )
    }

    static func loadInput(_ id: AudioDeviceID) -> AudioDevice {
        let name = CoreAudioController.name(of: id)
        return AudioDevice(
            id: id,
            uid: CoreAudioController.uid(of: id),
            name: name,
            kind: Self.classify(id: id, name: name),
            supportsVolume: CoreAudioController.inputVolume(of: id) != nil,
            canBeDefault: CoreAudioController.canBeDefaultInput(id)
        )
    }

    private static func classify(id: AudioDeviceID, name: String) -> AudioKind {
        let transport = CoreAudioController.transportType(of: id)
        let lowerName = name.lowercased()

        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:
            if let source = CoreAudioController.builtInDataSourceName(of: id)?.lowercased(), source.contains("headphone") {
                return .builtInHeadphones
            }
            return .builtInSpeakers
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            if lowerName.contains("airpods") {
                return .airpods
            }
            return .bluetooth
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return .hdmi
        default:
            return .other
        }
    }
}
