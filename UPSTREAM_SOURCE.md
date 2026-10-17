# Upstream source and provenance

## Current v1.3.2 setup

The current experimental setup includes Mac1.8-pr1834-public-v1.3.2 / 183402 and iPhone2.3.1 / 6402, complete corresponding source and licenses. Use the [v1.3.2 release](releases/v1.3.2.md) and [installation guide](docs/START-HERE.md). Rebuild from the complete source asset using packaging/v1.3.2/build-setup.sh with Xcode27 on Apple silicon; packaging/v1.3.2/REBUILD-IOS.md records dependency pins and source recovery. No recipient credentials, private signing keys, pairing records or runtime anisette identity are included. The pre-existing nested AltBackup.ipa contains its public upstream provisioning profile. The external provider and private-system-API dependency remain; automatic DNS/security changes are not performed.

The sections below describe earlier releases and their state at the time.


## Historical v1.3.1 experimental prerelease

The published app version is `1.8-pr1834-public-v1.3.1`, build `183401`, for macOS 27 arm64. It is ad-hoc signed and not notarized. The source archive is `AltServer-v1.3.1-source.tar.gz`; its download checksum is in `SHA256SUMS.txt` (artifact review pending).

- AltStore Classic [PR #1834](https://github.com/altstoreio/AltStore/pull/1834), pinned head `ddb4415cc6aeeb3145de33a29f7064292a45d895`.
- AltSign [PR #61](https://github.com/rileytestut/AltSign/pull/61), pinned commit `832d9cec339ea6ef6891011833dbb7227b028a29`.
- The app removes the bundled Apple static corecrypto library and restricted headers; it uses macOS system private SRP through an opaque interface, plus CryptoKit/CommonCrypto. This records the implementation contents and makes no broader legal determination.
- Windows ADI anisette comes from external service `ani.jkcoxson.com`. Apple Account credentials and 2FA codes are sent only to Apple.

See [v1.3.1 release notes](releases/v1.3.1.md) for verification and test limits.

## v1.3.0 source-only candidate

The project package version is `v1.3.0` (source-only release, 2026-10-15). The candidate lineage is labelled `1.8-pr1834-test/1834`; it is based on AltStore Classic source, not a patch to the official AltServer 1.8.1 binary. The source-only release contains patch notes at `compatibility/v1.3.0/README.md` and the archive `AltServer-v1.3.0-diagnostic-source-only.tar.zst`. `SHA256SUMS.txt` records the source archive SHA-256 for download verification only.

- [AltStore PR #1834](https://github.com/altstoreio/AltStore/pull/1834), head commit `ddb4415cc6aeeb3145de33a29f7064292a45d895`.
- [AltSign PR #61](https://github.com/rileytestut/AltSign/pull/61), pinned commit `832d9cec339ea6ef6891011833dbb7227b028a29`.
- The sign-in flow obtains Windows ADI anisette v3 from `ani.jkcoxson.com` and uses that provider's matching `client_info` and User-Agent for GSA requests.

The PR author's Apple-rejection explanation is a hypothesis, not an independently established policy cause. The observed sequence is limited to one setup: official AltServer returned `-80045`; the earlier Pixel-descriptor-only experiment returned HTTP 503; the candidate anisette smoke test received the required Windows identity fields; the maintainer reported sign-in and app refresh. An earlier screen showed YouTube with six days remaining and two other apps with seven; the maintainer later reported all three apps refreshed while connected by USB. That report does not establish the transport used in earlier tests, wireless success, or post-reboot behavior.

The locally tested candidate statically links `libcorecrypto_static.a`. Its [pinned upstream license](https://github.com/rileytestut/AltSign/blob/832d9cec339ea6ef6891011833dbb7227b028a29/Dependencies/corecrypto/License.txt) says Apple Internal Use only and prohibits redistribution. Therefore v1.3.0 is source-only; do not package or distribute an app, library, or DMG from this candidate unless the build/review team resolves this exact restriction. This document does not grant permission or suggest ignoring the notice.

No binary asset is supplied. `SHA256SUMS.txt` contains only the source archive hash for download verification. The separate `verification-manifest.txt` records the tested local executable hash for provenance only, not for binary download verification. Do not reuse historical v1.2.0 hashes.

## Historical v1.2.0 official input

The published v1.2.0 app used the official AltServer 1.8.1/build 98 archive distributed by AltStore:

- Download: <https://cdn.altstore.io/file/altstore/altserver/1_8_1.zip>
- Archive size: `13748146` bytes
- Archive SHA-256: `8f48728c64ad776580939ce05ee99e979d457226fb82b1d42f95a8c1bd73e3c1`
- Bundle ID: `com.rileytestut.AltServer`
- Signing team: `6XVY5G3U44`
- Official main executable SHA-256: `39b38f455ba71a8a163a38575c57d81dc1179068bc6fec0a76762c7a303b77df`

The exact public Git commit corresponding to official build 98 was not established. The v1.2.0 local getter patch and reviewed output hashes remain historical and do not identify the v1.3.0 candidate. See [CHANGELOG.md](CHANGELOG.md).
