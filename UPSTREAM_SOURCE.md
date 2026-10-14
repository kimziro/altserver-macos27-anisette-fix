# Upstream source and provenance

## Official AltServer input

The v1.2.0 app is based on the official AltServer 1.8.1/build 98 archive distributed by AltStore:

- Download: <https://cdn.altstore.io/file/altstore/altserver/1_8_1.zip>
- Archive size: `13748146` bytes
- Archive SHA-256: `8f48728c64ad776580939ce05ee99e979d457226fb82b1d42f95a8c1bd73e3c1`
- Bundle ID: `com.rileytestut.AltServer`
- Signing team: `6XVY5G3U44`
- Official main executable SHA-256: `39b38f455ba71a8a163a38575c57d81dc1179068bc6fec0a76762c7a303b77df`

The exact public Git commit corresponding to the official build 98 binary has not been established. Do not claim a commit-level source-to-binary mapping. The project's package version `v1.2.0` is distinct from the bundled AltServer version `1.8.1`/build `98`.

## Local patch and reviewed app

The source is in [`compatibility/v1.2.0/`](compatibility/v1.2.0/). The runtime dylib install name is the generic `@rpath/80045ClientInfoGetter.dylib`; it does not contain a developer checkout path.

Reviewed output hashes:

- Main executable: `8fcfac3b8d68adddc151bf920d82b32df3a8202e75e6753952e07f21dbb982eb`
- Injected dylib: `ba72c0fc7bb65bfa0175d0fc29ff49fcd322f6e23ade47acd179ae137a1d1875`
- Signature: ad-hoc; deep strict verification passed.

The app contains only the Mac-side compatibility change documented in [BUILDING.md](BUILDING.md). It adds no remote V3 fallback helper or endpoint and makes no iPhone-side changes.

## Release lineage

Published v1.0.8/v1.0.9 used AltServer 1.7.6/build 94 and a separate V3 fallback implementation. They are historical and are not the base or runtime behavior of v1.2.0. See [CHANGELOG.md](CHANGELOG.md) for the published release dates.
