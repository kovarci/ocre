# The command line

[← Ocre](../../README.md#documentation) · [Français](../fr/command-line.md)

For whatever is not a keyboard: a button box, a macro, a sleep script.

```
Ocre.exe /set 40        sets the intensity          /set +5, /set -5: relative
Ocre.exe /kelvin 3400   sets the temperature (1200 to 6500 K)
Ocre.exe /lum 60        sets the brightness         /lum +5, /lum -5: relative
Ocre.exe /plus          one step warmer
Ocre.exe /moins         one step cooler
Ocre.exe /toggle        off or back on
Ocre.exe /preset nuit   a preset: lecture, film, nuit (reading, movie, night)
Ocre.exe /gris          greyscale, on or off
Ocre.exe /chambre       darkroom, in or out
Ocre.exe /horaire on    scheduler: on, off, or nothing to toggle
Ocre.exe /rappel        makes the icon breathe, as the 20-20-20 reminder does
Ocre.exe /get           state on standard output; exit code = intensity
Ocre.exe /version       the version
Ocre.exe /diag          what a bug report needs: versions, screens, state
Ocre.exe /export f.ini  copies the settings to a file
Ocre.exe /import f.ini  takes the settings from a file, and applies them
Ocre.exe /reset         neutral ramp and stop
Ocre.exe /quit          clean stop
Ocre.exe /help          the list
```

`-set` equals `/set`: both conventions are in use on Windows, and refusing
one for the other teaches nobody anything. The English words are accepted
too: `warmer`, `cooler`, `brightness`, `schedule`, `darkroom`.

`/get` writes one `key=value` per line — intensite, kelvin, luminosite,
coupe, horaire, gris, noir, unite, portable, fichier, separes, and one line per
screen when they are separated — which a script reads effortlessly, and
returns the intensity as exit code for whoever only wants that. Ocre.exe is a
windowed application, not a console one: `cmd` and PowerShell do not wait for
it, the output shows up after the prompt, and the exit code lands neither in
`%ERRORLEVEL%` nor in `$LASTEXITCODE`. To read them, wait for it: `start /wait
Ocre.exe /get` in `cmd`, and in PowerShell `$p = Start-Process .\Ocre.exe /get
-Wait -PassThru -NoNewWindow; $p.ExitCode`.

`/export` and `/import` are the settings window's buttons, taken from the
command line — to roll the same settings out to several machines. A path
does not fit in a message: both work on the file themselves, and `/import`
then tells the running instance that everything changed, language included.
A relative path is relative to the folder the command is run from. A file
without an `[ocre]` section is refused, code 2.

A command that expects a number and gets none — `/set` on its own, `/set
abc` — **does nothing and says so**, exit code 2. It used to be worth zero,
and zero switches the filter off: a badly written macro turned the screen off
in silence.

A command addressed to a live instance is **posted** to it, not applied on
the spot: two processes each setting their own ramp would fight. Broadcasting
avoids having to find the window, which is hidden. That is also why
`#SingleInstance Force` is gone — it would have killed the application to
relaunch it on every command, which gives the right result by the worst
route. The question "am I the first?" is asked of a named mutex.

Without a running instance, `/set` and its neighbours start the application
and then apply; `/reset` simply flattens the screen, which is precisely the
case where it is used.

## Why we cannot hook the brightness key

The idea comes naturally: since F5 lowers brightness, why not tie the filter
to `Ctrl` + that key? Because in multimedia mode the keyboard emits no key
code at all: it fires a command that goes straight to the display driver,
without crossing the keyboard queue.

Measured with [`tools/sonde-luminosite.ahk`](../../tools/sonde-luminosite.ahk),
which listens to the keyboard hook, `WM_APPCOMMAND` and the system hotkeys:
**twenty presses on F5 alone, zero events**. There is nothing to intercept,
with or without a modifier.

## Checking that function keys reach you

Press **`F5` alone** in a browser. If the page refreshes, function keys
reach Windows and the primary set works. If the brightness changes instead,
the Fn-lock is in multimedia mode: the firmware swallows the key before
Windows, and only the fallback set answers. Many laptops reset this mode at
reboot.

The settings live in `%APPDATA%\Ocre\ocre.ini`, next to two logs.
`demarrage.log` notes at what second after power-on Ocre took over, which
distinguishes a slow application from one launched late by Windows.
`erreurs.log` receives every error before it is displayed: Ocre starts with
the session, and a box opened at that moment ends up behind the other windows
or gets closed by reflex. Both are truncated beyond forty lines.

## Portable mode

An `ocre.ini` placed **next to `Ocre.exe`** takes precedence over the one in
`%APPDATA%`, and the logs join it: the application then travels on a USB
stick or in a synced folder with its settings. The file must exist — even
empty — for the mode to engage; it is a choice you make by creating it, not
a behaviour that kicks in on its own. `Ocre.exe /get` says which file is in
use.
