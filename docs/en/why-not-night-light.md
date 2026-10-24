# Why Ocre does not use the Windows Night Light

[← Ocre](../../README.md#documentation) · [Français](../fr/why-not-night-light.md)

That was the original plan, and it failed for a reason worth documenting,
because it invalidates every existing tool on recent builds.

Night Light has no API. Its setting is persisted in two `REG_BINARY` values
under `HKEY_CURRENT_USER`, in **Microsoft Bond CompactBinary v1** format
wrapped in a **CloudStore** envelope. All the community literature states
that writing these values applies the setting immediately.

**This is no longer true since Windows 11 25H2 (build 26200).** Measured on
an Acer Aspire 14 AI, 25H2 build 26200.9168:

| Observation | Consequence |
|---|---|
| This repository's codec produces **exactly the same bytes** as Windows for a given temperature | the format is correctly understood |
| Settings reads back the written value (the slider follows) | the write succeeds |
| The on-screen rendering does not change | the engine does not re-read the registry |
| "Turn off now" does **not even** write the state key | the live state no longer lives in CloudStore |

Tried without success: writing the temperature alone, rewriting the state
key with a fresh timestamp, an off/on cycle with delays from 120 ms to 2.5 s,
and the "adjustment in progress" flag (field 70) that the UI raises while the
slider is being dragged.

Conclusion: on these builds, the registry is a persistence remnant, read at
logon and never again.

Cross-check the other way round, by switching Night Light on then off by
hand from quick settings while watching the keys:

| Key | Content | Written |
|---|---|---|
| `Store\...\Cloud\...state` | a timestamp alone, no state | on every toggle |
| `Store\...\Current\...state` | "forced ON" dated two days earlier | touched on toggle, **content unchanged** |
| `Store\...\Current\...settings` | schedule, temperature | never |

Windows therefore records *that* a toggle happened, not *which*. That is why
Ocre cannot see a Night Light switched on by hand (see
[the banner](settings.md#when-a-windows-filter-adds-up)).

The codec remains in [`recherche/`](../../recherche/): it is correct, tested, and
still lets you **preset** Night Light for the next logon.
