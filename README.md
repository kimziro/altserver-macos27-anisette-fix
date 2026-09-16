# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

An unofficial compatibility patch for the macOS 27 error:

```text
AltServer could not retrieve anisette data value "machineID".
```

## [⬇️ Download from the v1.0.9 release](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.0.9/AltServer-macOS27-Anisette-Fix-v1.0.9.dmg)

The link becomes available when the v1.0.9 release is published.
Download the completed-app asset `AltServer-macOS27-Anisette-Fix-v1.0.9.dmg`
from the v1.0.9 release.
It contains the patched `AltServer.app` for the Mac-side fix.

## Install (3 steps)

1. **Quit AltServer.**
2. **Open the DMG and install.** Double-click the DMG, then drag
   `AltServer.app` to **Applications**. If macOS asks to replace an existing
   app, choose **Replace**. Optional: copy your current official app to a safe
   folder first; drag-and-drop installation does not create an automatic backup.
3. **Open it through Finder.** In Applications, Control-click `AltServer.app`,
   choose **Open**, then confirm **Open**.

> **Gatekeeper:** This app is unofficial, ad-hoc signed, and not notarized by
> Apple, so a warning is expected. If macOS blocks it, attempt once to open it,
> then go to `System Settings → Privacy & Security → Security → Open Anyway → Open`.
> macOS may ask for your Mac login password. **Never disable Gatekeeper or SIP,
> and never use `xattr` commands to bypass them.**

## Compatibility and scope

- Apple Silicon Mac running macOS 27.
- Bundled Mac app version `1.7.6-macOS27-v3.8` (build 94).
- The patch changes only the Mac-side anisette path. AltStore 1.8.0 on iPhone
  may still show a `machineID` error when paired with the official Mac AltServer.
  This DMG replaces only Mac AltServer; it does not replace the AltStore app or
  the iPhone transport.

## After installation

1. Launch AltServer and confirm its icon appears in the menu bar.
2. Connect and trust your iPhone.
3. Use **Install AltStore…** for a first install, then use **Refresh** when
   needed. Network access is required the first time anisette data is
   provisioned.

## Restore and updates

To restore the official app, quit AltServer, remove or move the patched
`AltServer.app` from Applications, then restore an official app you saved
manually. If you have no saved copy, [redownload the official AltServer
1.7.6 archive](https://cdn.altstore.io/file/altstore/altserver/1_7_6.zip).

macOS or AltServer updates can overwrite this patch; reinstall the DMG if the
workaround stops working. This project is unofficial and is not affiliated with
or endorsed by AltStore, SideStore, or Apple.

## Privacy and security

Anisette provisioning data can be sensitive. Use only a service and network you
trust, and read [SECURITY.md](SECURITY.md) before proceeding. Never share Apple
Account credentials or codes, identity files, device IDs, or unredacted logs.

## Advanced and detailed docs

For the source-build workflow and implementation details, see
[BUILDING.md](BUILDING.md), [INSTALLATION.md](INSTALLATION.md),
[TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md), and
[UPSTREAM_SOURCE.md](UPSTREAM_SOURCE.md). The previous v1.0.8 release was
source-only.

- [SECURITY.md](SECURITY.md) — privacy and threat model
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) — dependency notices
- [CHANGELOG.md](CHANGELOG.md) — release history
- [LICENSE](LICENSE) — GNU AGPL v3.0 license for this source
