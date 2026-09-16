# BetterSound

A tiny, open-source menu bar app for macOS that puts a Control Center–style
sound mixer next to the battery icon: master volume, mute, and a one-click
picker for every connected output device (built-in speakers, headphones,
AirPods, USB/Bluetooth audio, etc.).

No Dock icon, no background processes, no polling — it talks to CoreAudio
directly and only wakes up when a property actually changes.

## Features

- Menu bar icon that lives next to the battery/Wi-Fi/clock cluster
- Master volume slider + mute, styled to match Control Center's Sound module
- Output device switcher with automatic icons (speakers, headphones, AirPods,
  USB, HDMI) and live updates when devices connect/disconnect; devices that
  can't actually be a system default (some virtual drivers) are left out
- Input: a general input-level slider + mute, plus a device picker
- **Per-app volume sliders and mute**, one per app that's ever registered
  audio with CoreAudio (so Finder/System Settings don't show up, but
  something like the App Store appears the moment it plays its first sound
  and stays listed), plus a per-app output picker (send one app to AirPods
  while everything else stays on speakers). macOS has no public "set this
  app's volume" API, so this works by using Apple's Core Audio **Process
  Tap** API (macOS 14.2+) to mute the app at the source and re-render its
  audio, scaled, straight to the chosen output device — see
  [Architecture](#architecture). Engines are created lazily: an app nobody
  touches costs nothing.
- App menu (top-left, next to the Apple menu) with **About BetterSound** and
  **Settings…**, the way a normal Mac app works — the popover itself stays
  audio-controls-only
- Settings: show/hide the Dock icon, "Launch at Login" (via `SMAppService`),
  and update checking (manual "Check for Updates…" or an "Automatically
  check for updates" toggle — see [Updates](#updates))
- No Dock icon by default, no menu bar clutter beyond one icon

## Updates

Settings → **Check for Updates…**, or toggle **Automatically check for
updates** for a daily background check. Either way this only tells you a
newer version exists — it does not silently download or install anything.
(This build isn't notarized, so an auto-downloaded update would hit the
same Gatekeeper quarantine block as a manual download anyway; a real silent
updater isn't worth building until that's solved.)

The popover's "Update available" link and the same line in Settings both
show the exact command to run (`brew upgrade --cask bettersound`) with a
one-click copy button, specifically because `brew install` a second time
silently does nothing — see [Updating](#updating) above.

## Installation

### Homebrew (recommended)

```bash
brew tap fernandovd/bettersound
brew install --cask bettersound
```

> [!NOTE]
> Recent Homebrew versions refuse to load a cask from a tap it hasn't seen
> before: `Refusing to load cask ... from untrusted tap`. If you hit that,
> run `brew trust --cask fernandovd/bettersound/bettersound` (or
> `brew trust fernandovd/bettersound`) once, then re-run `brew install`.

### Manual download

Grab `BetterSound.zip` from the [latest release](https://github.com/FernandoVD/BetterSound/releases/latest), unzip it, and move `BetterSound.app` to `/Applications`.

### Updating

> [!IMPORTANT]
> `brew install --cask bettersound` again does **not** update an existing
> install — Homebrew just prints "the latest version is already installed"
> and does nothing, even when it isn't. Running `install` a second time is
> the single most common way people end up stuck on an old version.

To actually update:

```bash
brew update && brew upgrade --cask bettersound
```

`brew update` refreshes the tap so Homebrew knows a newer version exists;
`brew upgrade --cask bettersound` is what installs it. (Bare `brew upgrade`
with no argument updates everything you have installed via Homebrew,
BetterSound included.)

If you installed manually, updating means repeating the manual-download
step above with the new zip — there's no separate "update" step for that
path.

**Every update re-triggers the Gatekeeper "Not Opened" dialog**, via either
path — verified directly: `xattr -l` on a freshly `brew upgrade`d install
still shows `com.apple.quarantine`. Each release is ad-hoc signed with no
stable Developer ID identity, so macOS treats every new version as a
never-seen-before binary, not just the very first install. Clear it again
after each update the same way:

```bash
xattr -cr /Applications/BetterSound.app
```

Either way, this build is **ad-hoc signed, not notarized** — no paid Apple
Developer account behind this project — so on first launch Gatekeeper will
say `"BetterSound" Not Opened`. That's not a malware flag, just macOS being
cautious about unsigned software. Fix it once with:

```bash
xattr -cr /Applications/BetterSound.app
```

or right-click `BetterSound.app` in Finder → **Open** → confirm.

## Requirements

- macOS 26 (Tahoe) or later — the UI uses real **Liquid Glass** materials
  (`glassEffect`, `GlassEffectContainer`), which are macOS 26+ only
- **Apple Silicon or Intel** — releases are universal binaries (verified:
  `lipo -info` shows both `arm64` and `x86_64` slices). Apple has said
  Tahoe is the last macOS version to support Intel at all, and only 4 Intel
  Mac models can run it: the 16" MacBook Pro (2019), the four-port 13"
  MacBook Pro (2020), the 2020 iMac, and the 2019 Mac Pro. Homebrew itself
  has dropped official support for Intel macOS as of this writing (installs
  still work, just flagged as a community-supported "Tier 3" configuration
  with a warning) — this hasn't been tested on real Intel hardware, only
  verified to build and link correctly for that architecture.
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
swift build -c release          # sanity-check the build (host arch only)
./Scripts/build-app.sh          # produces a universal BetterSound.app, ad-hoc signed
```

`build-app.sh` builds for `arm64` and `x86_64` together (`swift build --arch arm64 --arch x86_64`) so the resulting `.app` runs on both. A plain `swift build` without those flags only builds for your host architecture — fine for iterating locally, not for a release.

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
- `PillSlider.swift` — from-scratch capsule slider (the stock SwiftUI `Slider`
  doesn't render like Control Center's own); the fill is a solid capsule that
  IS the thumb. Its track uses real Liquid Glass (`.glassEffect`) only when
  `useGlass` is true (the default) — per [Apple's Liquid Glass adoption
  guide](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass),
  which explicitly warns against overusing the effect "in multiple custom
  controls," only the master Sound and Input sliders use it; per-app rows
  (of which there can be many) pass `useGlass: false` for a plain track. The
  two glass sliders share one `GlassEffectContainer` in
  `MenuBarContentView`, per the same guide's performance guidance.
- `MenuBarContentView.swift` / `AboutView.swift` / `SettingsView.swift` — SwiftUI UI
- `LoginItemManager.swift` — thin wrapper around `ServiceManagement.SMAppService`
- `UpdateChecker.swift` — polls the GitHub Releases API for a newer tag; no
  dependency, no silent install (this build isn't notarized, so an
  auto-downloaded update would hit the same Gatekeeper quarantine block as a
  manual one anyway) — it just tells you a new version exists and links to it

### Known v1 limitations

- The ring buffer assumes an interleaved (single-buffer) tap format, which is
  the common case for HAL device streams; a non-interleaved/multi-stream tap
  format is a silent no-op rather than a crash. Worth revisiting if you hit
  an app that doesn't respond to its slider.
- No sample-rate conversion between the tap's format and the output device's
  format yet — mismatched rates will sound wrong rather than being resampled.

## License

MIT — see [LICENSE](LICENSE). Created in 2026 by [FernandoVD](https://github.com/FernandoVD).
