# What Ocre does instead

[← Ocre](../../README.md#documentation) · [Français](../fr/how-it-works.md)

A gamma ramp, through `SetDeviceGammaRamp`. It applies instantly and depends
on no service.

The usual objection is that Windows clamps the amplitude of ramps. That is
true by default, and it can be **turned off**:

```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM
  GdiIcmGammaRange  (REG_DWORD)  =  256
```

A new logon is required afterwards. `install.ps1` takes care of it.
[`tools/test-clamp.ahk`](../../tools/test-clamp.ahk) checks that the requested ramp
is applied as is, by reading it back after writing.

## The curve

[`lib/Gamma.ahk`](../../lib/Gamma.ahk) starts from Tanner Helland's approximation
(colour temperature to RGB) with two corrections:

- **Normalisation.** At 6500 K the raw model returns (255, 254, 250), a warm
  residue at zero intensity. We divide by this reference so that 0 % is
  exactly the identity.
- **Extension.** The model plateaus: at 1200 K it still leaves green at 0.34,
  below the native Night Light at full strength. Beyond 60 % intensity, green
  is pushed down further, to 0.15. Below that, the rendering remains that of
  a true colour temperature.

The filter can only remove light: the higher the intensity, the darker the
screen. That is inherent to the method.

## Every screen

`GetDC(0)` gives the context of the whole desktop, but a ramp set on it only
affects the primary screen: on a two-screen machine, the external monitor
would stay blue while the laptop turns ochre. Ocre therefore enumerates the
displays attached to the desktop with `EnumDisplayDevices`, opens one context
per screen and sets the same ramp on each. A screen that refuses it -- some
external monitors have no gamma table -- does not deprive the others of the
filter.

The contexts stay open from one write to the next: reopening them on every
notch would cost more than the ramp itself, and the wheel asks for several
dozen per second. The watchdog closes them when the number of screens
changes.

**The same ramp everywhere is not always what you want, though.** A laptop
panel and an external IPS do not share the same native temperature: at 60 %
one turns orange while the other stays yellow, and no single setting suits
both. A *Set each screen separately* toggle then gives each its own intensity
and brightness.

It **only appears when there is something to choose**. On a single-screen
machine the question has no object, and a pointless toggle steals height
from a window that has none left. Plug in a second screen, reopen the
settings: the section is there, with a selector naming each monitor. Unplug
it, it goes away -- the setting stays written and becomes active again at the
next connection.

Once separated, a shortcut has to apply somewhere, and the two gestures do
not mean the same thing: **on the keyboard** you adjust the screen of the
active window, the one you are looking at; **with the wheel** the one it
hovers, since the hand is already there. The badge follows, and shows on the
screen concerned rather than always on the primary -- an answer that appears
behind you is no answer.

Recognising a screen from one session to the next needs a stable identifier.
It is the monitor's `DeviceID`, of the form
`MONITOR\ACR0429\{4d36e96e-...}\0001`, which carries the manufacturer code
and model read from the EDID; the numeric suffix separates two identical
units. Neither the `HMONITOR` nor the `\.\DISPLAY1` name will do: both change
with connections.

## Brightness

The ramp can also darken: a factor applied identically to the three channels,
so without shifting the hue. On a laptop it is a good method, because it
takes the screen **below the backlight minimum**, which the hardware cannot
do -- useful at night, when the lowest brightness is still too much.

On a desktop monitor it is the wrong one. The backlight stays at full and we
only crush the levels: black stops being black, contrast collapses. That is
the problem Twinkle Tray and Monitorian solve, and the only serious criticism
one could make of Ocre's slider.

The two complement each other instead of competing:

```
    100 %  ......  the hardware at full
      |            we lower the backlight
     25 %  ......  the hardware at its floor
      |            the gamma ramp takes over
      0 %  ......  as dark as this machine can go
```

Two mechanisms depending on the screen, with nothing in common. **DDC/CI**
(`dxva2.dll`) talks to the monitor over the video cable: it is the only way
for an external screen, and it is slow -- around fifty milliseconds per
write, where the wheel would ask for several dozen per second. Writes are
therefore batched over 120 ms, as the configuration file writes already
are. **WMI** (`WmiMonitorBrightnessMethods`) drives a laptop's built-in
panel; it is the same path as the Windows slider, hence the same setting: the
value found at startup is recorded and restored on exit, exactly like the
ramp.

The hardware floor is not the advertised minimum but a tenth of the range
above it. On many panels, zero switches the backlight off outright -- and a
black screen takes with it the control that would let you come back up. The
remaining tenth is rendered by the ramp, which itself never goes below 0.30
for the same reason.

The laptop's Fn keys and the Windows slider write the same value as Ocre. So
Ocre reads it back, every ten seconds and before quitting, and compares it to
what it last set. If it moved, someone else did it: Ocre **adopts** the
change -- its brightness slider realigns on it instead of overwriting it at
the next gesture -- and, on exit, only restores the morning's value if its own
is still in place. Restoring the morning's value over a setting made by hand
during the day was a surprise. Two units of tolerance absorb monitors that
round what they are written, without which 58 read back for 57 written would
pass for an external setting, be adopted, rewritten, read back, endlessly.
The read-back only happens if someone touched the keyboard or mouse since
the previous round: an Fn key is a key, the Windows slider takes a mouse,
and a DDC read costs thirty to a hundred milliseconds of I2C bus that some
monitors dislike being subjected to without pause.

A monitor with no brightness table, a driver that refuses, a corporate policy
that closes WMI: the slider then falls back on the ramp alone, and covers its
whole range with it. The bottom of the slider always means *as dark as
possible*, whatever the machine.
[`tools/sonde-ecrans.ahk`](../../tools/sonde-ecrans.ahk) tells you what yours can
do, without changing anything.

## And in HDR

Two Windows modes ignore the gamma table, for the same reason. In **HDR**,
Windows composes in 10- or 16-bit floating point and **no longer consults the
gamma table**: `SetDeviceGammaRamp` succeeds, and does nothing. Ocre would
set its ramp, the icon would tint, the badge would say "60 %" -- and the
screen would stay blue. The worst case for an application of this kind: a
silent failure.

The ramp multiplies each channel by a coefficient. **A compositor colour
matrix does exactly the same thing** -- that is the Magnification API, the
one Windows uses for its accessibility filters -- and the compositor also
runs in HDR. When a screen is in HDR, the tint therefore goes through this
matrix ([`lib/Compositeur.ahk`](../../lib/Compositeur.ahk)) instead of the ramp.
Measured in SDR, both paths give the same result to the digit: a white under
60 % is (255, 188, 133) either way. Grey is composed there by matrix
product.

Two things to know. The effect is **full screen**: in HDR, per-screen
settings apply to all, at the value of the screen being looked at. And in
HDR the compositor works in linear light where the ramp multiplied encoded
values: the coefficient is raised to the power 2.2 so that 60 % in HDR looks
like 60 % in SDR. That exponent is the theoretical value of the sRGB curve;
it has not yet been measured on a lit HDR screen.

Detection ([`lib/Hdr.ahk`](../../lib/Hdr.ahk)) deserves a word, because the first
API tried **lies**. `GET_ADVANCED_COLOR_INFO` (Windows 10) reports "advanced
colour active" for HDR as well as for automatic colour management (ACM),
which Windows 11 enables on its own on wide-gamut panels -- and which leaves
the ramp intact. On the development machine: flag at 1, HDR off, Ocre works.
Trusting it would have switched people for whom the ramp works perfectly
well over to the compositor. `GET_ADVANCED_COLOR_INFO_2` (Windows 11 24H2)
distinguishes SDR, WCG and HDR; that is the one we read. On an older Windows
we conclude "not HDR", and the `voie = compositeur` key in `ocre.ini` forces
the path by hand.

And WCG, the *automatic colour management* Windows 11 enables on its own on
wide-gamut panels? The ramp works there. We believed the opposite for a
while, and switched Ocre to the compositor as soon as WCG was on: the mouse
cursor, which the compositor's matrix does not touch, stayed white, and the
tint was weaker than with the ramp -- the compositor composes in linear under
WCG without the 2.2 exponent being applied. Measured by eye since: under
WCG, a (1; 0.3; 0) ramp set with `SetDeviceGammaRamp` tints the screen very
visibly. `Hdr.RampeIgnoree` therefore only switches in true HDR; in doubt,
the `voie` key of `ocre.ini` settles it by hand.

## The darkroom

A cousin of f.lux's *Darkroom* mode: the image rendered on the red channel
only. What is dark stays black, what is light turns red, and the screen only
emits the light that least disturbs dark-adapted vision. With applications in
dark mode, that is red text on a black background -- the intended effect,
and nothing else.

f.lux also inverts the image. That was designed for white backgrounds, which
became black; on applications that are already dark, the inversion does the
opposite of the goal, every black background turning bright red -- and
photos go negative. Ocre does not invert.

It is one more matrix set by the compositor (`Compositeur.CHAMBRE`), and a
session state: no shortcut, no box in the settings, no key in `ocre.ini`, and
a session always opens in colour. Only one line of the right-click panel
leads into it and out of it. Brightness keeps darkening; grey has nothing
left to do and is not composed.

## Forcing the filter back

A full-screen game, a wake from sleep or a colour-mode change can wipe out
the compositor effect, which the watchdog does not monitor the way it does
the ramp. Three things restore it: the `WM_DISPLAYCHANGE` family of messages
call `Filtre.Forcer`, which clears the HDR/WCG detection and the compositor
cache before reapplying; a **Reapply** button, next to the greyscale box,
does the same by hand; and `Ocre.exe /gris` toggles grey alone, handy for a
quick check.

## Watchdog

Windows resets the ramp by itself after a wake from sleep, a resolution
change, a UAC prompt or the exit of a full-screen game.

Three of these four cases announce themselves, and Ocre listens rather than
waits: `WM_DISPLAYCHANGE` for resolution and screen connections,
`WM_POWERBROADCAST` for sleep, `WM_WTSSESSION_CHANGE` for locking and session
switching. The ramp is then back within the millisecond. Since the driver
has not always finished reconfiguring the display when the message arrives,
it is set a second time 1.2 s later: one write too many costs nothing, one
too early is lost.

That leaves the UAC prompt, which announces nothing. A poll every 10 seconds
covers it, and now serves only for that.
