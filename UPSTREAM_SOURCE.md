# Upstream Source and Provenance

The repository source tree contains the local helper/dylib source,
transaction/build scripts, references, and documentation only. The v1.0.9
release uses a completed-app DMG containing the patched `AltServer.app`
(`1.7.6-macOS27-v3.8`, build 94); the historical v1.0.8 / v3.7 publication was
source-only and did not distribute an app or other binary asset. The v1.0.9
app is derived from the independently verified official AltServer input below.

## Official AltServer input

The authoritative public references for the input are:

- Product: AltServer 1.7.6, build 94
- Sparkle feed: <https://altstore.io/altserver/sparkle-macos.xml>
- Official archive: <https://cdn.altstore.io/file/altstore/altserver/1_7_6.zip>
- Archive SHA-256:
  `ea4c47fa25abc0166bd4e9785f96f82488e6606b2e015ff046f8fceee083e6b9`
- Bundle identifier: `com.rileytestut.AltServer`
- Main executable: universal `arm64` + `x86_64`
- TeamIdentifier: `6XVY5G3U44`
- Main executable SHA-256:
  `d1e4188b67adbd120af597ffa11708a18cb139db9919baa5be806a129a3cf819`

The patched app in the v1.0.9 DMG is derived from this verified official
archive plus the local patch sources. The archive itself is a build input, not
a repository asset.

`scripts/build_release.sh` requires the official Developer ID signature,
recursive strict signature verification, Gatekeeper assessment, and a valid
notarization ticket before injection. The original input is a local build
dependency, not a repository asset.

The official Sparkle release separately includes modern AuthKit client
information, the reported HTTP 503 sign-in handling, and the AltXPC fallback.
[AltStore issue #1751](https://github.com/altstoreio/AltStore/issues/1751) still
has a macOS 27 `machineID` failure report for 1.7.6, which motivates this local
fallback. These facts do not establish that upstream itself contains this
patch.

An exact public Git commit mapping for the official 1.7.6/build 94 archive or
its published binary cannot be proven from the available evidence. Do not
infer or claim such a mapping for the v1.0.9 app. [PR #1790](https://github.com/altstoreio/AltStore/pull/1790)
is closed and unmerged; [commit `c558994`](https://github.com/altstoreio/AltStore/commit/c558994501bac639780a853ffb54065cc703b770)
is retained only as PR-head context, not as an input or dependency.

## Related upstream references

These links provide context or protocol references; none is injected into the
local app:

- [AltStore PR #1770](https://github.com/altstoreio/AltStore/pull/1770) —
  experimental, unmerged macOS 26+ anisette fallback.
- [AltSign PR #54](https://github.com/rileytestut/AltSign/pull/54) — separate
  historical context; no `AltSign-Dynamic` is bundled or published here.
- [SideStore RemoteAnisette](https://github.com/SideStore/RemoteAnisette) — V3
  protocol interoperability reference.
- [anisette-v3-server](https://github.com/Dadoum/anisette-v3-server) — V3
  protocol interoperability reference.

The public AltStore Classic 2.2.2 on-device transport is a separate component.
This project contains no patched iPhone IPA; an on-device refresh failure may
require an official AltStore update.

## Local patch pins and reference checks

`scripts/build_release.sh` enforces exact SHA-256 values for the three source
inputs used to compile the helper and dylib:

| enforced source | SHA-256 |
| --- | --- |
| `src/AltServerAnisetteFix.m` | `7e3e241d1ad7c72b9900337bb51e3deb359beb9def2477ee261d9d549373de6c` |
| `src/AnisetteHelper/AnisetteV3Client.swift` | `118c5b84d2a8d2c5e8741a7e27d521628b29b15f337f8c70684343555e177112` |
| `src/AnisetteHelper/main.swift` | `0abfdd8ef5c3e0293d48421f6dc52cb5f2fab3dd8a120677035036dc0ee4f40e` |

The build computes the current `scripts/build_release.sh` SHA-256 and records
`BuildScriptSHA256=` in metadata; the validation is self-consistency against
that computed value, not a comparison with a hardcoded expected build-script
hash. Install.command and Restore.command hashes are not enforced by the
build. Keep all six observed hashes as manual `shasum -a 256` reference checks:

| reference input | SHA-256 | check |
| --- | --- | --- |
| `src/AltServerAnisetteFix.m` | `7e3e241d1ad7c72b9900337bb51e3deb359beb9def2477ee261d9d549373de6c` | enforced by build |
| `src/AnisetteHelper/AnisetteV3Client.swift` | `118c5b84d2a8d2c5e8741a7e27d521628b29b15f337f8c70684343555e177112` | enforced by build |
| `src/AnisetteHelper/main.swift` | `0abfdd8ef5c3e0293d48421f6dc52cb5f2fab3dd8a120677035036dc0ee4f40e` | enforced by build |
| `scripts/build_release.sh` | `2920f535476638da35208beab548ef51b7effbf558197edf451c0ca2fdc0deb3` | manual `shasum -a 256`; metadata self-consistency only |
| `scripts/Install.command` | `6b38363ceaf3fbfb65d407599c6d1ef81bdfecd8daa69b123725959831e6c1f0` | manual `shasum -a 256` |
| `scripts/Restore.command` | `ef291ab88ef6417ed1846bfaad8cc95d20cc5cde15deaa40bc0b731adb1befd1` | manual `shasum -a 256` |

For a checkout, run `shasum -a 256` over all six paths and compare the output
with the table. Documentation edits are not part of the source hash gate. A
binary-affecting dirty checkout requires the explicit
`ALTSERVER_ALLOW_DIRTY_ATTESTED_SOURCE=1` attestation and is recorded in local
metadata.

## What the local patch does

The injected arm64 dylib calls the official
`AOSUtilities.retrieveOTPHeadersForDSID:` path first. It accepts and
canonicalizes only a complete, coherent, nonempty pair of either
`X-Apple-MD-M`/`X-Apple-MD` or `X-Apple-I-MD-M`/`X-Apple-I-MD`. A
non-dictionary, missing/empty, partial/incomplete, or conflicting response
invokes the Foundation-based arm64 helper and public V3 protocol. Exact ABI
checks guard the `ALTAnisetteData` description hooks.

The helper's own Apple provisioning lookup is
`https://gsa.apple.com/grandslam/GsService2/lookup` with
`User-Agent: akd/1.0 CFNetwork/808.1.4`. The dylib has no GSA, GrandSlam,
User-Agent, or AltSign hook and does not alter the official authentication
exchange. The main AltServer executable remains unchanged and universal.

macOS 27 `dyld` requires a valid nonzero `LC_UUID`; a missing command reports
`OS_REASON_DYLD` / `missing LC_UUID load command`. The builder derives and
validates deterministic UUIDs for helper and dylib after linking, signing, and
ZIP extraction. The installer checks exactly one valid nonzero UUID before dry
run success and before writing `/Applications` or Application Support. This is
a loader-integrity check, not a change to the `machineID` decision or GSA path.

## Reproduce locally

To reproduce the v1.0.9 advanced source-build workflow, place the
independently verified official app at a local path and run from the repository
root:

```bash
./scripts/build_release.sh "/path/to/official/AltServer.app" "$PWD/out/v1.0.9"
```

The successful output directory contains exactly four regular files:

```text
AltServer-macOS27-v3.8.zip
AltServer-macOS27-v3.8.executables.txt
BUILD-METADATA.txt
CHECKSUMS-SHA256.txt
```

The ZIP is private local output for verification/installation; the repository
publishes no copy of it or raw app. The v1.0.9 release asset is the completed
DMG containing the patched `AltServer.app`; ordinary users should
use that DMG as described in [README.md](README.md). The former v1.0.8
publication was source-only. See
[BUILDING.md](BUILDING.md) for the exact staging layout and
[INSTALLATION.md](INSTALLATION.md) for install, refresh, restore, and
troubleshooting procedures.
