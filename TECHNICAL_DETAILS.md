# Technical Details

## Root cause

AltServer 1.7.2 calls the macOS private API:

```objc
[AOSUtilities retrieveOTPHeadersForDSID:@"-2"]
```

On macOS 27 build `26A5353q`, AOSKit logs error `-45070` and returns an
empty dictionary. AltServer then throws a missing value error for
`X-Apple-MD-M`, surfaced as `machineID`.

## Compatibility layer

`AltServerAnisetteFix.dylib` is loaded from inside the signed app bundle via:

```text
@executable_path/../Frameworks/AltServerAnisetteFix.dylib
```

Its constructor loads AOSKit and replaces three class method implementations
with `method_setImplementation`:

| Method | Replacement source |
| --- | --- |
| `retrieveOTPHeadersForDSID:` | `AltServerAnisetteHelper` child process |
| `machineSerialNumber` | `serialNumber` in `RemoteAnisetteUser.json` |
| `machineUDID` | `deviceID` in `RemoteAnisetteUser.json` |

The OTP replacement launches `AltServerAnisetteHelper` as a child process and
reads a JSON dictionary from standard output. This process boundary keeps
networking and persistent identity management out of the injected library.

## Device identity consistency

AltServer reads the device serial and UDID from AOSKit separately from the OTP
headers. Both of those calls still succeed on macOS 27 and return the host
Mac's real values, so replacing only `retrieveOTPHeadersForDSID:` leaves
AltServer pairing a `machineID` minted for the provisioned identity with the
host's own serial and UDID. The outbound request then describes two different
machines.

The serial and UDID replacements read the persisted identity directly rather
than launching the helper again, since `serialNumber` and `deviceID` are fixed
for the lifetime of the identity. That keeps the cost at one child process per
anisette fetch.

If `RemoteAnisetteUser.json` is missing or unreadable, both replacements call
through to the original AOSKit implementation, so behavior before the first
successful provision is unchanged.

## V3 provisioning

The helper implements the public anisette V3 message sequence using
Foundation:

1. Fetch Apple provisioning endpoints from `gsa.apple.com`.
2. Open a WebSocket to `/v3/provisioning_session`.
3. Exchange identifier, `spim`, `cpim`, `ptm`, and `tk` messages.
4. Store the returned `adi_pb` personalization data locally.
5. POST the saved identity to `/v3/get_headers` for fresh headers.

CryptoKit SHA-256 is used to derive the local user identifier from random
bytes. No Apple Account credentials are inputs to this flow.

The default endpoint is `ani.sidestore.zip`, which is listed by SideStore as
an official recommended server. Provisioning and header requests are retried
up to three times to tolerate short-lived network or WebSocket failures. The
endpoint can be overridden with `ALTSERVER_ANISETTE_SERVER_URL` when running
the helper directly.

## Header mapping

The helper returns current `X-Apple-I-*` headers. The compatibility layer
adds the two legacy aliases consumed by AltServer 1.7.2:

```text
X-Apple-MD-M <- X-Apple-I-MD-M
X-Apple-MD   <- X-Apple-I-MD
```

No other AltServer behavior is patched.

## Build and signing

- Helper: Swift, Foundation, CryptoKit
- Compatibility library: Objective-C, Foundation, Objective-C runtime
- Target architecture: `arm64`
- Distribution signature: ad-hoc
- App integrity: recursive `codesign --verify --deep --strict`
- Payload integrity: SHA-256 manifest
