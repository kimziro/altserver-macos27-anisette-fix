# Security and Privacy

## Threat model

This compatibility layer does not bypass Apple Account authentication. It
only replaces the path AltServer uses to generate the device attestation
headers required during sign-in.

## Stored data

`RemoteAnisetteUser.json` contains a personalized virtual-device identity and
is stored with permission mode `0600`. The helper does not store Apple Account
email addresses, passwords, session cookies, or two-factor authentication
codes.

## Apple Account authentication

AltStore and AltServer still use Apple's normal account authentication flow.
An installation or refresh may cause a trusted Apple device to display an
Apple Account sign-in approval alert and a six-digit verification code.

Approve the alert only when you initiated the operation and the displayed
account is yours. Enter the code only in the prompt shown by AltStore or
AltServer. The compatibility helper does not receive the code or send it to
the anisette V3 service.

Do not post verification codes, screenshots containing codes, Apple Account
credentials, anisette headers, or `RemoteAnisetteUser.json` in public issues.

## Network trust

The default V3 service is SideStore's `ani.sidestore.zip`. If you do not trust
that operator, change `serverURL` in the source to a self-hosted anisette V3
service and rebuild the helper, or set `ALTSERVER_ANISETTE_SERVER_URL` when
running it directly.

## Code injection

`DYLD_INSERT_LIBRARIES` is fixed to a relative path that loads only
`AltServerAnisetteFix.dylib` from inside the AltServer application bundle. The
installer requires the complete bundle to pass code-signature verification.

## Limitations

- The distributed build is not notarized by Apple.
- A macOS or AltServer update may change the internal API and break the fix.
- Header generation will fail while the configured public V3 service is
  unavailable.
