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
- "Launch at Login" toggle (via `SMAppService`, no LaunchAgent plist needed)
- No Dock icon, no menu bar clutter beyond one icon
- About panel with a link back to the author's GitHub

## Roadmap

- **Per-app volume mixing.** macOS has no public "volume mixer" API like
  Windows does. The plan is to use Apple's newer Core Audio **Process Tap**
  API (macOS 14.4+) to capture each running app's audio stream and rescale it
  through an aggregate output device — no virtual driver / kernel extension
  required. This is the next major milestone.

## Requirements

- macOS 14.4 (Sonoma) or later
- **Full Xcode** (not just the Command Line Tools) to build — SwiftUI's
  `@State`/`@Binding` macros need the compiler plugins that ship inside
  `Xcode.app`. Install Xcode from the App Store, then:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```

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
- `MenuBarContentView.swift` / `AboutView.swift` — SwiftUI UI
- `LoginItemManager.swift` — thin wrapper around `ServiceManagement.SMAppService`

## License

MIT — see [LICENSE](LICENSE). Created in 2026 by [FernandoVD](https://github.com/FernandoVD).
