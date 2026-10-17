# AltServer macOS27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

## v1.3.2 experimental setup — Mac + patched iPhone companion

[**Download the ready-to-install DMG — macOS27 / Apple silicon**](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.3.2/AltServer-Setup-v1.3.2-macOS27-arm64.dmg)

No compilation required. Drag AltServer into Applications, quit the older running copy, open the new app and connect/unlock your iPhone by USB. Choose **Install AltStore → your iPhone** from the menu-bar icon. It automatically selects the bundled patched **AltStore2.3.1 / build6402**. Enter your own Apple Account/2FA; use your existing account when replacing AltStore and do not uninstall first.

[Installation guide](docs/START-HERE.md) · [한국어 안내](docs/START-HERE.ko.md) · [Release + complete source](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.2)

**Observed:** the Macv1.3.1 authentication lineage installed AltStore over USB on macOS27.0.1 / iOS27.2. The bundled iPhone client code refreshed with USB+cellular and twice consecutively with USB+Wi-Fi after per-network DNS changed to1.1.1.1/1.0.0.1. v1.3.2 changes the Mac menu to select that companion. Its build/package checks are separate from those prior real-account tests; a new real-account v1.3.2 installation test is not claimed. Other accounts/devices/networks and USB-free refresh remain unverified.

[HTTP503: network comparison and reversible DNS workaround](docs/refresh-http-503.md). [Invalid anisette / issue14 investigation](docs/invalid-anisette.md). [Reddit/GitHub solved and unresolved cases](docs/community-findings.md). **No universal503 fix or confirmed #14 fix is claimed. No iOS hsc434 resync is added.**

Ad-hoc signed, not notarized. If blocked use System Settings → Privacy & Security → Open Anyway for this app. Mac minimum macOS27 arm64; iPhone deployment minimum iOS17.4, tested iOS27.2 only. External ani.jkcoxson.com supplies Windows anisette and can observe connection metadata; Apple Account passwords/2FA go only to Apple. No automatic DNS/security changes. [Security/privacy](SECURITY.md).

Mac version1.8-pr1834-public-v1.3.2 / 183402. Based on [AltStore PR1834](https://github.com/altstoreio/AltStore/pull/1834) (ddb4415) and [AltSign PR61](https://github.com/rileytestut/AltSign/pull/61) (832d9ce). Bundled restricted Apple static crypto and headers are removed; an opaque system private SRP adapter plus CryptoKit/CommonCrypto is used. Complete corresponding source, dependencies, licenses and rebuild scripts accompany the release.

Independent/unofficial project, not affiliated with AltStore, SideStore or Apple. [GNU AGPLv3](LICENSE).
