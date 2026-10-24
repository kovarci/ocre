# Contributing to Ocre

Thanks for looking. Ocre is small on purpose — **no network access, no account, nothing
that runs without you asking** — and contributions that keep to that are welcome:
bug reports, fixes, translations, tests, documentation.

Issues and pull requests can be written in **French or English**.

## Before you start

- **A bug?** Open an issue using the form. Paste the output of **Settings > About >
  Copy diagnostic** (or `Ocre.exe /diag`): it has the version, Windows build and screens,
  and no personal data.
- **A feature?** Open an issue first, describing the *problem* rather than the solution.
  The program has a lot of settings already; the answer is sometimes "a better default".
- **A security problem?** Do not open an issue: see [SECURITY.md](SECURITY.md).

## Setting up

You need [AutoHotkey v2](https://www.autohotkey.com/) (`winget install AutoHotkey.AutoHotkey`)
and PowerShell. Nothing else to run from source:

```powershell
git clone https://github.com/kovarci/ocre
cd ocre
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" .\Ocre.ahk
```

| To do this | Run |
|---|---|
| Run the whole test suite | `powershell -ExecutionPolicy Bypass -File .\tools\test.ps1` |
| Build `Ocre.exe` (no install, no registry) | `.\install.ps1 -Build -NoStart -NoStartup -NoRegistry` |
| Build the installer (needs Inno Setup, fetched by winget) | `.\tools\installer.ps1` |
| Play the installer's install / update / rollback | `.\tools\test-installateur.ps1` |
| Do all of it and produce `dist\` | `.\tools\release.ps1` |

The tests open Ocre's own windows on the desktop for about twenty seconds and write
screenshots to `%TEMP%\ocre-test-ui`; they never touch your real settings (see the top of
each `tools/test-*.ahk`).

## Conventions

- **Comments are in French, in plain ASCII** (no accents) — the whole code base is.
  Explain the *why*, especially for anything that looks odd: most oddities here are the
  scar of a real bug, and the comment says which.
- **Only `lib/I18n.ahk` carries accents**, and must stay UTF-8 *with* BOM (see
  [.editorconfig](.editorconfig)). Every user-visible string goes there, in **both**
  languages — a missing key is a test failure.
- **A setting** is a key in `Config.DEFAUTS` (`lib/Config.ahk`) with a default; it is read
  at the moment it is used, so editing `ocre.ini` by hand works.
- **A test** goes in `tools/test-*.ahk`: pure computation in `test-courbe`/`test-soleil`/`test-cli`,
  windows in `test-ui`, leaks in `test-fuites`. Keep the style of the existing ones —
  `Verifier("what is true", condition, detail)`.
- **Look before you change Windows.** Anything that writes to the registry, the scheduled
  tasks or the display driver must be undoable, and the installer's rollback
  (`installer/Ocre.iss`) must know about it.

## Pull requests

Small and focused is easier to review. Describe the problem the change solves; the
template has a short checklist. Add a line to the `Unreleased` section of
[CHANGELOG.md](CHANGELOG.md).

By contributing you agree that your work is released under the project's
[MIT licence](LICENSE), and you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
