# Security policy

## Supported versions

Only the [latest release](https://github.com/kovarci/ocre/releases/latest) receives
fixes. Ocre is small and releases are cheap: please update before reporting.

## Reporting a vulnerability

**Do not open a public issue.** Use GitHub's private reporting instead:

1. Go to the [Security tab](https://github.com/kovarci/ocre/security) of the repository.
2. Choose **Report a vulnerability**.
3. Describe what you found, how to reproduce it, and what an attacker gains.

This is a one-person project, maintained in spare time. Expect an acknowledgement
within about a week, and a fix or a clear answer after that. You will be credited in
the release notes unless you prefer otherwise.

## What is in scope

Ocre runs as your normal user and opens **no network connection**. The parts that
deserve scrutiny are therefore local:

- **The installer** (`Ocre-<version>-setup.exe`): it runs elevated, writes to
  `C:\Program Files\Ocre` and to `HKLM`, and registers a scheduled task. Anything that
  lets a less-privileged user turn that into code execution as an administrator is in
  scope (for example, a writable path that an elevated step later runs or reads).
- **The scheduled task and the files it launches.**
- **The command line and the inter-process message** used by `Ocre.exe /set`, `/quit`,
  and so on: anything that lets another local process do more than the documented
  commands.
- **The build and release pipeline** (`.github/workflows/release.yml`,
  `tools/outils-ci.ps1`): supply-chain weaknesses, unpinned downloads, tampered
  artefacts.

## What is not

- The Windows SmartScreen warning on files that are not (yet) code-signed. It is
  documented in the [README](README.md#smartscreen) and is not a vulnerability.
- Antivirus products flagging a compiled AutoHotkey executable. Please report those
  to the vendor as false positives; the source is public.
- Anything that requires administrator rights you already have.

## Checking a download

Every release published by the workflow carries a `SHA256SUMS.txt`. Compare it with:

```powershell
Get-FileHash .\Ocre-1.3.0-setup.exe -Algorithm SHA256
```

Once the project is signed, `Get-AuthenticodeSignature` will also report the signature
(see "Code signing policy" in the [README](README.md#code-signing-policy)).
