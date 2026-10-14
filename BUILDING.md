# Building v1.2.0

This guide builds the v1.2.0 app bundle from an independently downloaded official AltServer 1.8.1/build 98 archive. The project package version `v1.2.0` is separate from the AltServer bundle version.

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
