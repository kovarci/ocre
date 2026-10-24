# Changelog

All notable changes to Ocre are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/).

## [Unreleased]

### Added

- **An installer**, `Ocre-<version>-setup.exe` (Inno Setup): a wizard, a Start menu entry, an
  entry in *Settings > Apps*, optional launch at sign-in. Before changing anything it records
  the original value of the Windows settings it touches (`GdiIcmGammaRange`, the
  `Win+Ctrl+C` shortcut) in `sauvegarde\`, as a `.reg` file you can double-click and as the
  state the uninstaller reads. Uninstalling stops Ocre cleanly and gives back exactly what
  the installer changed — and nothing else. A Start menu shortcut restores the original
  settings, another resets the screen (`Ocre.exe /reset`). An *Information* page announces
  every change before it is made.
- **An About window** (*Settings > About…*): the version, links to the project and its
  releases, **Copy diagnostic**, the settings folder, and the licences of what is embedded.
- **`Ocre.exe /version` and `/diag`.** `/diag` prints what a bug report needs — Ocre and
  Windows versions, screens, whether the gamma safeguard is lifted, other colour tools
  running — with no personal data.
- **GitHub Actions.** `ci.yml` runs on every change: calculation and command-line tests, the
  build of `Ocre.exe` and of the installer, and the installer's full install / update /
  roll-back round trip. `release.yml` builds, signs through SignPath (once the project is
  accepted) and publishes a release, with `SHA256SUMS.txt`. The toolchain is pinned by
  version and SHA-256 (`tools/outils-ci.ps1`); the actions are pinned by commit.
- **Tests:** French and English have the same keys, and every text the code asks for exists;
  `/version` and `/diag`; the About window and its leaks; creating the startup task for
  real; the installer, in four starting states, without elevation
  (`tools/test-installateur.ps1`); the documentation's links (`tools/liens.ps1`).
- **Documentation:** the README is now a short front page; the detail lives in `docs/en` and
  `docs/fr`, with screenshots (`tools/captures.ps1` regenerates them). `CONTRIBUTING.md`,
  `SECURITY.md`, `CODE_OF_CONDUCT.md`, issue and pull request templates.
- Repository hygiene: topics, private vulnerability reporting, Dependabot for the pinned actions,
  release-note categories (`.github/release.yml`), a social preview image
  (`tools/social-preview.ps1`).
- `Ocre.exe` carries its company, copyright and original file name; the GPL v2 text of the
  embedded AutoHotkey interpreter ships with the archive and the installer.

### Changed

- `README.md` is now in English, the default on GitHub; the French one is `README.fr.md`.
  The archive carries `README.fr.md` instead of `README.en.md`.

### Fixed

- **The "Start with Windows" switch** in the settings silently fell back to a shortcut in the
  Startup folder — which Explorer launches tens of seconds late — instead of creating the
  logon scheduled task: the task's `MultipleInstances` property was misspelled, and the error
  was swallowed. It now creates the task.
- `install.ps1 -Build` and `tools/installer.ps1` no longer end with an error exit code when
  there is simply no code-signing certificate.
- `tools/test-cli.ahk` no longer depends on the machine: it passes on a fresh one with no
  settings file and on a screen that does not change.

## [1.3.0] - 2026-10-24

First public release.

- A gamma-ramp warm filter for every screen, in percent or Kelvin (1200–6500 K), with
  per-screen settings; brightness through the real backlight (DDC/CI, WMI) with the ramp
  below the hardware floor; HDR through the compositor; OLED true black, grayscale, a
  darkroom mode.
- Keyboard shortcuts (a primary set and a fallback set with no function key), mouse wheel,
  tray icon, a right-click panel with three presets, and a settings window.
- A scheduler: fixed hours or following the sun, from an offline table of 26,700 cities,
  with long fades; a 20-20-20 reminder.
- Optional comforts: dimming the screen you no longer look at, lowering brightness on
  battery, following the screen's content, learning your habits.
- A command line (`/set`, `/kelvin`, `/preset`, `/get`, `/export`, `/import`, `/reset`, …),
  a portable mode, French and English.
- `install.ps1`, and a portable `Ocre-1.3.0.zip`.

[Unreleased]: https://github.com/kovarci/ocre/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/kovarci/ocre/releases/tag/v1.3.0
