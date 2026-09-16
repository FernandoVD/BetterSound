# Changelog

All notable changes to BetterSound are documented here.

## [1.2.0] - 2026-09-16

### Fixed (post-release, same version)
- The v1.2.0 binary was arm64-only — a friend's real install on an Intel
  Mac succeeded via Homebrew but couldn't launch (no Rosetta translation
  arm64→x86_64). Replaced the release asset in place with a universal
  (arm64 + x86_64) build; `build-app.sh` now always builds both
  architectures. See [Requirements](README.md#requirements) for which
  Intel Macs macOS 26 actually supports.
- Documented that recent Homebrew versions require `brew trust` before
  loading a cask from an unfamiliar tap for the first time.

### Added
- Live percentage next to Sound, Input, and every per-app row (e.g. "72%"),
  scaled down for secondary rows so it stays out of the way.
- Output and Input device pickers: tapping the chevron now expands an
  inline list of rich rows — circular icon badge, white background + green
  icon when active — matching Control Center's own device list, instead of
  a plain dropdown.
- Per-device icons in the per-app output-routing menu (as rich as a native
  `NSMenu` can render — no colored badge there, that's a hard platform
  limit, not a choice).

### Changed
- **The master Sound slider now auto-mutes at 0%, and this now applies to
  Input and every per-app slider too** — dragging any slider to 0 engages
  real mute (icon included), instead of just displaying "0%" while a faint
  amount of audio could still get through. The volume scalar and the mute
  flag are genuinely separate CoreAudio properties; 0.0 volume doesn't
  guarantee hardware silence the way mute does.
- Input's slider is visibly smaller than Sound's — one control among
  several, not the one authoritative "this is the volume" reading Sound
  represents.
- PillSlider is a thin track + a distinct round knob now, not a growing
  filled bar — verified against real reference screenshots of the native
  macOS/iOS slider. The knob turns to Liquid Glass, and the track fades
  more translucent, only while actively dragging, matching a screenshot of
  the real native slider mid-drag.
- Icon sizing unified across Sound/Output/Input/Applications (explicit
  16×16 frames everywhere) — Output and Input were previously only
  width-constrained, letting icons render taller than the rest of the UI.

### Fixed
- The Output/Input chevron button's overlapping/garbled look: SwiftUI's
  `Menu` adds its own automatic disclosure indicator on top of a custom
  icon label unless explicitly suppressed, which was colliding with our
  own chevron glyph.
- An earlier attempt at the slider redesign had a real rendering bug where
  a `glassEffect` track visibly cut a line through the knob — root-caused
  to mixing a glass element with a plain sibling in the same ZStack, not
  guessed at.

## [1.1.2] - 2026-09-15

### Added
- The update prompt now also shows `xattr -cr /Applications/BetterSound.app`
  with its own copy button, alongside the upgrade command.

### Fixed
- Verified directly (`xattr -l` after a real `brew upgrade --cask
  bettersound`) that **every update re-triggers the Gatekeeper "Not Opened"
  dialog**, not just the first install — each release is ad-hoc signed with
  no stable Developer ID identity, so macOS treats every new version as a
  never-seen-before binary. Documented in the README's Updating section and
  surfaced directly in the update prompt so it isn't a surprise.

## [1.1.1] - 2026-09-15

### Added
- The "Update available" prompt (popover and Settings) now shows the exact
  `brew upgrade --cask bettersound` command with a one-click copy button,
  instead of just linking to the release page.

### Fixed
- Documented (README's new [Updating](README.md#updating) section) that
  running `brew install --cask bettersound` again does **not** update an
  existing install — Homebrew silently says "the latest version is already
  installed" even when it isn't. `brew upgrade --cask bettersound` is the
  actual update command.

## [1.1.0] - 2026-09-15

### Added
- Mute button on every per-app row and the Input row, matching the master
  Sound row's `[mute] [slider]` layout. Unmuting restores the previous
  level rather than just being volume-back-to-zero.
- Update checking: a manual "Check for Updates…" button and an
  "Automatically check for updates" toggle in Settings, plus an "Update
  available" link in the popover when one exists. No silent download or
  install — see the README's [Updates](README.md#updates) section for why.
- App icon (rounded-squircle gradient, speaker glyph with a "+" in place of
  the usual sound-wave arcs).
- Real Liquid Glass materials (`glassEffect`) on the slider track and device
  icon badges — requires macOS 26.
- General Input section: a master input-level slider plus a device picker.

### Changed
- The Applications list now only shows apps that have ever registered an
  audio process with CoreAudio (so Finder/System Settings don't show up),
  instead of every open app — but unlike an earlier "is it playing right
  now" attempt, this doesn't flicker: an app like the App Store shows up
  once it plays its first sound and stays listed from then on.
- Output/Input device pickers are compact single-row selectors (icon + name
  + a small chevron menu) instead of an expanded list of rows.
- Devices that can't actually be set as the system default (e.g. Microsoft
  Teams' virtual audio device) are filtered out of the Output/Input pickers,
  since macOS silently no-ops a switch to one rather than erroring.
- About/Settings live in the app's own menu bar item and a
  "BetterSound Settings…" popover link, not a system-tray-style footer.

### Fixed
- Master and per-app sliders no longer feel choppy while dragging — both
  were doing expensive work (a CoreAudio IPC write, or a full app-list
  rebuild) on every single drag tick instead of a debounced/in-place update.
- The master volume slider no longer silently shows a stale value when
  switching to a device with no single volume level (e.g. a Multi-Output
  Device) — it's now disabled with an explanation instead.

## [1.0.0] - 2026-09-15

Initial release.

- Menu bar icon with a Control Center-styled Sound popover: master volume
  + mute, and an output device switcher.
- Per-app volume sliders and per-app output routing, via a Core Audio
  Process Tap-based render engine (see the README's Architecture section).
- Launch at Login (`SMAppService`), Dock icon hidden by default.
- No third-party dependencies; talks directly to the CoreAudio HAL.
