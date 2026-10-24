# Troubleshooting

[← Ocre](../../README.md#documentation) · [Français](../fr/troubleshooting.md)

## If the screen stays warm

The ramp does not belong to the application: it is a global state of the
graphics driver. Ocre restores it on exit, but an "End task" in the task
manager lets nothing run, and the screen keeps its tint with no visible
control to undo it.

```
Ocre.exe /reset
```

flattens the screen and stops Ocre.


## If the shortcuts do not answer

On many laptops (Acer notably), the **Fn-lock** is in multimedia mode: `F5`
and `F6` trigger brightness at firmware level and never reach Windows. No
script can intercept them in that state.

- **`Fn` + `Esc`** on most Acers, or
- BIOS (`F2` at boot) > **Main** > **Function key behavior** > **Function key**

Brightness then moves to `Fn+F5` / `Fn+F6`.

Careful when reassigning a key: on these same machines, `Ctrl+F7` triggers
screen projection at firmware level, which the capture records as `Win+P`.
The *Reset* button restores the six original shortcuts.

### If the screen turns grey when Ocre switches off

That is not Ocre: it is the Windows **colour filter** (Accessibility >
Colour filters), in greyscale mode. While Ocre is on, the ochre masks it; as
soon as it switches off, the grey shows.

It turns on because Windows gives it a shortcut, `Win+Ctrl+C`, active by
default. The firmware of these same laptops injecting a Win key into `Fn+F7`
combinations, Ocre's toggle fires both at once. `install.ps1` disables that
shortcut — the filter itself stays available in Settings for whoever uses
it. By hand:

```
HKCU\Software\Microsoft\ColorFiltering
  HotkeyEnabled  (REG_DWORD)  =  0
```

### True black, for OLED panels

On an OLED screen a black pixel is off, and a very dark grey pixel is on.
Yet almost no application writes black: Notion's and Discord's dark mode is
`#191919` (level 25 of 255), VS Code's `#1E1E1E` (30), Spotify's `#121212`
(18). On a panel that can do true black, all of that is a uniform grey
glow — and the screen's infinite contrast goes to waste.

The **True black (OLED)** toggle in the settings sends every level at or
below a threshold to pure black, and stretches what is above so that white
stays white. It is the same gamma ramp as the filter, hence the same
mechanism, changes nothing in the applications, and it **follows the filter**
like grey does: `Ctrl+F7` takes it away with the tint, as a fade — the
threshold goes down step by step with the intensity — and brings it back
with it. Notion, Discord, VS
Code, the terminal and Explorer turn black at once, everywhere. The
threshold moves in steps of 4, from 4 to 64; 28 by default, which catches
Notion and Discord (25) and spares VS Code (30) — 32 catches them all.
Each extra step crushes the shadows of photos and films a little more: that
is the price, and it shows from 40 on. In HDR, where the ramp is ignored,
the same operation goes through the compositor's matrix, with the threshold
converted to linear light.

In `ocre.ini`, `noir` is the threshold in force (0 = off) and `noir_seuil`
the one you get back when switching it on again; `/get` returns `noir=`.
The watchdog guards it like the rest of the ramp: it reads back the entry
at the threshold, which must be zero.

### Grey, coupled to the filter

Some people read in the evening in grey **and** warm: grey removes the colour
that catches the eye, warm removes the blue that keeps you awake. A *Turn the
screen greyscale along with the filter* toggle makes grey follow the filter:
on as soon as Ocre is, off with it. A single command sets both states, and
that is what keeps them from drifting apart — the original problem.

Driving the Windows filter was tried and dropped, measurements in hand. Its
`Active` key is not re-read live: once written, it changes nothing before the
next toggle in Settings. Its shortcut goes through `atbroker.exe`, which
refuses as soon as the shortcut is disabled — and it must be disabled, that
is the previous paragraph.

Ocre therefore sets **its own** grey, through the Magnification API
(`MagSetFullscreenColorEffect`), which is the mechanism Windows itself uses
underneath: a colour matrix applied to the whole desktop by the compositor.
It is instant, registry-free, and **the effect belongs to the process**: an
"End task" gives the screen back its colour, where the Windows filter would
have stayed.

One trap, which cost an hour and deserves to be written down. `DllCall` loads
a DLL, calls, then **unloads** it if nothing else holds it — that is
documented. `MagInitialize` ran, the library was released along with its
state, and the next call landed on a pristine library:
`ERROR_INVALID_FUNCTION`, with no further explanation, while the same call
from Python succeeded. An explicit `LoadLibrary`, held for the life of the
process, fixes everything ([`lib/Compositeur.ahk`](../../lib/Compositeur.ahk)).

## Reporting a problem

Open **Settings > About… > Copy diagnostic** (or run `Ocre.exe /diag` and copy what it
prints) and paste it in a [new issue](https://github.com/kovarci/ocre/issues/new/choose).
It holds the versions of Ocre and Windows, the screens, whether the gamma safeguard is
lifted, whether another colour tool runs, and the state of the settings that matter — no
user name, nothing personal. With it, most reports can be answered without a round trip of
questions. If Ocre showed an error box, `erreurs.log` in `%APPDATA%\Ocre` (the
*Settings folder* button of the About window opens it) has the stack.