# v1.3.0 compatibility diagnostic (source-only prerelease)

## Scope

This is a source-only diagnostic note for the AltServer 80045 / Anisette
compatibility investigation. It is not an official release announcement and
does not include an app, DMG, upstream source tree, or Apple corecrypto code.

## Verification recorded

- Upstream AltStore commit: `ddb4415cc6aeeb3145de33a29f7064292a45d895`.
- AltSign submodule commit: `832d9cec339ea6ef6891011833dbb7227b028a29`.
- Candidate build label: `1.8-pr1834-test` / `1834`, arm64, macOS target 13.0.
- Candidate executable SHA-256:
  `01f03471f51e2828827978d110da9eeda332420f32080803325e2df31cea2bdf`.
- Local smoke: candidate remained running and loaded OpenSSL.
- End-to-end: user reported Apple ID sign-in completed; later, with the iPhone
  connected over USB, all three installed apps refreshed successfully.

This record summarizes test outcomes; it is not an installable app, signed
release build, or reproducible log. See the source-only package manifest for
limitations.

## Release blocker

The pinned AltSign checkout includes Apple corecrypto under an internal-use
license that prohibits redistribution of the software or portions. The tested
candidate statically links corecrypto. Do not distribute the candidate or a
source archive containing that code unless Apple grants written permission.
Before a public release, remove/replace this dependency with a redistributable
implementation and repeat protocol compatibility, security, and device tests.

## Files for review

The accompanying source-only diagnostic package contains pinned source refs,
the build-only patches, license summaries/notices, and sanitized verification
metadata. It intentionally omits upstream source and all binaries.
