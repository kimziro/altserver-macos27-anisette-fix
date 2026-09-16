# Installation

The v1.0.9 release asset is a completed-app DMG containing the patched
`AltServer.app`. Most users should follow [README.md](README.md) and install
it by dragging the app to Applications. This is the advanced source-build and
installer guide for v1.0.9 / v3.8. The repository source tree contains source,
scripts, references, and documentation; the former v1.0.8 / v3.7
publication was historical and source-only. This guide does not build or
package an iPhone IPA.

The tested target is an Apple Silicon Mac running macOS 27 natively
(`arm64`), with official AltServer 1.7.6/build 94. Rosetta and other macOS
versions are unsupported and unverified. Maintainer testing covered install,
sideload, and refresh on the current macOS 27/iOS 27 environment; independent
exact-match validation is limited.

## 1. Download and verify the official input

Use only the version-pinned official archive:

```text
https://cdn.altstore.io/file/altstore/altserver/1_7_6.zip
SHA-256  ea4c47fa25abc0166bd4e9785f96f82488e6606b2e015ff046f8fceee083e6b9
```

Download it to a private temporary file and verify before extraction:

```bash
set -euo pipefail
official_zip="$(mktemp -t altserver-1_7_6.XXXXXX.zip)"
curl -fL \
  'https://cdn.altstore.io/file/altstore/altserver/1_7_6.zip' \
  -o "$official_zip"
printf '%s  %s\n' \
  'ea4c47fa25abc0166bd4e9785f96f82488e6606b2e015ff046f8fceee083e6b9' \
  "$official_zip" | shasum -a 256 -c -
official_dir="$(mktemp -d)"
unzip -q "$official_zip" -d "$official_dir"
official_app="$(find -P "$official_dir" -type d -name AltServer.app -print -quit)"
test -n "$official_app" -a -d "$official_app"
```

Do not build from an already patched app. The build script independently checks
the bundle identifier, version/build, universal executable, official signing,
Gatekeeper assessment, notarization ticket, and approved main-executable hash.

## 2. Build the local payload

Clone or otherwise check out this repository, then run from its root:

```bash
mkdir -p out
./scripts/build_release.sh "$official_app" "$PWD/out/v1.0.9"
```

The successful output directory contains exactly four regular files:

```text
AltServer-macOS27-v3.8.zip
AltServer-macOS27-v3.8.executables.txt
BUILD-METADATA.txt
CHECKSUMS-SHA256.txt
```

The ZIP is a private, app-bearing build result; it is not a GitHub asset. A
pre-existing `out/v1.0.9` is stale until this command completes successfully.
Inspect `CHECKSUMS-SHA256.txt` and `BUILD-METADATA.txt` before staging. The
script emits no IPA, profile, certificate, or raw app beside the ZIP.

## 3. Stage and validate the installer

The current `scripts/Install.command` accepts either a flat layout or a
`Payload/` layout. The reproducible staging layout is a private directory with
the scripts at its top level and the four output files directly under
`Payload/`:

```bash
stage_dir="$(mktemp -d)"
cp scripts/Install.command scripts/Restore.command "$stage_dir/"
mkdir "$stage_dir/Payload"
cp out/v1.0.9/AltServer-macOS27-v3.8.zip \
   out/v1.0.9/AltServer-macOS27-v3.8.executables.txt \
   out/v1.0.9/BUILD-METADATA.txt \
   out/v1.0.9/CHECKSUMS-SHA256.txt "$stage_dir/Payload/"
chmod +x "$stage_dir/Install.command" "$stage_dir/Restore.command"
```

Quit AltServer before the real install. First run the non-root dry run from the
staging directory; it performs validation only and must not be prefixed with
`sudo`:

```bash
(cd "$stage_dir" && ALTSERVER_INSTALL_DRY_RUN=1 ./Install.command)
```

The dry run extracts into a private temporary directory and verifies the ZIP,
manifest, metadata, checksums, bundle metadata, architecture, symlinks,
executable modes, recursive signature, and exactly one valid nonzero `LC_UUID`
on the helper and dylib. It must report that no `/Applications` or Application
Support files were changed. Temporary extraction/validation files are expected.

If macOS blocks the script, attempt to open it once in Finder, then go to
**System Settings > Privacy & Security**, choose **Open Anyway** for this
script, confirm **Open**, and enter the Mac login password if requested. This
adds an exception for the script only; never disable Gatekeeper or SIP globally.

## 4. Install the patched AltServer

With the dry run successful and AltServer quit, run the exact command requested
by the current installer:

```bash
(cd "$stage_dir" && sudo ./Install.command)
```

`sudo` asks for the Mac login password, not an Apple Account password. Actual
installation is root-only and requires a valid non-root `SUDO_USER`; the script
uses that user's canonical home for backup storage. It replaces only
`/Applications/AltServer.app`, after verifying the existing official app and
publishing an atomic backup. It does not attempt an administrator fallback if a
transaction fails; recovery paths are reported and preserved.

The backup has this shape:

```text
~/Library/Application Support/AltServer-macOS27-Fix/Backups/
└── AltServer-<UTC>.<pid>.<rand>.backup/
    ├── AltServer.app
    └── metadata
```

Install and Restore use a shared root lock and descriptor-bound identity checks.
They stop only a process whose executable path is exactly
`/Applications/AltServer.app/Contents/MacOS/AltServer`; `TERM` is sent first,
and `KILL` is sent only if that same path remains. Backup-root and target-path
overrides are rejected for production transactions. The only override allowed
is a canonical, private, owner-owned `$HOME/.altserver-install-*/Backups`
fixture for non-root dry-run validation.

Launch AltServer from `/Applications` after a successful installation. The
patched app identifies itself as:

```text
1.7.6-macOS27-v3.8 (94)
```

An official AltServer update can overwrite this local compatibility build. Keep
the official build or repeat the verified local build if the macOS 27 failure
returns; never mix payload versions.

## 5. Install or refresh AltStore on iPhone

Connect and trust the iPhone, then use AltServer's official **Install
AltStore…** flow. Select the device and complete Apple's normal prompts. If
AltStore is already installed and opens normally, do not reinstall it merely
because the Mac app changed; open **My Apps > Refresh All** instead.

An **Apple Account Sign-In Requested** alert and six-digit verification code
may be part of this normal flow. Approve only an alert you initiated when the
displayed account is yours. Enter the code only in AltStore or AltServer's
prompt. Choose **Don't Allow** for an unsolicited alert. The helper never sees
or sends the code to the anisette service.

## 6. Sideload another app and refresh

Obtain an IPA from a source you trust, open AltStore on the iPhone, choose
**My Apps > +**, and select the IPA. Authenticate only in the normal
AltStore/AltServer UI. This repository ships no IPA and does not change Apple's
signing requirements.

Use **My Apps > Refresh All** to refresh installed apps. A refresh may request
the same Apple Account approval or code. If the version display does not show
`1.7.6-macOS27-v3.8 (94)`, quit AltServer, verify the local build metadata and
staging path, and do not mix payload versions.

## 7. Restore the official app

Quit AltServer and run the staged restore script with `sudo`:

```bash
(cd "$stage_dir" && sudo ./Restore.command)
```

Restore selects the newest verified backup created by Install. You may pass a
verified backup record path explicitly:

```bash
(cd "$stage_dir" && sudo ./Restore.command \
  "$HOME/Library/Application Support/AltServer-macOS27-Fix/Backups/AltServer-<UTC>.<pid>.<rand>.backup")
```

It also validates legacy `AltServer-<UTC>.<pid>.<rand>.app` records with an
adjacent `.metadata` file. Backups remain after a successful restore. Actual
Restore is root-only; the non-root read-only check is:

```bash
(cd "$stage_dir" && ALTSERVER_INSTALL_DRY_RUN=1 ./Restore.command)
```

If no verified backup exists, stop and obtain the official app from
[altstore.io](https://altstore.io/) rather than deleting or guessing at backup
files.

## Troubleshooting

| Symptom | Next step |
| --- | --- |
| `AltServer could not retrieve anisette data value "machineID".` | Confirm native Apple Silicon execution, version `1.7.6-macOS27-v3.8 (94)`, a successful install, and a relaunch. |
| HTTP `503`, `401`, or `apptokens` | Check the network and configured anisette service; the official 1.7.6 path includes its reported 503 handling, but upstream/service outages remain possible. |
| `3840`, HTML in JSON, or parse error | Treat the response as an upstream/proxy error; retry later without posting response bodies or headers. |
| AltStore is missing | Use the official **Install AltStore…** flow. No custom IPA is required by this project. |
| Refresh still fails on iPhone | This patch covers only the Mac-side `machineID` path. An on-device transport or AltStore update may be required. |
| macOS blocks the command | Follow the per-script **Open Anyway** steps above. Do not disable Gatekeeper or SIP globally. |

## Privacy and support logs

The helper's dedicated URLSession is ephemeral and sanitized: cookies, URL
credential storage, cache, and inherited additional headers are disabled or
cleared. HTTPS/WSS requests stay on the configured secure origin; redirects
must keep scheme, host, and effective port. HTTP responses and WebSocket
messages are capped at 1 MiB. The helper does not receive or send Apple
ID/Apple Account email, password, session cookies, two-factor codes, or
authorization headers to the anisette service.

The default V3 service is `https://ani.sidestore.zip`. A personalized identity
is stored locally in
`~/Library/Application Support/AltServer/RemoteAnisetteUser.json` with mode
`0600`; it is not published or included in the output directory. Read
[SECURITY.md](SECURITY.md) before using a public service.

The identity is opened relative to an owner-checked private support directory.
The directory is owner-owned and mode `0700`; the identity must be an
owner-owned regular file with exactly mode `0600` and one hard link. A
no-follow, nonblocking open rejects symlinks, FIFOs, and other non-regular entries;
reads are bounded to 64 KiB. New identities use a unique `0600` exclusive
temporary file, `fsync`, and exclusive publication so concurrent runs cannot
replace an existing entry. If an existing identity fails these checks, the
helper rejects it; after review or quarantine, rerunning provisioning may be
required.

When requesting help, share only a short redacted error, architecture, macOS
version, AltServer version/build, and failed step. Remove Apple ID/Apple Account data,
device IDs/serials/UDIDs, usernames and home paths, backup names, anisette
headers/tokens, identity files, IP/location data, and identifying timestamps.
Never upload an unredacted log, screenshot, or account prompt.
