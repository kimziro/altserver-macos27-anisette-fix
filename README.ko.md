# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

## 1. 다운로드 링크와 변경 사항

[**v1.3.3 통합 DMG 다운로드 — macOS27 / Apple silicon**](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.3.3/AltServer-Setup-v1.3.3-macOS27-arm64.dmg)

**설치 중 “The anisette server ani.jkcoxson.com sent an invalid response” 오류에 대응합니다.** 서버가 Windows에서 Mac 인증 정보로 전환됐지만 v1.3.2가 Windows만 허용해 정상 HTTP200 응답을 거부한 것이 원인이었습니다. 지원하는 Mac 정보를 허용하고, 동봉 iPhone 앱에도 현재 확인한 정확한 Mac 정보에 맞는 User-Agent를 적용합니다. 기존 ADI가 -45061로 거부되면 원래의 재발급 1회 경로를 이용합니다. 기존 -80045/HTTP503 인증 수정은 유지하며 모든 인증 오류 해결을 주장하지 않습니다.

Applications에 설치하고 이전 앱을 종료한 뒤 **Install AltStore → 내 iPhone**에서 본인 계정으로 설치하세요. 동봉 앱은 **AltStore2.3.1 / build6403**, Mac은 **1.8-pr1834-public-v1.3.3 / 183403**입니다. [영어·한국어 상세 오류 설명과 설치 안내](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.3).

## 2. 주의 사항

비공식 실험용 사전 릴리스이며 임시 서명, Apple 미공증입니다. Mac은 macOS27 arm64 전용이고 iPhone 최소 iOS17.4입니다. 차단되면 해당 앱의 개인정보 보호 및 보안 → 확인 없이 열기(Open Anyway)를 이용하세요. 이번 검증은 새 iPhone iOS27.2의 USB 실제 설치 성공과 기기6403/ProfileValidated확인입니다. **설치 후 갱신·원격·USB 없는 사용은 미시험**입니다. -80046·지속503·invalidanisette 등 모든 오류를 해결하지 않으며 iOS434resync도 추가하지 않았습니다. 외부 anisette서비스·private시스템API에 의존합니다. 계정 암호·2FA는 Apple에만 전송되며 DNS·보안설정 자동변경은 없습니다. [보안 안내](SECURITY.md), [이번 수정 상세](releases/v1.3.3.md).

## 3. 지금까지의 릴리스 내역

공개 버전 최신순, 날짜는 한국시간입니다.

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
