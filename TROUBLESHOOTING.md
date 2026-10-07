# HTTP 503 followed by Apple Account locked (-20209)

[English](TROUBLESHOOTING.md) | [한국어](TROUBLESHOOTING.ko.md)

If refresh fails, read the latest error before applying another patch. An
initial HTTP 503 and a later Apple Account lock can be separate problems.

## Confirmed case — 2026-10-08

Environment: macOS 27.0.1 (26A434), official AltServer 1.8.1 (build 98).
This case used the official app, not this repository's 1.7.6-based patch.

1. AltServer logged `Apple SPIM endpoint returned HTTP 503` during initial
   anisette provisioning. A subsequent request logged successful provisioning.
2. Local anisette requests succeeded three times before and three times after
   restarting AltServer, with nonempty machineID and one-time-password fields.
3. Refresh on iPhone then failed with `This Apple Account has been locked for
   security reasons` and code `-20209`.
4. The same account could sign in to Apple's website using a passkey. However,
   a fresh **password** sign-in showed that the account was locked.
5. The user unlocked the account through Apple's flow and confirmed that
   AltStore refresh succeeded. No additional code patch was applied.

The initial 503 stopped reproducing after successful provisioning. Unlocking
the account resolved the later `-20209`; this does not establish that an account
lock caused the initial SPIM 503, or that unlocking fixes every HTTP 503.

## What to check

1. If the latest error is `-20209`, compare the email in **AltStore → Settings**
   with the Apple Account you are checking on the web.
2. In a private browser window, sign in at [account.apple.com](https://account.apple.com/)
   using your **password**, and complete verification if requested. A successful
   passkey sign-in alone does not test the password authentication AltStore uses.
3. If Apple also reports a lock, follow its recovery instructions or use
   [iforgot.apple.com](https://iforgot.apple.com/). Then retry **Refresh All** once.
4. If you changed your password, sign out of AltStore and sign back in with
   the updated password. If password sign-in works but AltStore still fails,
   record the latest error and investigate that authentication path separately.

Keep passwords, verification codes, anisette identities, and unredacted logs
out of public issues. Account recovery is performed directly with Apple.

## References

- [Apple: locked, inactive, or disabled accounts](https://support.apple.com/102640)
- [Apple: passkeys](https://support.apple.com/guide/iphone/iphf538ea8d0/ios)
- [AltStore: account/password installation flow](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)
- [AltStore issue #283](https://github.com/altstoreio/AltStore/issues/283): a historical
  case where an outdated or recovery email produced `-20209` while web sign-in
  worked. That was not the cause in the case above; the emails matched.
