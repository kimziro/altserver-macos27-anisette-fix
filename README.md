# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

An experimental macOS 27 sign-in investigation based on AltStore Classic source. **v1.3.0 is a source-only prerelease (2026-10-15); there is no app or DMG.** It is not an official AltServer update. The earlier v1.2.0 app is not recommended: `-80045` recurred.

## What changed

The v1.2.0 package changed only the anisette device-description getter and later reproduced `-80045`. The v1.3.0 candidate changes the Mac sign-in flow to fetch Windows ADI anisette data from `ani.jkcoxson.com` and send its matching client identity and User-Agent. This is more than changing a descriptor string. See [release notes](releases/v1.3.0.md), [security notes](SECURITY.md), and [upstream details](UPSTREAM_SOURCE.md).

## Test scope

In the test, the official app returned `-80045`; the earlier Pixel-descriptor build returned HTTP 503. The v1.3.0 candidate's anisette smoke test received all required Windows-identity fields. The maintainer reported signing in and refreshing apps. An earlier screen showed YouTube with six days remaining and two other apps with seven; the maintainer later reported all three apps refreshed while connected by USB. This is limited user-reported evidence: USB does not establish the transport used in earlier tests, and wireless behavior, reboot persistence, Apple's cause, and broad compatibility remain unverified.

The candidate follows [AltStore PR #1834](https://github.com/altstoreio/AltStore/pull/1834) and [AltSign PR #61](https://github.com/rileytestut/AltSign/pull/61). It is a Classic-source-based app labelled `1.8-pr1834-test/1834`, not a binary patch of official AltServer 1.8.1. Binary distribution is blocked by the upstream [corecrypto license](https://github.com/rileytestut/AltSign/blob/832d9cec339ea6ef6891011833dbb7227b028a29/Dependencies/corecrypto/License.txt), which says Apple Internal Use only and prohibits redistribution. The source-only prerelease has no DMG, app, or binary download. No binary release is promised. The source archive includes patch notes at `compatibility/v1.3.0/README.md`.

## Version history

Project package versions are separate from the bundled AltServer version.

| Project version | Summary |
| --- | --- |
| v1.3.0 (2026-10-15 source-only prerelease) | Classic-source-based sign-in flow using matching Windows ADI anisette identity and User-Agent. No app/DMG; binary distribution blocked. |
| v1.2.0 | AltServer 1.8.1/build 98 with a getter-only compatibility change; `-80045` later recurred. |
| v1.0.9 | DMG release of the older `machineID` V3 fallback. |
| v1.0.8 | Source-only release of the older `machineID` V3 fallback. |

Earlier v1.0.8/v1.0.9 V3 fallback documentation is historical and does not describe this candidate. This independent project is not affiliated with or endorsed by AltStore, SideStore, or Apple. Source is licensed under [GNU AGPL v3.0](LICENSE).
