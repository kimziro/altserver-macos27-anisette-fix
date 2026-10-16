# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

## v1.3.1 experimental prerelease — macOS 27, Apple silicon only

[**Download AltServer v1.3.1 for macOS 27 (arm64) — DMG**](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.3.1/AltServer-v1.3.1-macOS27-arm64.dmg)

Installation: drag AltServer into Applications. If macOS blocks it, open **System Settings → Privacy & Security → Open Anyway**. Do not disable macOS security.

This experimental prerelease is ad-hoc signed and not notarized. Requires macOS 27 and arm64 (Apple silicon). It uses the external anisette service `ani.jkcoxson.com`; availability and privacy depend on that service. The Apple Account password and 2FA code are sent only to Apple.

The app is based on AltStore Classic [PR #1834](https://github.com/altstoreio/AltStore/pull/1834) (`ddb4415`) and [AltSign PR #61](https://github.com/rileytestut/AltSign/pull/61) (`832d9ce`). Version `1.8-pr1834-public-v1.3.1`, build `183401`. This build removes the bundled Apple static corecrypto library and restricted headers, using macOS system private SRP through an opaque interface with CryptoKit/CommonCrypto. This describes the build contents; it makes no broader legal determination.

Protocol tests passed 5/5, including PBKDF2 vectors, invalid CBC padding, GCM AAD tampering, and malformed SRP. An independent handshake accepted valid M2, rejected bad M2, and matched the session key exactly. App build, launch, and Windows-identity smoke checks passed. No fresh-build real-account login or iPhone refresh was tested; earlier USB refresh success applies to v1.3.0 only. See [v1.3.1 notes](releases/v1.3.1.md) and [security notes](SECURITY.md).

This project is independent and not affiliated with or endorsed by AltStore, SideStore, or Apple. Source is licensed under [GNU AGPL v3.0](LICENSE).
