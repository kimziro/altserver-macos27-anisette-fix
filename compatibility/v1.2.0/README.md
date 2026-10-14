# AltServer macOS 27 anisette compatibility patch

This source builds a modified copy of the official AltServer 1.8.1 (build 98) for macOS 27 compatibility. It changes only the in-process `ALTAnisetteData.deviceDescription` getter to return this Android client descriptor:

`<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>`

The hook checks the getter ABI before installing and retries briefly if the target class is not yet loaded. It does not change stored anisette fields, the setter, provisioning, or the iOS authentication flow. The synthetic test checks the getter, preservation of other fields and setter behavior, and fail-closed handling of a mismatched ABI.

## Build

On macOS with Xcode command line tools installed, pass either the official archive or its extracted `AltServer.app`, followed by a new output app path:

```sh
./build.sh /path/to/1_8_1.zip /path/to/output/AltServer.app
```

The build verifies the official bundle identifier, version, build, Developer ID team, strict signature, and original main executable SHA-256 before patching. It preserves the original `__TEXT` contents in both architectures, adds only the `allow-jit` entitlement used by the official app, ad-hoc signs the outer app, and runs the synthetic getter test. It does not launch the app.

The output bundle reports the upstream version `1.8.1` and build `98`; the community package version is tracked separately as v1.2.0. The dylib uses the generic install name `@rpath/80045ClientInfoGetter.dylib` so the binary contains no developer checkout path.

## Upstream provenance

The official input archive was downloaded from the AltStore CDN:

`https://cdn.altstore.io/file/altstore/altserver/1_8_1.zip`

Downloaded size: 13,748,146 bytes
Downloaded SHA-256: `8f48728c64ad776580939ce05ee99e979d457226fb82b1d42f95a8c1bd73e3c1`

AltServer and its bundled components remain subject to their respective upstream notices and licenses. This patch source is distributed under the GNU Affero General Public License v3.0; see `LICENSE`.
