# Security and privacy

## Scope

The v1.2.0 app is an ad-hoc-signed, non-notarized build based on official AltServer 1.8.1/build 98. The Mac-side compatibility change adds no network service or account-data export. AltServer's normal Apple sign-in and device communication remain unchanged.

No iPhone app is patched. The compatibility change does not read or transmit Apple Account credentials, verification codes, or provisioning files. The ordinary AltServer/AltStore flow may still display Apple's normal sign-in or verification prompts.

## Installation safety

- Download only from the project's [v1.2.0 release](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.2.0) and verify the DMG against the release's `SHA256SUMS.txt`.
- Save a copy of the current official app before replacing it; dragging into Applications does not make a backup.
- The app is not notarized. Use Finder's **Open Anyway** flow only if you choose to proceed. Never disable Gatekeeper or SIP globally or use shell commands to bypass them.
- Do not share credentials, verification codes, provisioning/identity files, device identifiers, or unredacted logs/screenshots in issue reports.

The patch changes Mac-side client information, not Apple's authentication policy. A successful refresh on one setup does not guarantee compatibility on other devices, networks, or accounts. See [release limits](releases/v1.2.0.md).

## Historical material

The repository retains older v1.0.8/v1.0.9 V3 fallback source and documentation. Those files describe a different implementation and are not part of the v1.2.0 app's runtime behavior. See [CHANGELOG.md](CHANGELOG.md) and [UPSTREAM_SOURCE.md](UPSTREAM_SOURCE.md).
