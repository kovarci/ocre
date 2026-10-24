# Building, testing, layout

[← Ocre](../../README.md#documentation) · [Français](../fr/development.md)

You need [AutoHotkey v2](https://www.autohotkey.com/) and PowerShell, nothing else to run
from source. The source is French (names, comments), by choice; the interface and the
documentation are in both languages. See [CONTRIBUTING.md](../../CONTRIBUTING.md) for
conventions.

## The commands

| To do this | Run |
|---|---|
| Run from source | `AutoHotkey64.exe .\Ocre.ahk` |
| Build `Ocre.exe`, without installing or touching the registry | `.\install.ps1 -Build -NoStart -NoStartup -NoRegistry` |
| Install from a clone: lift the gamma safeguard, build if missing, startup task, launch | `.\install.ps1` (as administrator the first time) |
| Build the installer | `.\tools\installer.ps1` |
| Everything: build, test, archive, installer → `dist\` | `.\tools\release.ps1` |
| The test suite | `.\tools\test.ps1` |
| The installer's install / update / roll-back | `.\tools\test-installateur.ps1` |
| The links in the documentation | `.\tools\liens.ps1` |
| The screenshots in `docs/img` | `.\tools\captures.ps1` |

Compiling to an executable is what gives a clean entry in the task manager: without it,
Windows shows `AutoHotkey64.exe` with its green icon, since it is the interpreter that
starts.

**Leave the Windows Night Light off** while you work on it: the two filters would add up.
The settings window flags it in red if it is scheduled.

## The tests

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test.ps1
```

returns the number of failing tests. The AutoHotkey interpreter is required: the tests are
not compiled. In order:

| Test | What it checks | Needs |
|---|---|---|
| `test-courbe` | the curve, the scheduler, the configuration — pure arithmetic | nothing |
| `test-soleil` | the solar calculation, against values from an independent implementation | nothing |
| `test-cli` | Kelvin, unit, breathing, shortcuts, export; French and English have the same keys; the startup task, created for real; the command line itself, as a subprocess, judged on its exit codes and output | nothing (a console, for the command line) |
| `test-ui` | every window, opened with a throwaway configuration, clicked, checked and photographed into `%TEMP%\ocre-test-ui` | the desktop for about twenty seconds; sets no ramp |
| `test-fuites` | redraws eight hundred times everything that gets redrawn, and compares the task manager's counters before and after | the desktop |
| `test-perf` | times the loading of everything Ocre loads (under a second and a half, interpreter included; 125 ms on the development machine) and measures the processor at rest, timers running, then `Ocre.exe` itself if it is running (under one percent of a core; half a percent with the mouse moving, zero without — the mouse hook for the wheel over the icon is the only cost) | |
| `test-clamp` (`-Clamp`) | sets an extreme ramp on **your screens** for half a second, to check that Windows does not clamp it | only on request |

The callbacks into the program are replaced by functions that record what they are asked,
so no test touches your real settings or sets a ramp. `test-ui` catches what the
arithmetic tests cannot see: a button whose closure captured the wrong variable, two names
differing only in case. `test-fuites` found, the day it was written, that every redraw left
three GDI objects behind — see [The logo](interface.md#the-logo).

Two details of `test-ui` are worth knowing if you write more: a click sent through
`SendInput` is lost as soon as another process holds a mouse hook — Ocre holds one for the
wheel over its icon — so the press and release are posted to the control itself; and an
arrow sent right after a Tab arrives before the slider is taken, hence one key at a time.
`OCRE_TEST_LANGUE=en` replays it in English, which is how the English screenshots are taken.

Outside the suite, [`tools/test-installateur.ps1`](../../tools/test-installateur.ps1) plays
the installer without elevation, on dummy keys (see
[Installation](installation.md#rolling-back)), and
[`tools/liens.ps1`](../../tools/liens.ps1) checks the documentation's links. On GitHub,
[`ci.yml`](../../.github/workflows/ci.yml) runs both, with the arithmetic and command-line
tests and the build, on every change.

## Layout

### The program

| | |
|---|---|
| [`Ocre.ahk`](../../Ocre.ahk) | the program: shortcuts, icon, watchdog, command line |
| [`lib/Config.ahk`](../../lib/Config.ahk) | persisted settings, portable mode and automatic startup |
| [`lib/I18n.ahk`](../../lib/I18n.ahk) | French and English texts |

### The filter

| | |
|---|---|
| [`lib/Gamma.ahk`](../../lib/Gamma.ahk) | the intensity curve and the ramp that carries it |
| [`lib/Ecrans.ahk`](../../lib/Ecrans.ahk) | which screens there are, and which one you are looking at |
| [`lib/Retro.ahk`](../../lib/Retro.ahk) | the hardware backlight, DDC/CI and WMI |
| [`lib/Filtre.ahk`](../../lib/Filtre.ahk) | the filter state and its application to the screens |
| [`lib/Fondu.ahk`](../../lib/Fondu.ahk) | easing a change made by hand |
| [`lib/Compositeur.ahk`](../../lib/Compositeur.ahk) | a colour matrix over the whole desktop: grey, and the tint in HDR |
| [`lib/Hdr.ahk`](../../lib/Hdr.ahk) | is the screen in HDR |
| [`lib/Concurrents.ahk`](../../lib/Concurrents.ahk) | are the Windows Night Light and colour filter on |
| [`lib/Unite.ahk`](../../lib/Unite.ahk) | percent or Kelvin, for display |

### The scheduler and the places

| | |
|---|---|
| [`lib/Horaire.ahk`](../../lib/Horaire.ahk) | the scheduler and its fade |
| [`lib/Soleil.ahk`](../../lib/Soleil.ahk) | sunrise and sunset, computed locally |
| [`lib/Villes.ahk`](../../lib/Villes.ahk) | city search, and the exonyms |
| [`lib/villes.txt`](../../lib/villes.txt) | 26,700 cities, read at the first search |
| [`lib/Pays.ahk`](../../lib/Pays.ahk) | country names, and accent flattening |
| [`lib/Fuseau.ahk`](../../lib/Fuseau.ahk) | an approximate location, from the time zone |

### The comforts

| | |
|---|---|
| [`lib/Rappel.ahk`](../../lib/Rappel.ahk) | the 20-20-20 rule, by breathing icon |
| [`lib/Inactif.ahk`](../../lib/Inactif.ahk) | dimming the screen you no longer look at |
| [`lib/Batterie.ahk`](../../lib/Batterie.ahk) | lowering brightness when the charger is unplugged |
| [`lib/Adaptatif.ahk`](../../lib/Adaptatif.ahk) | brightness that follows the screen content |
| [`lib/Capture.ahk`](../../lib/Capture.ahk) | a screen's average luminance, by DXGI desktop duplication |
| [`lib/Habitudes.ahk`](../../lib/Habitudes.ahk) | learning what is set by hand, and doing it itself |

### The interface

| | |
|---|---|
| [`lib/Ui.ahk`](../../lib/Ui.ahk) | GDI+ drawing surface and hover tracking |
| [`lib/Cadre.ahk`](../../lib/Cadre.ahk) | a resizable window around fixed content: centring, scrollbar |
| [`lib/Widgets.ahk`](../../lib/Widgets.ahk) | button, toggle, slider, counter, field, flag, keyboard, alert |
| [`lib/Theme.ahk`](../../lib/Theme.ahk) | palette and darkening of system elements |
| [`lib/Blob.ahk`](../../lib/Blob.ahk) | the logo, drawn live |
| [`lib/Police.ahk`](../../lib/Police.ahk) | the badge's Inter font, loaded from the exe resource |
| [`lib/Osd.ahk`](../../lib/Osd.ahk) | the intensity badge |
| [`lib/Panneau.ahk`](../../lib/Panneau.ahk) | the right-click panel |
| [`lib/Reglages.ahk`](../../lib/Reglages.ahk) | the settings window |
| [`lib/Apropos.ahk`](../../lib/Apropos.ahk) | the About window: version, links, copy the diagnostic, licences |
| [`lib/Planificateur.ahk`](../../lib/Planificateur.ahk) | the scheduler window |
| [`lib/Lieu.ahk`](../../lib/Lieu.ahk) | the location window |
| [`lib/Prereglages.ahk`](../../lib/Prereglages.ahk) | the three presets window |
| [`lib/Raccourcis.ahk`](../../lib/Raccourcis.ahk) | the shortcuts window, and their test |
| [`lib/Apprentissage.ahk`](../../lib/Apprentissage.ahk) | the habits window |

### Embedded, and its licences

| | |
|---|---|
| [`lib/Inter-Medium.ttf`](../../lib/Inter-Medium.ttf), [`lib/Inter-LICENSE.txt`](../../lib/Inter-LICENSE.txt) | the font and its licence (SIL OFL 1.1) |
| [`lib/AutoHotkey-LICENSE.txt`](../../lib/AutoHotkey-LICENSE.txt) | the licence (GPL v2) of the interpreter embedded in `Ocre.exe` |

### Building, releasing

| | |
|---|---|
| [`install.ps1`](../../install.ps1) | installs from a clone or the archive: gamma safeguard, build, startup task, launch |
| [`installer/`](../../installer/) | the installer's Inno Setup script, and `utilisateur.ps1`, what it sets in the user's own account (startup task) |
| [`tools/installer.ps1`](../../tools/installer.ps1) | builds `dist\Ocre-<version>-setup.exe` with Inno Setup (fetched by winget if missing) |
| [`tools/release.ps1`](../../tools/release.ps1) | builds, tests, checks the resources, packs it all into `dist\Ocre-<version>.zip` and builds the installer |
| [`tools/outils-ci.ps1`](../../tools/outils-ci.ps1), [`tools/archive.ps1`](../../tools/archive.ps1) | the pinned build chain (versions and hashes); the `.zip` archive, shared with `release.ps1` |
| [`tools/sign.ps1`](../../tools/sign.ps1) | signs `Ocre.exe` and the installer, when there is a certificate |
| [`tools/make-icon.ps1`](../../tools/make-icon.ps1) | generates `Ocre.ico` |
| [`tools/make-villes.ps1`](../../tools/make-villes.ps1) | regenerates the city table from GeoNames |
| [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) | on every change: tests, build, the installer's install / update / roll-back round trip, the docs' links |
| [`.github/workflows/release.yml`](../../.github/workflows/release.yml) | on a tag: builds, gets it signed (SignPath), publishes the release; [`.signpath/`](../../.signpath/) describes its artefacts |

### Tests and probes

| | |
|---|---|
| [`tools/test.ps1`](../../tools/test.ps1) | runs the tests and counts the failures |
| [`tools/test-courbe.ahk`](../../tools/test-courbe.ahk) | checks the curve and the scheduler, without hardware |
| [`tools/test-soleil.ahk`](../../tools/test-soleil.ahk) | checks the solar calculation against another implementation |
| [`tools/test-cli.ahk`](../../tools/test-cli.ahk) | Kelvin, unit, breathing, shortcuts, export, translations, command line |
| [`tools/test-ui.ahk`](../../tools/test-ui.ahk) | every window, opened, clicked, photographed |
| [`tools/test-fuites.ahk`](../../tools/test-fuites.ahk) | does what gets drawn a thousand times leave anything behind? |
| [`tools/test-perf.ahk`](../../tools/test-perf.ahk) | is startup fast, is rest silent? |
| [`tools/test-clamp.ahk`](../../tools/test-clamp.ahk) | checks that the ramp is not clamped |
| [`tools/test-installateur.ps1`](../../tools/test-installateur.ps1) | plays the test installer — install, update, roll back — without elevation, on dummy keys |
| [`tools/sonde-ecrans.ahk`](../../tools/sonde-ecrans.ahk) | what Ocre sees of your screens, without changing anything |
| [`tools/sonde-touches.ahk`](../../tools/sonde-touches.ahk) | which keys actually reach Windows |
| [`tools/sonde-luminosite.ahk`](../../tools/sonde-luminosite.ahk) | is the brightness key visible to software |

### Documentation and research

| | |
|---|---|
| [`docs/`](../../docs/) | this documentation (`en`, `fr`) and its screenshots (`img`) |
| [`tools/liens.ps1`](../../tools/liens.ps1) | do the links in the Markdown files lead anywhere? |
| [`tools/captures.ps1`](../../tools/captures.ps1) | regenerates the screenshots in `docs/img`, in both languages |
| [`tools/social-preview.ps1`](../../tools/social-preview.ps1) | draws the 1280 × 640 image shown when the repository is linked (`docs/img/social-preview.png`; uploaded by hand in the repository settings) |
| [`recherche/`](../../recherche/) | the native Night Light: codec, CLI, registry backups |
