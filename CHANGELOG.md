# Changelog

[English](CHANGELOG.md) | [한국어](CHANGELOG.ko.md)

## v1.3.0 — source-only release (2026-10-15)

- Source-only release for a Classic-source-based app lineage labelled `1.8-pr1834-test/1834`. This is not a patch of the official AltServer 1.8.1 binary.
- Pins the candidate to [AltStore PR #1834](https://github.com/altstoreio/AltStore/pull/1834) head `ddb4415cc6aeeb3145de33a29f7064292a45d895` and [AltSign PR #61](https://github.com/rileytestut/AltSign/pull/61) commit `832d9cec339ea6ef6891011833dbb7227b028a29`.
- Uses Windows ADI anisette v3 from `ani.jkcoxson.com`, with matching `client_info` and User-Agent for GSA. The PR author's explanation of Apple's rejection behavior is a hypothesis, not an independently established policy cause.
- Evidence is limited to one setup: official AltServer sign-in returned `-80045`; the earlier Pixel-descriptor-only experiment returned HTTP 503; the candidate smoke test received all required Windows-identity fields; the maintainer reported sign-in and app refresh. An earlier screen showed YouTube with six days remaining and two other apps with seven; the maintainer later reported all three apps refreshed over USB. This is user-reported; USB does not establish the transport used in earlier tests. Wireless behavior, reboot persistence, and broad compatibility are not established.
- v1.3.0 is a source-only release: no app, DMG, or binary download. Binary distribution is blocked because the locally tested candidate statically links corecrypto whose [pinned license](https://github.com/rileytestut/AltSign/blob/832d9cec339ea6ef6891011833dbb7227b028a29/Dependencies/corecrypto/License.txt) says Apple Internal Use only and prohibits redistribution. Do not ignore this restriction. `SHA256SUMS.txt` contains only the source archive hash for download verification; a separate `verification-manifest.txt` records the tested local executable hash for provenance only. The source archive includes patch notes at `compatibility/v1.3.0/README.md`.

## v1.2.0 — 2026-10-14

- Targets the macOS 27 Apple sign-in/refresh error `-80045`, distinct from the earlier `machineID` issue.
- Updates the packaged official AltServer base from 1.7.6/build 94 to 1.8.1/build 98. The project package version is not the official AltServer app version.
- Changes only the Mac-side `deviceDescription` getter to return an Android client description; the iPhone app, stored anisette fields, provisioning, and sign-in flow are unchanged. No V3 fallback is included.
- An installed test build completed Refresh All for three existing apps on one Apple Silicon Mac running macOS 27; all showed seven days remaining. The final distribution app passed strict signature verification and launch checks, but a second three-app refresh was not claimed. USB/Wi-Fi was not established; remote anisette, reboot, new login/2FA, Intel, other devices/accounts, and broad compatibility were not tested. See [release notes](releases/v1.2.0.md) and [build notes](BUILDING.md).
- The maintainer later reported that `-80045` recurred on the previously tested setup; the cause is not established, and this patch is not a guaranteed fix.
- A separate environment check confirmed installation and local anisette only; it did not establish refresh behavior or resolve Wi-Fi ServerError 2001.

## Release history

Dates below are GitHub publication dates in UTC for published entries. These are project package releases; the AltServer version is listed separately where documented. The public API currently shows no releases or tags for v1.0.3–v1.0.7 or v1.1.0, so those numbers are not treated as published versions here.

| Project version | Published (UTC) | Official AltServer base | Change and verification record |
| --- | --- | --- | --- |
| v1.3.0 | 2026-10-15 (source-only release) | Classic source lineage `1.8-pr1834-test/1834` | Windows ADI v3 authentication flow; no app/DMG, binary distribution blocked by corecrypto license. |
| [v1.2.0](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.2.0) | 2026-10-14 | 1.8.1/build 98 | `-80045` getter compatibility patch; one Mac/iPhone setup refreshed three apps. Connection type and broader compatibility were not established. |
| [v1.0.9](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.9) | 2026-09-16 | 1.7.6/build 94 | DMG release of the `machineID` V3 fallback; install, launch, provisioning, AltStore install, and refresh were reported on the tested Apple Silicon/macOS 27 setup. |
| [v1.0.8](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.8) | 2026-09-15 | 1.7.6/build 94 | Source-only release of the `machineID` fallback; maintainer-reported install/sideload/refresh testing, with limited independent exact-match validation. |
| [v1.0.2](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.2) | 2026-06-13 | 1.7.2/build 90 (inherited) | Adds Gatekeeper instructions; patched binary unchanged from v1.0.1. No new runtime test is recorded for this documentation release. |
| [v1.0.1](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.1) | 2026-06-13 | 1.7.2/build 90 (inherited) | Streamlines installer distribution and restores the official app from a local backup; patched binary unchanged from v1.0.0. No new runtime test is recorded for this packaging release. |
| [v1.0.0](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.0) | 2026-06-13 | 1.7.2/build 90 | Initial V3 fallback for the macOS 27 `machineID` error, documented for Apple Silicon/macOS 27.0 beta; the release notes do not provide a separate runtime-test result. |

## Historical release details

The detailed v1.0.8/v1.0.9 entries below document the older V3 fallback. They are retained as release history and do not describe v1.2.0 or the v1.3.0 candidate.

## v1.0.9 / v3.8 — completed-app DMG — 2026-09-16

This release adds the completed-app DMG
`AltServer-macOS27-Anisette-Fix-v1.0.9.dmg`. It contains the patched
`AltServer.app` (`1.7.6-macOS27-v3.8`, build 94) for the normal Finder
drag-to-Applications workflow. The app is ad hoc signed and not notarized by
Apple, and drag installation does not create an automatic backup; save the
official app manually when a restore path is needed.

- Fixes the macOS 27 `machineID` fallback regression by canonicalizing the
  `/var`-backed temporary root before private-directory creation while retaining
  `O_NOFOLLOW_ANY` on opened paths.
- Strips inherited `DYLD_*` variables from the private helper's child
  environment before `execve`.
- Anchors helper cleanup to validated directory/file descriptors and device,
  inode, owner, and path identity checks before `unlinkat`/`rmdir`.
- Verifies the completed app's install, launch, anisette provisioning, AltStore
  install, and refresh runtime on the tested Apple Silicon/macOS 27 setup.
- Keeps the official AltServer 1.7.6/build 94 authentication and the public V3
  provisioning protocol unchanged; this is a Mac-side runtime fix only.
- The Git source tree remains source, scripts, references, and documentation;
  the historical v1.0.8 publication was source-only.

## v1.0.8 / v3.7 — source-only publication — 2026-09-15

This release follows v1.0.2 in the existing GitHub repository. It publishes
source, build/transaction scripts, and documentation only. No modified
`AltServer.app`, installer archive, app-bearing payload ZIP, IPA, provisioning
profile, certificate, or other binary asset is published.

- Targets the macOS 27 `machineID` failure observed with official AltServer
  1.7.6/build 94 while preserving the official universal main executable.
- Calls the official AOSKit anisette path first and invokes the arm64 helper
  only for a non-dictionary, missing/empty, partial/incomplete, or conflicting
  alias response. The dylib has no GSA, GrandSlam, User-Agent, or AltSign hook.
- Keeps the official 1.7.6 HTTP 503/modern AuthKit handling and AltXPC fallback;
  these remain upstream behavior, not local hooks.
- Builds the helper and dylib for native Apple Silicon `arm64`; Rosetta is
  rejected. The helper uses the public anisette V3 protocol and the default
  `https://ani.sidestore.zip` service.
- Verifies official input provenance (archive SHA-256, TeamIdentifier,
  universal executable, Developer ID signature, Gatekeeper assessment, and
  notarization ticket) before local injection. The output is ad hoc signed and
  not notarized.
- Adds deterministic nonzero `LC_UUID` derivation and validation after linking,
  signing, ZIP extraction, and installer validation. This addresses a macOS 27
  loader requirement and does not change the `machineID` decision or official
  GSA/GrandSlam path.
- For the historical source-only workflow, produced four private local build
  files under `out/v1.0.8`: the app-bearing
  payload ZIP, executable manifest, metadata, and checksums. The repository
  does not publish those files; a stale pre-existing output must be rebuilt.
- Records source/worktree provenance and pins the Objective-C source, Swift
  client, Swift entry point, build script, Install.command, and Restore.command
  hashes. Binary-affecting dirty trees require explicit source attestation and
  immutable source snapshots.
- Uses dedicated ephemeral/sanitized URLSession settings: cookies, credential
  storage, cache, and inherited additional headers are disabled or cleared.
  HTTPS/WSS redirects stay on the same secure origin, and network messages are
  capped at 1 MiB.
- Uses root-only Install/Restore transactions with non-root read-only dry runs,
  canonical backup paths, descriptor-bound identity checks, a shared root lock,
  and exact target/process matching. Backups remain restorable after success.
- Keeps the iPhone boundary explicit: no patched IPA or `AltSign-Dynamic` is
  included; use the official AltStore install and refresh flows.
- Maintainer testing covered install, sideload, and refresh on the current
  macOS 27/iOS 27 environment. Independent exact-match validation remains
  limited.
- Documents that no exact public Git commit mapping for official 1.7.6/build 94
  can be proven; PR #1790 and commit `c558994` are context only.

## v1.0.2 — 2026-06-13 (historical)

- Documented the per-script Gatekeeper **Open Anyway** flow.
- Linked Apple's official English and Korean guidance.
- Clarified that Gatekeeper and SIP must not be disabled globally.
- Made no change to the patched AltServer implementation.

- The release notes do not report a new runtime test; this release records an installation-documentation change only.

## v1.0.1 — installer packaging — 2026-06-13

- Makes the installer smaller, removes duplicate source and bundled original-app copies, and restores the official app from the local backup created before install.
- The patched binary is unchanged from v1.0.0. No new runtime test is reported for this packaging release.

## v1.0.0 — initial V3 fallback — 2026-06-13

- Targets the macOS 27 `machineID` anisette error with a Foundation-based client using the public V3 provisioning protocol; based on official AltServer 1.7.2/build 90.
- Release notes document Apple Silicon and macOS 27.0 beta as the compatibility scope, plus install and restoration scripts. They do not report a separate runtime-test result, so none is inferred here.

## Public development milestones (not releases)

- The 2026-09-14 [v1.0.8 preparation commit](https://github.com/kimziro/altserver-macos27-anisette-fix/commit/6f372b0) records release preparation; that commit itself is not a published release or tag.
- The 2026-09-15 UTC [README simplification commit](https://github.com/kimziro/altserver-macos27-anisette-fix/commit/c2647c6) is a documentation change, not an app-binary release.

Earlier release notes are historical context only. They are not instructions
for installing the v1.3.0 candidate.
