# Security and privacy

## Current v1.3.2 setup

The current experimental setup includes Mac1.8-pr1834-public-v1.3.2 / 183402 and iPhone2.3.1 / 6402, complete corresponding source and licenses. Use the [v1.3.2 release](releases/v1.3.2.md) and [installation guide](docs/START-HERE.md). Rebuild from the complete source asset using packaging/v1.3.2/build-setup.sh with Xcode27 on Apple silicon; packaging/v1.3.2/REBUILD-IOS.md records dependency pins and source recovery. No recipient credentials, private signing keys, pairing records or runtime anisette identity are included. The pre-existing nested AltBackup.ipa contains its public upstream provisioning profile. The external provider and private-system-API dependency remain; automatic DNS/security changes are not performed.

The sections below describe earlier releases and their state at the time.


## Historical v1.3.1 experimental release

The v1.3.1 DMG is for macOS 27 arm64 only, ad-hoc signed, and not notarized. Installation may require **System Settings → Privacy & Security → Open Anyway**; do not disable macOS security. The app uses the external `ani.jkcoxson.com` service for Windows ADI anisette. The service handles anisette requests and can observe connection metadata; service availability and privacy practices affect use. The Apple Account password and 2FA code are sent only to Apple. No real-account login or iPhone refresh was tested with this build. See [v1.3.1 notes](releases/v1.3.1.md).

## Scope

The v1.3.0 source-only release (2026-10-15) has no downloadable app or DMG. It follows the Classic-source-based AltStore PR #1834 and AltSign PR #61 flow and is not a binary patch of official AltServer 1.8.1. The previous v1.2.0 getter-only package later reproduced `-80045` and is not recommended as a fix.

The candidate fetches Windows ADI anisette data from `ani.jkcoxson.com`. The provider provisions and receives a persistent anisette identity through the v3 handshakes; the client stores its identity/ADI data locally, including `adi.pb` material. The provider can observe its connection's IP address and timing. The source sends the Apple Account password and 2FA code only to Apple's authentication endpoint; this does not remove the privacy or availability risk of using a third-party anisette provider. The local persistent identity is stored under `~/Library/Application Support/com.rileytestut.AltServer/RemoteAnisetteWindows/identity.json`.

Never upload or share `identity.json`, `adi.pb`, anisette headers/values, credentials, 2FA codes, device identifiers, or unredacted logs. These files are not release assets. The release is source-only because the candidate statically links upstream corecrypto whose license prohibits redistribution; no binary is included or promised.

## Installation safety

- No v1.3.0 app or DMG is available. Do not treat this source-only release as an installer.
- If evaluating the source, review the pinned upstream commits and third-party license before building or distributing anything.
- Do not share credentials, verification codes, provisioning/identity files, device identifiers, or unredacted logs/screenshots in issue reports.

Candidate testing is limited to one setup. The maintainer reported that all three apps refreshed while connected by USB; that does not establish wireless success or the transport used in earlier tests. It does not establish Apple's policy cause or compatibility on other devices, networks, or accounts. See [release notes](releases/v1.3.0.md).

## Historical material

The repository retains older v1.0.8/v1.0.9 V3 fallback source and documentation and v1.2.0 getter patch history. They are not the v1.3.0 candidate's runtime behavior. See [CHANGELOG.md](CHANGELOG.md) and [UPSTREAM_SOURCE.md](UPSTREAM_SOURCE.md).
