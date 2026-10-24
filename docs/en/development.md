# Building, testing, layout

[← Ocre](../../README.md#documentation) · [Français](../fr/development.md)

## The tests

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\test.ps1
```

runs `test-courbe`, `test-soleil`, `test-cli` and `test-ui` -- the curve,
the sun, what 1.3 added (Kelvin, unit, breathing, shortcuts, export, and the
command line itself as a subprocess, judged on its exit codes), then every
window, opened with a throwaway configuration, clicked, checked and
photographed into `%TEMP%\ocre-test-ui` -- and returns the number of
failing tests, then `test-fuites`, which redraws eight hundred times
everything that gets redrawn and compares the task manager's counters
before and after, and `test-perf`, which times the loading of everything
Ocre loads (under a second and a half, interpreter included; 125 ms on the
development machine) and measures the processor at rest with the timers
running, then `Ocre.exe` itself if it is running (under one percent of a
core; half a percent measured with the mouse moving, zero without -- the
mouse hook for the wheel over the icon is the only cost). The first three touch nothing; the next two show Ocre's
windows for about twenty seconds without setting any ramp, the callbacks
into the program being replaced by functions that record what they are
asked. `test-ui` catches what the arithmetic tests cannot see: a button
whose closure captured the wrong variable, two names differing only in
case. `test-fuites` found, the day it was written, that every redraw left
three GDI objects behind -- see "The logo". `-Clamp` adds `test-clamp`, which sets an extreme ramp on your screens for
half a second to check that Windows does not clamp it. The AutoHotkey
interpreter is required: the tests are not compiled.

Two details of `test-ui` are worth knowing if you write more: a click sent
through `SendInput` is lost as soon as another process holds a mouse hook --
Ocre holds one for the wheel over its icon -- so the press and release are
posted to the control itself; and an arrow sent right after a Tab arrives
before the slider is taken, hence one key at a time.

Compiling to an executable is what gives a clean entry in the task manager:
without it, Windows shows `AutoHotkey64.exe` with its green icon, since it is
the interpreter that starts.

**Leave the Windows Night Light off**: the two filters would add up. The
settings window flags it in red if it is scheduled.


## Layout

| | |
|---|---|
| [`Ocre.ahk`](../../Ocre.ahk) | the program: shortcuts, icon, watchdog, command line |
| [`lib/Gamma.ahk`](../../lib/Gamma.ahk) | the intensity curve and the ramp that carries it |
| [`lib/Ecrans.ahk`](../../lib/Ecrans.ahk) | which screens there are, and which one you are looking at |
| [`lib/Retro.ahk`](../../lib/Retro.ahk) | the hardware backlight, DDC/CI and WMI |
| [`lib/Filtre.ahk`](../../lib/Filtre.ahk) | the filter state and its application to the screens |
| [`lib/Fondu.ahk`](../../lib/Fondu.ahk) | easing a change made by hand |
| [`lib/Compositeur.ahk`](../../lib/Compositeur.ahk) | a colour matrix over the whole desktop: grey, and the tint in HDR |
| [`lib/Hdr.ahk`](../../lib/Hdr.ahk) | is the screen in HDR |
| [`lib/Horaire.ahk`](../../lib/Horaire.ahk) | the scheduler and its fade |
| [`lib/Unite.ahk`](../../lib/Unite.ahk) | percent or Kelvin, for display |
| [`lib/Concurrents.ahk`](../../lib/Concurrents.ahk) | are the Windows Night Light and colour filter on |
| [`lib/Soleil.ahk`](../../lib/Soleil.ahk) | sunrise and sunset, computed locally |
| [`lib/Villes.ahk`](../../lib/Villes.ahk) | city search, and the exonyms |
| [`lib/villes.txt`](../../lib/villes.txt) | 26,700 cities, read at the first search |
| [`lib/Pays.ahk`](../../lib/Pays.ahk) | country names, and accent flattening |
| [`lib/Lieu.ahk`](../../lib/Lieu.ahk) | the location window |
| [`lib/Planificateur.ahk`](../../lib/Planificateur.ahk) | the scheduler window |
| [`lib/Prereglages.ahk`](../../lib/Prereglages.ahk) | the three presets window |
| [`lib/Raccourcis.ahk`](../../lib/Raccourcis.ahk) | the shortcuts window, and their test |
| [`lib/Rappel.ahk`](../../lib/Rappel.ahk) | the 20-20-20 rule, by breathing icon |
| [`lib/Inactif.ahk`](../../lib/Inactif.ahk) | dimming the screen you no longer look at |
| [`lib/Batterie.ahk`](../../lib/Batterie.ahk) | lowering brightness when the charger is unplugged |
| [`lib/Adaptatif.ahk`](../../lib/Adaptatif.ahk) | brightness that follows the screen content |
| [`lib/Capture.ahk`](../../lib/Capture.ahk) | a screen's average luminance, by DXGI desktop duplication |
| [`lib/Habitudes.ahk`](../../lib/Habitudes.ahk) | learning what is set by hand, and doing it itself |
| [`lib/Apprentissage.ahk`](../../lib/Apprentissage.ahk) | the habits window |
| [`lib/Fuseau.ahk`](../../lib/Fuseau.ahk) | an approximate location, from the time zone |
| [`lib/Blob.ahk`](../../lib/Blob.ahk) | the logo, drawn live |
| [`lib/Police.ahk`](../../lib/Police.ahk) | the badge's Inter font, loaded from the exe resource |
| [`lib/Inter-Medium.ttf`](../../lib/Inter-Medium.ttf), [`lib/Inter-LICENSE.txt`](../../lib/Inter-LICENSE.txt) | the font and its licence (SIL OFL 1.1) |
| [`lib/AutoHotkey-LICENSE.txt`](../../lib/AutoHotkey-LICENSE.txt) | the licence (GPL v2) of the interpreter embedded in `Ocre.exe` |
| [`lib/Ui.ahk`](../../lib/Ui.ahk) | GDI+ drawing surface and hover tracking |
| [`lib/Cadre.ahk`](../../lib/Cadre.ahk) | a resizable window around fixed content: centring, scrollbar |
| [`lib/Widgets.ahk`](../../lib/Widgets.ahk) | button, toggle, slider, counter, field, flag, keyboard, alert |
| [`lib/Osd.ahk`](../../lib/Osd.ahk) | the intensity badge |
| [`lib/Panneau.ahk`](../../lib/Panneau.ahk) | the right-click panel |
| [`lib/Reglages.ahk`](../../lib/Reglages.ahk) | the settings window |
| [`lib/Apropos.ahk`](../../lib/Apropos.ahk) | the About window: version, links, copy the diagnostic, licences |
| [`lib/Theme.ahk`](../../lib/Theme.ahk) | palette and darkening of system elements |
| [`lib/I18n.ahk`](../../lib/I18n.ahk) | French and English texts |
| [`lib/Config.ahk`](../../lib/Config.ahk) | persisted settings, portable mode and automatic startup |
| [`tools/make-icon.ps1`](../../tools/make-icon.ps1) | generates `Ocre.ico` |
| [`tools/make-villes.ps1`](../../tools/make-villes.ps1) | regenerates the city table from GeoNames |
| [`tools/test.ps1`](../../tools/test.ps1) | runs the tests and counts the failures |
| [`tools/test-cli.ahk`](../../tools/test-cli.ahk) | Kelvin, unit, breathing, shortcuts, export, command line |
| [`tools/test-ui.ahk`](../../tools/test-ui.ahk) | every window, opened, clicked, photographed |
| [`tools/test-fuites.ahk`](../../tools/test-fuites.ahk) | does what gets drawn a thousand times leave anything behind? |
| [`tools/test-perf.ahk`](../../tools/test-perf.ahk) | is startup fast, is rest silent? |
| [`tools/release.ps1`](../../tools/release.ps1) | builds, tests, checks the resources, packs it all into `dist\Ocre-<version>.zip` and builds the installer |
| [`tools/installer.ps1`](../../tools/installer.ps1) | builds `dist\Ocre-<version>-setup.exe` with Inno Setup (fetched by winget if missing) |
| [`.github/workflows/release.yml`](../../.github/workflows/release.yml) | on a tag: builds, gets it signed (SignPath), publishes the release; [`.signpath/`](../../.signpath/) describes its artefacts |
| [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) | on every change: tests, build, the installer's install / update / roll-back round trip, the docs' links |
| [`tools/outils-ci.ps1`](../../tools/outils-ci.ps1), [`tools/archive.ps1`](../../tools/archive.ps1) | the pinned build chain (versions and hashes); the `.zip` archive, shared with `release.ps1` |
| [`tools/test-installateur.ps1`](../../tools/test-installateur.ps1) | plays the test installer -- install, update, roll back -- without elevation, on dummy keys |
| [`tools/liens.ps1`](../../tools/liens.ps1) | do the links in the Markdown files lead anywhere? |
| [`tools/captures.ps1`](../../tools/captures.ps1) | regenerates the screenshots in `docs/img`, in both languages |
| [`docs/`](../../docs/) | this documentation (`en`, `fr`) and its screenshots (`img`) |
| [`installer/`](../../installer/) | the installer's Inno Setup script, and `utilisateur.ps1`, what it sets in the user's own account (startup task, `Win+Ctrl+C`) |
| [`tools/sign.ps1`](../../tools/sign.ps1) | signs `Ocre.exe` and the installer, when there is a certificate |
| [`tools/test-soleil.ahk`](../../tools/test-soleil.ahk) | checks the solar calculation against another implementation |
| [`tools/sonde-ecrans.ahk`](../../tools/sonde-ecrans.ahk) | what Ocre sees of your screens, without changing anything |
| [`tools/test-clamp.ahk`](../../tools/test-clamp.ahk) | checks that the ramp is not clamped |
| [`tools/test-courbe.ahk`](../../tools/test-courbe.ahk) | checks the curve and the scheduler, without hardware |
| [`tools/sonde-touches.ahk`](../../tools/sonde-touches.ahk) | which keys actually reach Windows |
| [`tools/sonde-luminosite.ahk`](../../tools/sonde-luminosite.ahk) | is the brightness key visible to software |
| [`recherche/`](../../recherche/) | the native Night Light: codec, CLI, registry backups |
