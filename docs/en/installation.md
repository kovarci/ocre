# Installation

[← Ocre](../../README.md#documentation) · [Français](../fr/installation.md)

## The installer

The easy way: `Ocre-<version>-setup.exe`, from the GitHub Releases. One
double-click, a wizard, and Ocre installs like any other application — in
Program Files, with a Start menu shortcut, an entry in Settings > Apps to
remove it, and, optionally, launch at sign-in. It sets `GdiIcmGammaRange`
(that HKLM key is why it asks for elevation) and turns off `Win+Ctrl+C` (see
below); uninstalling stops Ocre cleanly, removes the startup task and
restores `Win+Ctrl+C`. To update, run the next version over this one: Ocre is
stopped and replaced, your settings stay.

Silently, for a rollout:

```
Ocre-<version>-setup.exe /VERYSILENT /TASKS="demarrage,filtres"
```

Until the installer is signed, Windows shows "Windows protected your PC": see
"SmartScreen" below.

### Rolling back

Before touching Windows, the installer records what it is about to change, in
`C:\Program Files\Ocre\sauvegarde\`:

- `avant-installation.reg`: the original registry values
  (`GdiIcmGammaRange`, `HotkeyEnabled`). Double-click it — or use the Start
  menu shortcut "Ocre - restore the original Windows settings" — and Windows
  is back to how it was, Ocre installed or not. A value that did not exist
  reads `"name"=-`: it is deleted.
- `avant-installation.ini`: the same, for the uninstaller.

It works value by value, never a whole key: exporting a key would also
overwrite what you have changed since. The recorded state is the one from
**before the first install**; an update does not rewrite it.

Uninstalling gives back only what the install really changed — if
`GdiIcmGammaRange` was already 256 it leaves it alone — and only if the value
is still the one the install set: what another tool has set since is not
Ocre's to touch. The `sauvegarde\` folder goes with the rest.
`tools/test-installateur.ps1` plays all of it (install, update, uninstall,
four starting states) without elevation, on dummy keys.


## Without the installer

Two ways: the `Ocre-<version>.zip` archive from the GitHub Releases — the
executable, `install.ps1` and the licences, nothing to build —, or the whole
repository, where `install.ps1` builds the executable if it is missing
(AutoHotkey v2 and its compiler are fetched as needed). Either way, from the
unzipped or cloned folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

**Run as administrator the first time**, to set `GdiIcmGammaRange` if it is
missing (an HKLM key). The logon scheduled task itself needs no elevation;
only replacing a task left by a previous version does, and the script says so
when that happens.

The script also disables `Win+Ctrl+C`, the Windows colour-filter shortcut,
which collides with `Ctrl+F7` on some laptops (see below);
`install.ps1 -Uninstall` restores it.


## Why a scheduled task rather than a shortcut

A shortcut dropped in the Startup folder is only launched by Explorer once
the shell is ready, behind the whole queue of other startup items. Measured
on a laptop loaded with manufacturer services:

| | |
|---|---|
| Windows starts at | 06:34:59 |
| Ocre launched at | 06:35:45 |
| gap | **46 seconds** |

While the application initialises in 0.35 s. The delay therefore does not
come from it. `StartupDelayInMSec` was already 0: it is not the configurable
Windows delay either, but the serialisation of startup items.

A task triggered at logon escapes that queue. Creating it requires
elevation; without it, `install.ps1` automatically falls back on the
shortcut, which works but remains subject to the same delay.

`Ocre.exe` is standalone: once built, neither AutoHotkey nor the compiler is
needed to use it. `-Build` forces regeneration of the icon and
recompilation; `-Uninstall` removes the startup shortcut and stops the
application; `-Test` runs the tests.


## SmartScreen

On first launch on someone else's machine, Windows shows "Windows protected
your PC". That is not Ocre: it is the fate of any **unsigned** executable
SmartScreen has never heard of, and a compiled AutoHotkey exe gets it more
than most — some antivirus products even quarantine it, the interpreter
having served enough bad purposes. *More info > Run anyway* gets past it.

The proper answer is a **code signature**. `tools/sign.ps1` signs `Ocre.exe`
(SHA-256, timestamped) with a code-signing certificate found in the user's
store or in a PFX, and `install.ps1 -Build` calls it on its own when it
finds one. The certificate itself is not made here:
[SignPath Foundation](https://signpath.org) signs open-source projects for
free from their GitHub repository — provided the project has the verifiable
reputation they ask for, and builds from GitHub Actions (see the *Code signing
policy* in the README); Microsoft's Artifact Signing (formerly Trusted Signing)
costs a few euros a month after identity verification, but is, as far as we
know, open only to organisations in the US, Canada, the EU and the UK and to
individuals in the US and Canada — check Microsoft's page; a classic OV
certificate about two hundred euros a year. `-SelfSigned` makes a test one that convinces nobody
but verifies the chain.
