# Technical Details

This document describes the local helper/dylib and its boundaries. The
repository source tree contains source, scripts, references, and documentation
only. Historical v1.0.8 / v3.7 was source-only; the v1.0.9 release uses a
completed-app DMG containing the patched `AltServer.app`
(`1.7.6-macOS27-v3.8`, build 94), derived from official AltServer 1.7.6/build
94.

## Root cause and scope

Official AltServer 1.7.6/build 94 includes its HTTP 503/modern AuthKit handling
and official AltXPC fallback. It still asks the private macOS AOSKit API for
anisette headers:

```objc
[AOSUtilities retrieveOTPHeadersForDSID:@"-2"]
```

On the tested macOS 27.0 build `26A5353q`, this call can log `-45070` and return
an empty dictionary. AltServer then lacks `X-Apple-MD-M` (`machineID`).
[AltStore issue #1751](https://github.com/altstoreio/AltStore/issues/1751)
contains a 1.7.6 macOS 27 report. The local code supplements this missing
response; it does not claim to fix every Apple, anisette, or iPhone transport
failure.

## AOSKit compatibility layer

`AltServerAnisetteFix.dylib` is loaded from the app bundle at:

```text
@executable_path/../Frameworks/AltServerAnisetteFix.dylib
```

Its constructor loads AOSKit, locates `retrieveOTPHeadersForDSID:`, and changes
the implementation only after an exact Objective-C type-encoding check. The
official method is always called first.

The response is accepted only when it is a dictionary containing a complete,
coherent, nonempty pair of either:

```text
X-Apple-MD-M / X-Apple-MD
X-Apple-I-MD-M / X-Apple-I-MD
```

Accepted values are canonicalized to both key forms. A non-dictionary,
missing/empty, partial/incomplete, or conflicting alias response invokes the
local helper. Unrelated response fields are preserved when the dictionary can
be copied safely.

## Helper process boundary

The dylib launches `AltServerAnisetteHelper` as a child and reads a JSON header
dictionary from standard output. Before `fork`/`execve`, it verifies the
embedded helper SHA-256 and strict Security signature, opens without following
links, and copies the bytes to an owner-private immutable temporary path.
Output is capped at 1 MiB for stdout and 1 MiB for stderr (2 MiB total), and a
15-second deadline is enforced. Timeout, overflow, identity, signature, or
cleanup failures reject the fallback result.

## ALTAnisetteData hooks

AltServer can reinsert a legacy device description while creating or updating
`ALTAnisetteData`. The dylib hooks both
`initWithMachineID:oneTimePassword:localUserID:routingInfo:deviceUniqueIdentifier:deviceSerialNumber:deviceDescription:date:locale:timeZone:`
and `setDeviceDescription:` only when the class/method exists and its
Objective-C ABI matches exactly. A missing description or one containing the
legacy Xcode marker `3594.4.19` is replaced with the helper's current
`X-Mme-Client-Info`; all other arguments and nonlegacy descriptions pass through
unchanged. If AltSign loads later, a guarded one-shot add-image callback retries
the hook once rather than polling continuously.

## GrandSlam ownership

The official AltServer 1.7.6/AltSign transport owns the official GrandSlam
authentication, HTTP 503 handling, modern AuthKit client information, and
AltXPC fallback. The injected dylib installs no GSA, GrandSlam, User-Agent, or
AltSign hook. The separate helper uses the upstream lookup endpoint
`https://gsa.apple.com/grandslam/GsService2/lookup` with
`User-Agent: akd/1.0 CFNetwork/808.1.4` for its own provisioning flow; this does
not rewrite or intercept the official exchange.

## v3.8 helper and V3 protocol

The helper builds `X-Mme-Client-Info` at runtime from `hw.model`, the macOS
product version/build, and Xcode `25183.54.10`. When an existing identity is
decoded, this client-info string is refreshed in memory while its identity and
provisioning data are retained; reprovisioning is not forced.

The public V3 sequence is:

1. Fetch Apple provisioning URLs from the GSA lookup endpoint.
2. Open a WSS connection to `/v3/provisioning_session`.
3. Exchange the identifier, `spim`, `cpim`, `ptm`, and `tk` messages.
4. Store returned `adi_pb` personalization data locally.
5. POST the saved identity to `/v3/get_headers` for fresh headers.

CryptoKit SHA-256 derives the local user identifier from random bytes. The
default server is `https://ani.sidestore.zip`; a direct helper run may set
`ALTSERVER_ANISETTE_SERVER_URL` to another HTTPS URL without userinfo. Secure
redirects must retain scheme, host, and effective port. HTTP responses and WSS
messages are capped at 1 MiB, and transient provisioning/header operations are
retried up to three times.

## v1.0.9 machineID runtime hardening

The completed-app build includes three narrow regression fixes around the
private helper process. First, the `NSTemporaryDirectory()` path is resolved
with `realpath` before creating the private directory under the `/var`-backed
temporary root. The root is checked for ownership and write permissions, and
the opened directory and helper retain `O_NOFOLLOW_ANY`; this avoids a path
alias without weakening no-follow checks. Second, the child environment is
rebuilt without every `DYLD_*` variable before `execve`, so inherited loader
state cannot alter the private helper. Third, cleanup is descriptor-anchored:
the helper and directory device/inode/owner identities are captured, the
helper is removed with `unlinkat` relative to the validated directory
descriptor, and the directory is removed only if its path still matches the
captured identity. Cleanup therefore cannot follow a replacement path or
remove an unrelated directory.

These changes harden the fallback's temporary-process lifecycle only. They do
not change the public V3 message sequence, endpoint, header mapping, Apple
authentication, or the official GrandSlam path.

## Header mapping and failure boundary

The helper returns current `X-Apple-I-*` headers. The dylib maps:

```text
X-Apple-MD-M <- X-Apple-I-MD-M
X-Apple-MD   <- X-Apple-I-MD
```

Malformed or non-dictionary helper output, missing required headers, invalid
HTTP status, and unsafe URLs are rejected. An HTML `503`, `apptokens` failure,
HTTP `401/503`, or other upstream outage remains outside this local guarantee.

## macOS 27 loader integrity

macOS 27 `dyld` rejects an injected dylib without exactly one valid nonzero
`LC_UUID`, reporting `OS_REASON_DYLD` / `missing LC_UUID load command`. The
builder derives deterministic UUID values from pinned source hashes and compile
inputs, then validates helper and dylib after linking, after signing, and after
ZIP extraction. The installer repeats the one-valid-UUID check before dry-run
success and before any write to `/Applications` or Application Support. This is
a loader requirement, not a change to `machineID` fallback or the official
GSA/GrandSlam path. Two clean builds should be byte-identical.

## Signing, packaging, and transactions

The build verifies the official input's Developer ID signature, notarization
ticket, Gatekeeper assessment, and universal main executable before copying it
to a private staging tree. It preserves the main executable's code and signs
the modified app/helper/dylib ad hoc; the output must not be described as
Developer ID signed or notarized. For the historical v1.0.8 source-only
workflow, the local output directory contains exactly the ZIP, executable
manifest, metadata, and checksum file, with no raw app or `Payload/` directory.
The v1.0.9 release package contains the patched app in a DMG for drag
installation; that direct replacement makes no automatic backup. See
[README.md](README.md)
for the expected Gatekeeper warning and safe **Open Anyway** flow.

Install and Restore are root-only transactions; their non-root dry-runs are
read-only. Both use a shared root lock and descriptor-bound parent/device/inode
checks around copy, rename, remove, backup publication, and recovery. Install
backs up the verified official app as
`{AltServer.app,metadata}` under the invoking user's canonical Application
Support path. Restore also accepts legacy `.app` plus adjacent `.metadata`
records. Both scripts act only on `/Applications/AltServer.app` and terminate
only its exact executable path.

## Privacy isolation

The helper's URLSession is dedicated and ephemeral. It disables cookie creation
and acceptance, removes cookie storage, clears URL credential storage, clears
additional headers, and disables the URL cache. The helper does not receive or
send Apple ID/Apple Account email, password, session cookie, two-factor code, or
authorization header to the anisette service. The only persistent protocol
state is the local `RemoteAnisetteUser.json` identity (mode `0600`).

The tracked repository source tree contains source, scripts, references, and
documentation only. The v1.0.9 DMG release asset contains the patched app
binary, but neither distribution contains personal credentials,
certificates, profiles, device identities, or copied local user data.
