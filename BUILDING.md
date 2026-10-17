# Historical v1.3.1 release

## Current v1.3.2 setup

The current experimental setup includes Mac1.8-pr1834-public-v1.3.2 / 183402 and iPhone2.3.1 / 6402, complete corresponding source and licenses. Use the [v1.3.2 release](releases/v1.3.2.md) and [installation guide](docs/START-HERE.md). Rebuild from the complete source asset using packaging/v1.3.2/build-setup.sh with Xcode27 on Apple silicon; packaging/v1.3.2/REBUILD-IOS.md records dependency pins and source recovery. No recipient credentials, private signing keys, pairing records or runtime anisette identity are included. The pre-existing nested AltBackup.ipa contains its public upstream provisioning profile. The external provider and private-system-API dependency remain; automatic DNS/security changes are not performed.

The sections below describe earlier releases and their state at the time.


The current experimental release includes `AltServer-v1.3.1-macOS27-arm64.dmg` for macOS 27 arm64, app version `1.8-pr1834-public-v1.3.1`, build `183401`. It is ad-hoc signed and not notarized. The corresponding-source archive passed independent source and restricted-material review, and a clean extracted-source build succeeded. See [v1.3.1 notes](releases/v1.3.1.md) for verified artifact hashes and validation limits.

# Historical v1.3.0 build (source-only release, 2026-10-15)

The v1.3.0 package is not an installable build. Its candidate app is Classic-source-based (`1.8-pr1834-test/1834`), follows AltStore PR #1834 head `ddb4415cc6aeeb3145de33a29f7064292a45d895`, and pins AltSign PR #61 at `832d9cec339ea6ef6891011833dbb7227b028a29`. The source-only release contains pinned upstream references, local patch sources, and result documentation, including `compatibility/v1.3.0/README.md`. Its source archive is `AltServer-v1.3.0-diagnostic-source-only.tar.zst`; `SHA256SUMS.txt` records the source archive SHA-256 for download verification only.

**Do not create or distribute a v1.3.0 app/DMG from this candidate yet.** The locally tested candidate statically links `libcorecrypto_static.a`, whose [pinned license](https://github.com/rileytestut/AltSign/blob/832d9cec339ea6ef6891011833dbb7227b028a29/Dependencies/corecrypto/License.txt) states Apple Internal Use only and prohibits redistribution. No alternative implementation is assumed here. A binary build/release remains blocked until the build/review team resolves this exact restriction. No binary download checksum is available; `SHA256SUMS.txt` verifies the source archive only.

The candidate uses Windows ADI anisette v3 from `ani.jkcoxson.com`, matching that provider's `client_info` and User-Agent. Smoke testing established that the required Windows identity fields were returned; the maintainer later reported sign-in and all three apps refreshing while the iPhone was connected by USB. This is user-reported, does not determine the transport used in earlier tests, and does not establish wireless or broad compatibility. See [release notes](releases/v1.3.0.md), [security notes](SECURITY.md), and [upstream provenance](UPSTREAM_SOURCE.md).

## Historical build instructions: v1.2.0

These instructions describe only the historical v1.2.0 app bundle built from official AltServer 1.8.1/build 98. They do not build the v1.3.0 candidate. The project package version `v1.2.0` is separate from the AltServer bundle version.

The patch source and synthetic tests are in [`compatibility/v1.2.0/`](compatibility/v1.2.0/).

## Requirements

- macOS with Xcode Command Line Tools (`xcrun clang`) and ripgrep (`rg`)
- Official AltServer 1.8.1 archive from the [AltStore CDN](https://cdn.altstore.io/file/altstore/altserver/1_8_1.zip)

Verify the downloaded archive before building:

```sh
shasum -a 256 /path/to/1_8_1.zip
stat -f '%z' /path/to/1_8_1.zip
```

Expected SHA-256: `8f48728c64ad776580939ce05ee99e979d457226fb82b1d42f95a8c1bd73e3c1`

Expected size: `13748146` bytes.

## Build the app

Run from the repository root. The output app path must not already exist:

```sh
mkdir -p out/v1.2.0
./compatibility/v1.2.0/build.sh \
  /path/to/1_8_1.zip \
  "$PWD/out/v1.2.0/AltServer.app"
```

The script checks the input bundle ID, version/build, Developer ID team, strict signature, and official main-executable SHA-256 before patching. It compiles the hook as a universal `arm64`/`x86_64` dylib, runs the synthetic getter tests, injects the dylib into a copy of the official app, and ad-hoc signs the result while retaining the official `allow-jit` entitlement. It verifies both architectures' original AltServer `__TEXT` contents are unchanged and checks that the dylib install name is the generic `@rpath/80045ClientInfoGetter.dylib`. The script does not launch the app or create the DMG.

The hook checks the Objective-C getter ABI before installing, retries briefly while the target class is absent, and fails closed on an ABI mismatch. It changes only `ALTAnisetteData.deviceDescription` to:

```text
<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>
```

The setter, other anisette fields, local provisioning path, and iPhone authentication flow are unchanged. No remote helper or endpoint is added. Synthetic tests check the getter result, another field, setter behavior, and ABI-mismatch rejection.

## Verify the built app

```sh
codesign --verify --deep --strict out/v1.2.0/AltServer.app
shasum -a 256 \
  out/v1.2.0/AltServer.app/Contents/MacOS/AltServer \
  out/v1.2.0/AltServer.app/Contents/Frameworks/80045ClientInfoGetter.dylib
otool -D out/v1.2.0/AltServer.app/Contents/Frameworks/80045ClientInfoGetter.dylib
```

Expected distribution hashes:

- `AltServer`: `8fcfac3b8d68adddc151bf920d82b32df3a8202e75e6753952e07f21dbb982eb`
- `80045ClientInfoGetter.dylib`: `ba72c0fc7bb65bfa0175d0fc29ff49fcd322f6e23ade47acd179ae137a1d1875`
- Install name: `@rpath/80045ClientInfoGetter.dylib`

These identify the reviewed distribution build; they do not claim byte-for-byte identity across build toolchains. The final distribution copy was read back, passed deep strict signature verification, started successfully, and logged that the getter hook was installed. Its AltServer executable `__TEXT` matched the tested app for both architectures; the dylib install name was sanitized to the generic `@rpath/80045ClientInfoGetter.dylib`. The live Refresh All evidence is from the installed test build described in the release notes; no additional three-app refresh is claimed for the distribution copy. Assemble and checksum the DMG separately. The app is ad-hoc signed and not notarized; do not disable Gatekeeper or SIP.

## Historical pipeline

The root-level `scripts/build_release.sh`, `scripts/Install.command`, `scripts/Restore.command`, and `src/AnisetteHelper/` are the older v1.0.8/v1.0.9 V3 fallback pipeline for AltServer 1.7.6/build 94. They are not used by this build. See [CHANGELOG.md](CHANGELOG.md) for its history.
