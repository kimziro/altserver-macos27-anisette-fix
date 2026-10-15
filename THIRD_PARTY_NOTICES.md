# Third-party notices

## v1.3.0 source-only prerelease (2026-10-15)

The candidate follows [AltStore PR #1834](https://github.com/altstoreio/AltStore/pull/1834) at `ddb4415cc6aeeb3145de33a29f7064292a45d895` and pins [AltSign PR #61](https://github.com/rileytestut/AltSign/pull/61) at `832d9cec339ea6ef6891011833dbb7227b028a29`.

**Binary distribution is blocked.** The pinned AltSign tree statically links `libcorecrypto_static.a`; its [License.txt](https://github.com/rileytestut/AltSign/blob/832d9cec339ea6ef6891011833dbb7227b028a29/Dependencies/corecrypto/License.txt) states Apple Internal Use only and prohibits redistribution. The v1.3.0 prerelease scope is source patches, pinned upstream references, and result documentation only. Do not include or distribute an app, DMG, static library, or other binary built with that restricted component unless the build/review team resolves this exact restriction. This notice does not grant permission to redistribute or to ignore the license.

The candidate uses `ani.jkcoxson.com` for Windows ADI anisette v3. That service is an external dependency: it handles anisette identity provisioning and related v3 requests and can observe connection metadata. The candidate source sends Apple Account credentials and 2FA codes only to Apple. See [SECURITY.md](SECURITY.md) for the data-flow summary.

## Historical v1.2.0 material

The v1.2.0 app was based on official AltServer 1.8.1/build 98 from the [AltStore CDN](https://cdn.altstore.io/file/altstore/altserver/1_8_1.zip); its archive SHA-256 was `8f48728c64ad776580939ce05ee99e979d457226fb82b1d42f95a8c1bd73e3c1`. Its local compatibility source in [`compatibility/v1.2.0/`](compatibility/v1.2.0/) is distributed under [GNU AGPL v3.0](LICENSE). That older package did not use remote anisette.

Older v1.0.8/v1.0.9 source and documentation describe a separate V3 fallback. They are retained as history and do not describe the v1.3.0 candidate. AltStore, SideStore, Apple, and other product names identify upstream software only; this project is not endorsed by them.
