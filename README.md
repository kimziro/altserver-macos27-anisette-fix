# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

## 1. Downloads and changes

[**Download v1.3.3 setup DMG — macOS27 / Apple silicon**](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.3.3/AltServer-Setup-v1.3.3-macOS27-arm64.dmg)

**Addresses “The anisette server ani.jkcoxson.com sent an invalid response” during installation.** The provider changed its Windows identity to Mac while v1.3.2 required Windows, rejecting valid HTTP200 metadata. This release accepts supported Mac identities and supplies the exact verified Mac User-Agent to the companion when local transport omits it. Existing -45061 recovery reprovisions rejected ADI once. Earlier -80045/HTTP503 compatibility is retained; this is not a universal authentication fix.

Install into Applications, quit the old app, then choose **Install AltStore → your iPhone** and sign with your own account. Companion **AltStore2.3.1 / build6403**; Mac **1.8-pr1834-public-v1.3.3 / 183403**. [Detailed bilingual error explanations and installation instructions](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.3).

## 2. Important notes

Unofficial experimental prerelease, ad-hoc signed and not notarized. Mac requires macOS27 arm64; iPhone minimum iOS17.4. Use the normal Privacy & Security → Open Anyway action if blocked. Verified: real-account USB installation on a new iPhone iOS27.2, independently confirmed6403/ProfileValidatedtrue. **Post-install refresh, Remote AltServer and USB-free use remain untested.** No universal fix for -80046, persistent503 or invalidanisette; no new iOS434resync. External anisette service/private system APIs remain dependencies. Passwords/2FA go only to Apple; no automatic DNS/security changes. [Security](SECURITY.md), [full release notes](releases/v1.3.3.md).

## 3. Release history

Published versions, newest first; dates in Korea Standard Time.

| 버전 / Version | 공개일 / KST date | 변경 사항 / Changes |
| --- | --- | --- |
| [v1.3.3](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.3) | 2026-10-23 | 서버의 Windows→Mac identity 변경으로 인한 invalid-response 거부 수정, 해당 Mac User-Agent 대응, 새 iPhone USB 설치 성공. / Provider-transition response compatibility and matching companion UA; new-iPhone USB installation verified. |
| [v1.3.2](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.2) | 2026-10-17 | Mac·패치 iPhone 통합 설치본, 기본 설치 메뉴 자동 선택. / Integrated Mac/companion installation and bilingual troubleshooting. |
| [v1.3.1](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.1) | 2026-10-16 | macOS27 arm64 실험 DMG, 제한된 정적 crypto 제외. / Installable experimental Mac build without bundled restricted static crypto. |
| [v1.3.0](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.0) | 2026-10-15 | Windows ADI 인증 흐름 소스 전용. / Source-only Windows ADI authentication release. |
| [v1.2.0](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.2.0) | 2026-10-14 | AltServer1.8.1 기반 -80045 client-info 패치, 이후 재발 보고. / Client-description workaround; recurrence later reported. |
| [v1.0.9](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.9) | 2026-09-16 | AltServer1.7.6 machineID 수정의 완성 앱 DMG. / Completed-app DMG for machineID compatibility. |
| [v1.0.8](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.8) | 2026-09-15 | macOS27 anisette 수정 소스 전용. / Source-only compatibility fix. |
| [v1.0.2](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.2) | 2026-06-13 | Gatekeeper 안내 보완, 앱 바이너리 동일. / Gatekeeper documentation; unchanged binary. |
| [v1.0.1](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.1) | 2026-06-13 | 배포 크기·백업 복원 개선, 앱 바이너리 동일. / Smaller distribution and backup restoration; unchanged binary. |
| [v1.0.0](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.0) | 2026-06-13 | AltServer1.7.2 machineID V3 대체 최초 공개. / Initial machineID V3 fallback. |
