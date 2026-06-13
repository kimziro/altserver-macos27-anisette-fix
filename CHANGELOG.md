# Release Notes

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
