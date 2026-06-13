# Building

Requirements:

- macOS 27 Command Line Tools
- Original AltServer 1.7.2 application
- Apple Silicon Mac

Build:

```bash
chmod +x scripts/build_release.sh
./scripts/build_release.sh /path/to/original/AltServer.app
```

The output is ad-hoc signed. To use a Developer ID certificate, replace
`codesign --sign -` in the script with the desired signing identity and
perform Apple's notarization process separately.

The helper uses only Foundation and CryptoKit. The default V3 endpoint is
declared in `src/AnisetteHelper/main.swift`.

For testing or self-hosted deployments, set
`ALTSERVER_ANISETTE_SERVER_URL` before running the helper.
