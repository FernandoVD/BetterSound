# BetterSound

A tiny, open-source menu bar app for macOS that puts a Control Center–style
sound mixer next to the battery icon: master volume, mute, and a one-click
picker for every connected output device (built-in speakers, headphones,
AirPods, USB/Bluetooth audio, etc.).

No Dock icon, no background processes, no polling — it talks to CoreAudio
directly and only wakes up when a property actually changes.

## Features (v1)

- Menu bar icon that lives next to the battery/Wi-Fi/clock cluster
- Master volume slider + mute, styled to match Control Center's Sound module
- Output device switcher with automatic icons (speakers, headphones, AirPods,
  USB, HDMI) and live updates when devices connect/disconnect
- **Per-app volume sliders**, one per running application, plus a per-app
  output picker (send one app to AirPods while everything else stays on
  speakers). macOS has no public "set this app's volume" API, so this works
  by using Apple's Core Audio **Process Tap** API (macOS 14.2+) to mute the
  app at the source and re-render its audio, scaled, straight to the chosen
  output device — see [Architecture](#architecture). Engines are created
  lazily: an app nobody touches costs nothing.
- App menu (top-left, next to the Apple menu) with **About BetterSound** and
  **Settings…**, the way a normal Mac app works — the popover itself stays
  audio-controls-only
- Settings: show/hide the Dock icon, and "Launch at Login" (via
  `SMAppService`, no LaunchAgent plist needed)
- No Dock icon by default, no menu bar clutter beyond one icon

## Requirements

- macOS 15 (Sequoia) or later
- **Full Xcode** (not just the Command Line Tools) to build — SwiftUI's
  `@State`/`@Binding` macros need the compiler plugins that ship inside
  `Xcode.app`. Install Xcode from the App Store, then:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```

- The first time you turn down an individual app's volume, macOS will prompt
  for an "Audio Capture" permission (the same family as Screen Recording) —
  that's expected, it's what lets the Process Tap API read that app's audio
  so BetterSound can rescale it.

## Building

```bash
swift build -c release          # sanity-check the build
./Scripts/build-app.sh          # produces BetterSound.app, ad-hoc signed
```

Then move `BetterSound.app` to `/Applications` and open it. Running it from
a stable location matters for the "Launch at Login" toggle to keep working
across reboots.

## Development

```bash
swift run
```

runs it straight from the package (useful while iterating — it still hides
its Dock icon and behaves as a normal menu bar app).

## Architecture

- `CoreAudioController.swift` — thin wrapper around the CoreAudio HAL
  (`AudioObjectGetPropertyData` / `SetPropertyData`), no third-party deps
- `AudioEngine.swift` — `ObservableObject` that mirrors CoreAudio state into
  SwiftUI and subscribes to HAL property-change listeners (no polling)
- `AudioDevice.swift` — device model + heuristics for classifying transport
  type into an icon (built-in speakers/headphones, AirPods, Bluetooth, USB, HDMI)
- `ProcessTapEngine.swift` — the per-app audio engine. For one running app:
  creates a Core Audio process tap muted at the source, wraps it in a private
  aggregate device, reads its captured audio via an `AudioDeviceIOProc`,
  applies a gain, and renders the result directly to the chosen physical
  output device via a second `AudioDeviceIOProc` — bypassing "system default
  output" entirely so different apps can target different devices at once.
- `RingBuffer.swift` — lock-light (`os_unfair_lock`) ring buffer moving audio
  between the tap-capture callback and the render callback, which run on
  independent device clocks/threads; `AtomicFloat` for the live gain value
- `PerAppAudioController.swift` — `ObservableObject` listing running apps
  (`NSWorkspace`) and lazily owning one `ProcessTapEngine` per app that's
  actually been touched (volume ≠ 100% or output overridden)
- `MenuBarContentView.swift` / `AboutView.swift` / `SettingsView.swift` — SwiftUI UI
- `LoginItemManager.swift` — thin wrapper around `ServiceManagement.SMAppService`

### Known v1 limitations

- The ring buffer assumes an interleaved (single-buffer) tap format, which is
  the common case for HAL device streams; a non-interleaved/multi-stream tap
  format is a silent no-op rather than a crash. Worth revisiting if you hit
  an app that doesn't respond to its slider.
- No sample-rate conversion between the tap's format and the output device's
  format yet — mismatched rates will sound wrong rather than being resampled.

## License

MIT — see [LICENSE](LICENSE). Created in 2026 by [FernandoVD](https://github.com/FernandoVD).
