import AppKit
import CoreAudio
import Foundation

struct AppAudioItem: Identifiable {
    var id: pid_t { pid }
    let pid: pid_t
    let name: String
    let icon: NSImage?
    var volume: Float
    var isMuted: Bool
    /// nil means "follow whatever the system default output device is".
    var outputDeviceID: AudioDeviceID?
}

@MainActor
final class PerAppAudioController: ObservableObject {
    /// Open, regular (Dock-visible) apps that have ever registered an audio
    /// process with CoreAudio — i.e. apps that can make noise, not
    /// necessarily ones making noise right this second. Excludes apps like
    /// Finder or System Settings that never touch the audio subsystem at
    /// all, while still showing something like the App Store the first time
    /// it plays a sound, and keeping it listed afterward (registration is
    /// stable for the life of the process, so this doesn't flicker the way
    /// "is it playing audio right now" would).
    @Published private(set) var items: [AppAudioItem] = []

    private var engines: [pid_t: ProcessTapEngine] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private let listenerQueue = DispatchQueue(label: "com.fernandovandet.bettersound.perapp.listener")

    init() {
        refreshAppList()

        let nc = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshAppList() }
        })
        workspaceObservers.append(nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshAppList() }
        })

        CoreAudioController.addSystemListener(queue: listenerQueue) { [weak self] in
            Task { @MainActor in self?.defaultOutputDeviceChanged() }
        }
        CoreAudioController.addProcessListListener(queue: listenerQueue) { [weak self] in
            Task { @MainActor in self?.refreshAppList() }
        }
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers { nc.removeObserver(observer) }
    }

    private func refreshAppList() {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != selfPID
        }

        let livePIDs = Set(running.map(\.processIdentifier))
        for (pid, engine) in engines where !livePIDs.contains(pid) {
            engine.stop()
            engines.removeValue(forKey: pid)
        }

        items = running.compactMap { app -> AppAudioItem? in
            let pid = app.processIdentifier
            let isAudioCapable = CoreAudioController.audioProcessObjectID(forPID: pid) != nil
            guard isAudioCapable || engines[pid] != nil else { return nil }

            return AppAudioItem(
                pid: pid,
                name: app.localizedName ?? "Unknown",
                icon: app.icon,
                volume: engines[pid]?.volume ?? 1.0,
                isMuted: engines[pid]?.muted ?? false,
                outputDeviceID: engines[pid]?.outputDeviceID
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func setVolume(_ volume: Float, for item: AppAudioItem) {
        let clamped = max(0, min(1, volume))
        let shouldUnmute = clamped > 0 && (engines[item.pid]?.muted ?? false)

        // A drag fires this dozens of times a second. Update the visible row
        // in place — cheap — instead of calling refreshAppList(), which
        // re-enumerates every running app via NSWorkspace and CoreAudio on
        // every single tick; that full rebuild was what made dragging choppy.
        if let index = items.firstIndex(where: { $0.pid == item.pid }) {
            items[index].volume = clamped
            if shouldUnmute { items[index].isMuted = false }
        }

        if let engine = engines[item.pid] {
            engine.volume = clamped
            if shouldUnmute { engine.muted = false }
            retireIfIdle(item.pid)
        } else if clamped < 0.999 {
            let engine = ProcessTapEngine(pid: item.pid, name: item.name)
            engine.volume = clamped
            if engine.start() {
                engines[item.pid] = engine
            }
        }
    }

    func toggleMute(for item: AppAudioItem) {
        let newMuted = !(engines[item.pid]?.muted ?? false)

        if let index = items.firstIndex(where: { $0.pid == item.pid }) {
            items[index].isMuted = newMuted
        }

        if let engine = engines[item.pid] {
            engine.muted = newMuted
            retireIfIdle(item.pid)
        } else if newMuted {
            let engine = ProcessTapEngine(pid: item.pid, name: item.name)
            engine.muted = true
            if engine.start() {
                engines[item.pid] = engine
            }
        }
    }

    func setOutputDevice(_ deviceID: AudioDeviceID?, for item: AppAudioItem) {
        if let engine = engines[item.pid] {
            engine.outputDeviceID = deviceID
            retireIfIdle(item.pid)
        } else if deviceID != nil {
            let engine = ProcessTapEngine(pid: item.pid, name: item.name)
            engine.outputDeviceID = deviceID
            if engine.start() {
                engines[item.pid] = engine
            }
        }
        refreshAppList()
    }

    /// Once volume is back to 1.0, output is back to "default", and it's not
    /// muted, the engine has nothing left to override — tear it down so the
    /// app just plays normally.
    private func retireIfIdle(_ pid: pid_t) {
        guard let engine = engines[pid] else { return }
        if engine.volume >= 0.999 && engine.outputDeviceID == nil && !engine.muted {
            engine.stop()
            engines.removeValue(forKey: pid)
        }
    }

    private func defaultOutputDeviceChanged() {
        for engine in engines.values {
            engine.followDefaultOutputDeviceChanged()
        }
    }
}
