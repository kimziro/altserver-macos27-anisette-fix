# AltServer Setup v1.3.2 — Start here

Unofficial experimental setup for macOS27 / Apple silicon. Includes Mac1.8-pr1834-public-v1.3.2 / 183402 and iPhone AltStore2.3.1 / 6402.

## Install

Drag AltServer from the DMG into Applications, quit an older running copy, and open the new app. It is ad-hoc signed and not notarized. If blocked, use the normal System Settings → Privacy & Security → Open Anyway action for this app.

Connect and unlock the iPhone by USB; complete trust/developer-mode prompts yourself when requested. Choose the Mac menu-bar **Install AltStore → your iPhone**. This menu automatically selects the bundled patched companion. Enter your own Apple Account and2FA code. Use the existing account when replacing AltStore; do not uninstall it first. Tapping an IPA in Safari does not install it. Verify iPhone AltStore Settings shows **2.3.1 / build6402**.

## First refresh

Keep USB connected and use the same Wi-Fi as the Mac. Turn Prefer Remote AltServer off and refresh one app. LocalDevVPN is not required for this Mac-assisted USB path. Certificate changes can require reinstalling a large app, taking over a minute.

## HTTP503 over Wi-Fi

Retain USB, switch only the iPhone from Wi-Fi to cellular, and compare once. This succeeded with the tested client code. To try the observed Wi-Fi workaround, record original DNS settings, then Settings → Wi-Fi → networkⓘ → Configure DNS → Manual; replace servers with **1.1.1.1 / 1.0.0.1**, save and retry one app. Two consecutive refreshes succeeded in the tested setup, independently confirmed by new device profiles. This is not proof that every503 is a DNS fault. Restore original DNS if ineffective or connectivity worsens.

The change applies only to that Wi-Fi, can affect router-provided internal names/filtering, and does not itself encrypt DNS queries. [Cloudflare instructions](https://developers.cloudflare.com/1.1.1.1/setup/ios/).

## Limits and privacy

Invalid anisette is a separate investigation. Inspect clock agreement and automatic time settings, record both app versions/builds and full error domain/code/stage; generic clock advice does not establish the cause. No iOS hsc434 resync is added.

Normal Refresh All uses the current app cache/profiles; missing-cache downloads and official updates can replace the patch. Check version if failures recur.

External service ani.jkcoxson.com supplies anisette and can observe connection metadata. Apple Account passwords/2FA go only to Apple. Added authentication diagnostics record fixed stages/status codes, not payloads. No account credentials, private signing keys, pairing records or runtime anisette identity are distributed. The installer does not change DNS/security settings. Real-device evidence is limited to macOS27.0.1 / iOS27.2 / USB; other accounts/devices/OS combinations and USB-free refresh remain unverified.

[503 investigation](refresh-http-503.md) · [Invalid anisette](invalid-anisette.md) · [Community cases](community-findings.md) · [Release and complete source](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.2)
