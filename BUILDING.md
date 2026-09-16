# Building

This is the advanced source-build guide for release v1.0.9 / v3.8. The v1.0.9
release asset is a completed-app DMG containing the patched `AltServer.app`.
Ordinary users should download it from the v1.0.9 release as described in
[README.md](README.md). The repository source tree publishes source, scripts,
and documentation, not a raw app or IPA. The former v1.0.8 /
v3.7 publication was source-only. No step here builds or packages an iPhone IPA.

## Requirements and official input

- Apple Silicon Mac running a native `arm64` process. Rosetta is rejected.
- macOS 27 Command Line Tools available through `xcrun`; macOS 27 is the tested
  target and other versions are unsupported/unverified.
- An independently obtained, unmodified official AltServer 1.7.6/build 94.

Download the official archive from:

```text
https://cdn.altstore.io/file/altstore/altserver/1_7_6.zip
SHA-256  ea4c47fa25abc0166bd4e9785f96f82488e6606b2e015ff046f8fceee083e6b9
```

Verify the hash before extraction. The builder then requires bundle identifier
`com.rileytestut.AltServer`, version `1.7.6`, build `94`, a universal
`arm64`+`x86_64` main executable, TeamIdentifier `6XVY5G3U44`, a Developer ID
signature, recursive strict verification, Gatekeeper acceptance, a valid
notarization ticket, and the approved main executable SHA-256:

```text
d1e4188b67adbd120af597ffa11708a18cb139db9919baa5be806a129a3cf819
```

The public feed and archive/version/build/hash are the authoritative input
checks. An exact public Git commit mapping the official 1.7.6/build 94 archive
cannot be proven from the available evidence; do not invent one. PR #1790 and
commit `c558994` are context only (closed/unmerged PR head), not a build input.

## Pinned local source and manual reference checks

The build gate enforces exact SHA-256 values for these three source files only:

| enforced input | path | SHA-256 |
| --- | --- | --- |
| Objective-C patch | `src/AltServerAnisetteFix.m` | `7e3e241d1ad7c72b9900337bb51e3deb359beb9def2477ee261d9d549373de6c` |
| Swift client | `src/AnisetteHelper/AnisetteV3Client.swift` | `118c5b84d2a8d2c5e8741a7e27d521628b29b15f337f8c70684343555e177112` |
| Swift entry point | `src/AnisetteHelper/main.swift` | `0abfdd8ef5c3e0293d48421f6dc52cb5f2fab3dd8a120677035036dc0ee4f40e` |

The script computes the current `scripts/build_release.sh` SHA-256 and records
it as `BuildScriptSHA256=` in `BUILD-METADATA.txt`. Its validation checks that
metadata value against the same hash computed for that build; it does not
compare the script with a hardcoded expected build-script hash. The build does
not enforce the Install.command or Restore.command hashes. The six current
hashes below are therefore source pins plus manual reference checks, not
downloadable binary checksums:

| reference input | path | SHA-256 | check |
| --- | --- | --- | --- |
| Objective-C patch | `src/AltServerAnisetteFix.m` | `7e3e241d1ad7c72b9900337bb51e3deb359beb9def2477ee261d9d549373de6c` | enforced by build |
| Swift client | `src/AnisetteHelper/AnisetteV3Client.swift` | `118c5b84d2a8d2c5e8741a7e27d521628b29b15f337f8c70684343555e177112` | enforced by build |
| Swift entry point | `src/AnisetteHelper/main.swift` | `0abfdd8ef5c3e0293d48421f6dc52cb5f2fab3dd8a120677035036dc0ee4f40e` | enforced by build |
| build script | `scripts/build_release.sh` | `2920f535476638da35208beab548ef51b7effbf558197edf451c0ca2fdc0deb3` | manual `shasum -a 256` reference; metadata self-consistency only |
| installer | `scripts/Install.command` | `6b38363ceaf3fbfb65d407599c6d1ef81bdfecd8daa69b123725959831e6c1f0` | manual `shasum -a 256` reference |
| restore | `scripts/Restore.command` | `ef291ab88ef6417ed1846bfaad8cc95d20cc5cde15deaa40bc0b731adb1befd1` | manual `shasum -a 256` reference |

To check a checkout manually, run `shasum -a 256` over these six paths and
compare the output with the table.

## Build command

Run from the repository root. Create the explicit output parent first; the
script deliberately does not create an arbitrary parent:

```bash
chmod +x scripts/build_release.sh
mkdir -p out
./scripts/build_release.sh \
  "/path/to/official/AltServer.app" \
  "$PWD/out/v1.0.9"
```

The script snapshots the official input and approved source files before
compiling, rejects a stale/already patched input, and fails closed on dynamic
AltSign or embedded IPA content. Documentation-only worktree changes are
recorded. Any binary-affecting dirty state fails unless explicitly attested:

```bash
ALTSERVER_ALLOW_DIRTY_ATTESTED_SOURCE=1 \
  ./scripts/build_release.sh "/path/to/official/AltServer.app" "$PWD/out/v1.0.9"
```

That opt-in marks metadata `SourceTreeState=dirty-attested`, snapshots the
approved source bytes into an owner-private immutable temporary directory, and
checks snapshot identities throughout the build. Use it only when you have
reviewed the dirty changes.

The build compiles the arm64 helper and compatibility dylib, strips debug/path
data, rejects GSA/GrandSlam/User-Agent network-hook strings and symbols, and
uses install name `@rpath/AltServerAnisetteFix.dylib`. It preserves the
official main executable and universal resources, sets app version
`1.7.6-macOS27-v3.8`/build `94`, adds the relative
`DYLD_INSERT_LIBRARIES` entry, and signs the resulting app and injected objects
ad hoc. Developer ID and notarization are input checks only; they are not
carried forward to the locally modified app.

The helper's own provisioning lookup uses
`https://gsa.apple.com/grandslam/GsService2/lookup` with
`User-Agent: akd/1.0 CFNetwork/808.1.4`. The dylib does not hook or rewrite the
official GSA/GrandSlam/User-Agent authentication path.

## macOS 27 loader integrity

macOS 27 `dyld` rejects an injected dylib without a valid nonzero `LC_UUID`,
reporting `OS_REASON_DYLD` / `missing LC_UUID load command`. The builder derives
deterministic UUIDs from the pinned source hashes and compile inputs, then
validates each UUID after link, after signing, and after ZIP extraction. The
helper is checked as well. This loader requirement is separate from the
`machineID` fallback and does not change the official GSA path. Two clean builds
should produce byte-identical local artifacts.

## Local output and verification

On success, `out/v1.0.9` contains exactly these four regular files:

```text
AltServer-macOS27-v3.8.zip
AltServer-macOS27-v3.8.executables.txt
BUILD-METADATA.txt
CHECKSUMS-SHA256.txt
```

There is no raw app, `Payload/` directory, IPA, profile, certificate, or other
release file in that directory. The ZIP is the only app-bearing artifact and
is private local output. Do not stage an old directory: an existing
`out/v1.0.9` is stale until a fresh build succeeds.

The ZIP writer uses sorted paths and fixed timestamps, rejects traversal,
duplicate, absolute, dangling-symlink, and AppleDouble entries, and records a
finite executable-mode manifest. Metadata includes `ReleaseVersion=1.0.9`,
`PatchVersion=v3.8`, official base version/build, `AltSign=Official-static-only`,
`PatchedIPA=Not-included`, `NetworkHooks=No-GSA-or-User-Agent-hook`, source and
script hashes, worktree state, helper/dylib hashes, and deterministic UUID data.

Verify without installing by extracting the local ZIP into a private temporary
directory:

```bash
set -euo pipefail
cd out/v1.0.9
shasum -a 256 -c CHECKSUMS-SHA256.txt
verify_dir="$(mktemp -d)"
unzip -q AltServer-macOS27-v3.8.zip -d "$verify_dir"
codesign --verify --deep --strict "$verify_dir/AltServer.app"
lipo -archs "$verify_dir/AltServer.app/Contents/MacOS/AltServer"
lipo -archs "$verify_dir/AltServer.app/Contents/Frameworks/AltServerAnisetteHelper"
lipo -archs "$verify_dir/AltServer.app/Contents/Frameworks/AltServerAnisetteFix.dylib"
```

The main architecture output must include `arm64` and `x86_64`; each injected
object must report only `arm64`. The installer repeats the relevant checks.

## Exact installer staging, dry run, and restore

The current installer accepts a flat layout or a `Payload/` layout. For the
four-file output, use a private staging directory with both scripts at its root
and the files directly under `Payload/`:

```bash
stage_dir="$(mktemp -d)"
cp scripts/Install.command scripts/Restore.command "$stage_dir/"
mkdir "$stage_dir/Payload"
cp out/v1.0.9/AltServer-macOS27-v3.8.zip \
   out/v1.0.9/AltServer-macOS27-v3.8.executables.txt \
   out/v1.0.9/BUILD-METADATA.txt \
   out/v1.0.9/CHECKSUMS-SHA256.txt "$stage_dir/Payload/"
chmod +x "$stage_dir/Install.command" "$stage_dir/Restore.command"
(cd "$stage_dir" && ALTSERVER_INSTALL_DRY_RUN=1 ./Install.command)
(cd "$stage_dir" && sudo ./Install.command)
```

Run the dry run as the invoking non-root user, then run the actual installer
with `sudo`; do not use `sudo` for the dry run. Actual Install and Restore are
root-only and require a valid non-root `SUDO_USER`. The installer extracts and
validates before writing `/Applications` or Application Support. If the target
exists, it atomically records:

```text
~/Library/Application Support/AltServer-macOS27-Fix/Backups/
└── AltServer-<UTC>.<pid>.<rand>.backup/{AltServer.app,metadata}
```

Restore from the same staging directory:

```bash
(cd "$stage_dir" && ALTSERVER_INSTALL_DRY_RUN=1 ./Restore.command)
(cd "$stage_dir" && sudo ./Restore.command)
```

Restore selects the newest verified backup, accepts a verified backup path
argument, and also validates legacy `.app` plus adjacent `.metadata` records.
Backups remain after success. Both transactions use a shared root lock and
descriptor-bound identity checks, and terminate only the exact AltServer
executable path.

See [INSTALLATION.md](INSTALLATION.md) for the end-user sideload, refresh,
Gatekeeper, troubleshooting, and log-redaction guidance.
