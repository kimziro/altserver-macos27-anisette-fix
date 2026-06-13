# Release Notes

## v1.0.2 - 2026-06-13

- Documents how to allow `Install.command` through Gatekeeper using System
  Settings > Privacy & Security > Open Anyway.
- Links to Apple's official English and Korean instructions.
- Clarifies that users should not disable Gatekeeper or SIP globally.
- Contains no changes to the patched AltServer binary.

## v1.0.1 - 2026-06-13

- Reduces the installer archive from about 81 MB to about 7 MB.
- Distributes the installer and corresponding source as separate assets.
- Removes the bundled original AltServer application from the installer.
- Restores the official AltServer from the local pre-installation backup.
- Avoids creating duplicate backups when the patched build is reinstalled.
- Uses one `SHA256SUMS.txt` file for all downloadable release assets.
- Includes English and Korean documentation directly in the installer.

## v1.0.0 - 2026-06-13

- Works around the missing anisette `machineID` in AltServer 1.7.2 on macOS
  27.
- Creates a personalized identity through the public anisette V3 protocol.
- Reuses the identity and stores it locally with permission mode `0600`.
- Does not send Apple Account credentials to the anisette service.
- Includes double-clickable installation and restoration scripts.
- Includes ad-hoc code signatures and SHA-256 checksums.
- Includes the complete modification source and upstream commit information.
- Uses the recommended `ani.sidestore.zip` V3 endpoint by default.
- Retries transient provisioning and header-generation failures up to three
  times.
- Documents that an existing AltStore installation does not need to be
  reinstalled when refreshing apps.
- Documents Apple's sign-in approval alert and six-digit verification-code
  flow, including anti-phishing guidance.

Tested with:

- macOS 27.0 beta, build `26A5353q`
- Apple Silicon
- AltServer 1.7.2, build 90
