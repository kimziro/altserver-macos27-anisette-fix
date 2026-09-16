# Security and Privacy

The v1.0.9 release uses a completed-app DMG,
`AltServer-macOS27-Anisette-Fix-v1.0.9.dmg`, containing the patched
`AltServer.app` (`1.7.6-macOS27-v3.8`, build 94). The repository source tree
contains source, scripts, references, and documentation only. The earlier
v1.0.8 / v3.7 publication is historical and source-only; it did not contain an
app or installer asset.

The v1.0.9 release asset contains the patched app binary but excludes
`RemoteAnisetteUser.json`, Apple ID/Apple Account email, passwords and
two-factor codes, device identifiers, provisioning profiles, certificates,
IPAs, and other private user data. The app is ad hoc signed and not notarized
by Apple, so a Gatekeeper warning is expected. Follow the safe Finder **Open
Anyway** flow in [README.md](README.md); never disable Gatekeeper or SIP, and
never use `xattr` commands to bypass them. Direct drag-and-drop installation
does not create an automatic backup; save the official app yourself first if
you may need to restore it.

## Threat model

The patch addresses one macOS 27 failure: AOSKit can return no usable
`machineID` headers. It does not bypass Apple Account authentication, alter
Apple's signing requirements, or secure a remote anisette operator. AltServer
and AltStore continue to perform their normal Apple authentication and device
flows.

## Data that is stored

The helper persists only a personalized V3 identity in:

```text
~/Library/Application Support/AltServer/RemoteAnisetteUser.json
```

The file is created with permission mode `0600` and is not included in local
build output or the v1.0.9 DMG. Treat it as sensitive device identity data. The
helper does not store an Apple ID/Apple Account email, password, session
cookie, two-factor code, or authorization header.

The identity is opened relative to an owner-checked support-directory descriptor.
The `AltServer` support directory is owner-owned and mode `0700`; the identity
entry must be an owner-owned regular file with exactly mode `0600` and one hard
link. The identity open uses no-follow and nonblocking flags, so symlinks, FIFOs,
and other non-regular entries are rejected; reads are bounded to 64 KiB and the
file identity is checked again after reading. New identities use a unique `0600`
exclusive temporary file, `fsync`, and exclusive publication, so concurrent
provisioning cannot replace an existing entry. If an existing identity fails
these checks, it is rejected rather than reused; after reviewing or quarantining
that file, a fresh provisioning run may be required.

## Apple Account prompts

An install or refresh can trigger Apple's normal **Apple Account Sign-In
Requested** alert and a six-digit verification code. Approve only an alert you
initiated when the displayed account is yours. Enter the code only in the
AltStore or AltServer prompt. Choose **Don't Allow** for an unsolicited alert.
The compatibility helper never receives or sends that code to an anisette
service.

Never put Apple Account credentials, two-factor codes, screenshots containing
codes, anisette headers, or `RemoteAnisetteUser.json` in an issue, chat, or
support log.

## Network boundary

The helper contacts:

- `https://gsa.apple.com/grandslam/GsService2/lookup` for Apple provisioning
  URLs, with `User-Agent: akd/1.0 CFNetwork/808.1.4`.
- The configured V3 server, default `https://ani.sidestore.zip`, for
  `/v3/provisioning_session` over WSS and `/v3/get_headers` over HTTPS.

The GSA lookup belongs to the helper's provisioning flow. The injected dylib
does not hook or rewrite the official GSA/GrandSlam/User-Agent/AltSign
authentication path.

The helper uses a dedicated URLSession configuration. It is ephemeral, disables
cookie creation and acceptance, removes cookie storage, disables URL
credential storage, clears inherited additional headers, and disables the URL
cache. HTTPS and WSS URLs must have a host, use no userinfo, and remain on the
same secure scheme, host, and effective port across redirects. HTTP responses
and WebSocket messages are capped at 1 MiB; transient operations retry up to
three times.

A remote V3 operator can process the personalized identity and anisette
headers required by the protocol. Use only a service you trust, or change the
source and rebuild for a service you operate. HTTPS/WSS transport does not make
an untrusted operator trustworthy.

## Code-injection and transaction checks

`DYLD_INSERT_LIBRARIES` is set to the relative in-bundle path
`@executable_path/../Frameworks/AltServerAnisetteFix.dylib`. Before launching
the helper, the dylib verifies its embedded SHA-256 and strict Security
signature, copies it to an owner-private immutable temporary path without
following links, and runs it with `fork`/`execve`. It caps stdout and stderr at
1 MiB each (2 MiB total) and enforces a 15-second deadline.

The installer validates the payload ZIP, manifest, metadata, checksums, bundle
metadata, architecture, symlinks, executable modes, recursive signature, and
exactly one valid nonzero `LC_UUID` on helper and dylib before dry-run success
or any write to `/Applications` or Application Support. Install and Restore
are root-only for real transactions, use descriptor-bound identity checks and a
shared root lock, and target only `/Applications/AltServer.app`.

## Reporting safely

When reporting a problem, include only a short redacted error, architecture,
macOS major version, AltServer version/build, and the failed step. Remove or
redact Apple Account data, device names/serials/UDIDs, local usernames and home
paths, backup names, anisette headers/tokens, identity files, IP/location data,
and identifying timestamps. Do not upload an unredacted log, screenshot, or
account prompt.

## Limitations

- The v1.0.9 DMG app is ad hoc signed and not notarized by Apple.
- A macOS or AltServer update can change private framework behavior.
- Availability and behavior of the configured V3 service are outside this
  repository's control.
- The patch covers the Mac-side `machineID` path only; on-device transport and
  later AltStore refresh failures may require an official update.
