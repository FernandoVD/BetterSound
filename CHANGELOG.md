# Changelog

All notable changes to BetterSound are documented here.

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
