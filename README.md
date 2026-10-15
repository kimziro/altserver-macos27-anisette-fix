# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

Fixes the Apple sign-in and app refresh error `-80045` on macOS 27.

## Download v1.2.0

[Download AltServer-macOS27-Anisette-Fix-v1.2.0.dmg](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.2.0/AltServer-macOS27-Anisette-Fix-v1.2.0.dmg)

## Install

1. Quit AltServer.
2. Before replacing it, copy your current app somewhere safe. Open the DMG, drag `AltServer.app` to **Applications**, and choose **Replace**.
3. Double-click the app in Applications. If macOS blocks it, follow the Gatekeeper steps below.

> **Gatekeeper:** This unofficial app is ad-hoc signed and not notarized by Apple. A warning is expected. Double-click it once first; the **Open Anyway** button may not appear until after this first attempt. If blocked, go to **System Settings → Privacy & Security → Open Anyway**, then confirm **Open**. Do not disable Gatekeeper or SIP globally.

## What it fixes

- It updates the Mac app to AltServer **1.8.1 (build 98)**. `v1.2.0` is this project's package version.
- This is a Mac-only fix. It does not change the iPhone app or require reinstalling AltStore.

If AltStore is already on your iPhone, do not reinstall it. Turn **Prefer Remote** off when refreshing through this Mac app. If separately testing wireless refresh, put the Mac and iPhone on the same Wi-Fi network; wireless behavior has not been verified for this release.

## Tested scope

On 2026-10-14, an installed v1.2.0 test build on one Apple Silicon Mac running macOS 27 completed Refresh All for three existing apps; all three showed seven days remaining. No visible error or 2FA prompt appeared. This does not establish wireless, remote anisette, reboot, new-login/2FA, Intel, or universal compatibility.

## Version history

These are this project's package versions, separate from the official AltServer app version.

| Project version | Summary |
| --- | --- |
| v1.2.0 | AltServer 1.8.1/build 98; `-80045` getter compatibility fix. |
| v1.0.9 | `machineID` V3 fallback packaged as a DMG. |
| v1.0.8 | Source-only release of the `machineID` V3 fallback. |
| v1.0.2 | Gatekeeper installation guidance. |
| v1.0.1 | Simplified installer and local-backup restore flow. |
| v1.0.0 | Initial V3 fallback, based on AltServer 1.7.2/build 90. |

See [CHANGELOG.md](CHANGELOG.md) for dates, per-release changes, verification scope, and limits.

The app is ad-hoc signed and not notarized. Read [SECURITY.md](SECURITY.md) before installing. See [release notes](releases/v1.2.0.md), [build notes](BUILDING.md), [upstream provenance](UPSTREAM_SOURCE.md), [third-party notices](THIRD_PARTY_NOTICES.md), and [CHANGELOG.md](CHANGELOG.md). The older [installation guide](INSTALLATION.md) and [technical details](TECHNICAL_DETAILS.md) describe the v1.0.8/v1.0.9 V3 fallback, not this release.

This independent project is not affiliated with or endorsed by AltStore, SideStore, or Apple. Source is licensed under [GNU AGPL v3.0](LICENSE).
