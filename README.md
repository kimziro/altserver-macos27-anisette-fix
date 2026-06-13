# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

An unofficial compatibility build for AltServer 1.7.2 on macOS 27 when app
installation fails with:

```text
AltServer could not retrieve anisette data value "machineID".
```

[Download the latest release](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/latest)

## Release Files

- `AltServer-macOS27-Anisette-Fix-v1.0.1.zip`: installer, restore script,
  bilingual documentation, and patched AltServer payload
- `AltServer-macOS27-Anisette-Fix-v1.0.1-source.zip`: corresponding source,
  including the referenced AltStore upstream snapshot
- `SHA256SUMS.txt`: SHA-256 hashes for both archives

## Compatibility

- Apple Silicon Macs (`arm64`)
- macOS 27.0 beta
- Based on AltServer 1.7.2, build 90

This project was tested on macOS 27.0 build `26A5353q`.

## Installation

1. Download `AltServer-macOS27-Anisette-Fix-v1.0.1.zip` from
   [Releases](https://github.com/kimziro/altserver-macos27-anisette-fix/releases).
2. Extract the archive.
3. Right-click `Install.command` and choose **Open**.
4. Open AltStore on the iPhone and refresh your apps.

If AltStore is already installed on the iPhone, **do not reinstall it**.
Installing the patched AltServer on the Mac is enough. In AltStore, open
**My Apps** and use **Refresh All**, or refresh the affected app individually.
Reinstall AltStore only if it is missing or no longer opens.

The installer backs up the currently installed official AltServer before
replacing it. Run `Restore.command` from the same archive to restore that
local backup. If no valid backup exists, download the official AltServer from
[altstore.io](https://altstore.io).

Do not disable Gatekeeper or SIP globally.

## Apple Account Verification

During an installation or refresh, a trusted Apple device may show an
**Apple Account Sign-In Requested** alert. If it appears immediately after
you started the operation in AltStore:

1. Check that the displayed Apple Account is yours.
2. Tap **Allow**.
3. Enter the displayed six-digit verification code only in the prompt shown
   by AltStore or AltServer.

This is part of AltServer's normal Apple Account authentication flow, not an
extra sign-in introduced by this compatibility fix. The compatibility helper
does not receive or send the verification code to the anisette V3 server.

If you did not initiate an installation or refresh, tap **Don't Allow**.
Never share the verification code, screenshots containing it, or anisette
headers in a GitHub issue, chat, or support request. The approximate location
shown in Apple's alert is IP-based and may differ from your physical
location.

## What It Does

AltServer 1.7.2 asks the private macOS `AOSKit` framework for anisette
headers. On macOS 27, that call returns error `-45070` and an empty dictionary,
so AltServer cannot obtain `X-Apple-MD-M`.

This project:

1. Loads a small compatibility library from inside the AltServer app bundle.
2. Replaces only `AOSUtilities.retrieveOTPHeadersForDSID:` at runtime.
3. Runs a separate Foundation-based helper that implements the public
   anisette V3 protocol.
4. Maps the generated V3 headers to the legacy keys expected by AltServer.

The rest of AltServer's signing, installation, and device communication logic
is unchanged.

See [TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md) for the full implementation
overview.

## Privacy

The compatibility helper does **not** send your Apple Account email,
password, session cookies, or two-factor authentication codes to the
anisette server. AltStore and AltServer still communicate with Apple as part
of their normal account authentication and app-signing flow.

It connects to:

- `https://gsa.apple.com` for Apple's provisioning endpoints
- `wss://ani.sidestore.zip/v3/provisioning_session`
- `https://ani.sidestore.zip/v3/get_headers`

A personalized V3 device identity is stored locally at:

```text
~/Library/Application Support/AltServer/RemoteAnisetteUser.json
```

The file is created with permission mode `0600`. It is not included in release
archives and should not be shared.

Read [SECURITY.md](SECURITY.md) before using a public anisette server.

## Build From Source

Requirements:

- Apple Silicon Mac
- macOS 27 Command Line Tools
- An original AltServer 1.7.2 application

```bash
chmod +x scripts/build_release.sh
./scripts/build_release.sh /path/to/original/AltServer.app
```

The output is ad-hoc signed. See [BUILDING.md](BUILDING.md) for details.

## Verification

Every release includes a `SHA256SUMS.txt` file covering the installer and
corresponding source archives. The release package has been tested
for:

- recursive code-signature validation
- clean first-time V3 provisioning
- reuse of the same personalized V3 identity
- restoration of the original AltServer
- reinstallation of the patched AltServer
- absence of local usernames, personal certificates, and identity files

## Limitations

- This is an unofficial and non-notarized build.
- The helper binary is currently `arm64` only.
- AltServer updates may overwrite the compatibility build.
- macOS beta updates may change private framework behavior again.
- Availability depends on the configured anisette V3 server.

## Credits

- [AltStore](https://github.com/altstoreio/AltStore)
- [SideStore RemoteAnisette](https://github.com/SideStore/RemoteAnisette),
  used as a protocol reference
- [anisette-v3-server](https://github.com/Dadoum/anisette-v3-server),
  used as a protocol reference

No RemoteAnisette source file is redistributed in this repository.

## License

This project and the modified AltServer distribution are provided under the
[GNU Affero General Public License v3.0](LICENSE).

This repository is not affiliated with or endorsed by AltStore, SideStore, or
Apple.
