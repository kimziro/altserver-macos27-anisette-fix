# AltServer macOS27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

## v1.3.2 실험용 통합 설치본 — Mac + 패치 iPhone 앱

[**바로 설치하는 DMG 다운로드 — macOS27 / Apple silicon**](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.3.2/AltServer-Setup-v1.3.2-macOS27-arm64.dmg)

직접 빌드할 필요가 없습니다. AltServer를 Applications로 옮기고 이전 실행 앱을 종료한 뒤 새 앱을 여세요. iPhone을 USB로 연결·잠금 해제하고 메뉴 막대 **Install AltStore → 내 iPhone**을 선택하면 **패치된 AltStore2.3.1 / build6402**가 자동 선택됩니다. 본인 계정과 인증코드로 설치하세요. 기존 앱 교체 시 같은 계정을 쓰고 먼저 삭제하지 마세요.

[차례대로 설치하기](docs/START-HERE.ko.md) · [English](docs/START-HERE.md) · [릴리스·전체 소스](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.2)

**확인 결과:** Macv1.3.1 인증 코드 계열은 macOS27.0.1 / iOS27.2에서 USB 설치에 성공했습니다. 동봉 iPhone 앱 코드는 USB 유지+LTE 및 Wi-Fi DNS를1.1.1.1/1.0.0.1로 바꾼 뒤 연속 두 번 갱신에 성공했습니다. v1.3.2는 기본 설치 메뉴가 이 앱을 선택하도록 바꿉니다. 새 패키지 검증과 기존 실제 계정 시험 결과는 구분하며, 최종 v1.3.2의 새 실제 계정 설치 시험은 주장하지 않습니다. 다른 계정·기기·망 및 USB 없는 갱신은 미검증입니다.

[503 연결 경로 비교·DNS 방법](docs/refresh-http-503.md) · [invalid anisette / 이슈14 조사](docs/invalid-anisette.md) · [Reddit·GitHub 해결 및 미해결 사례](docs/community-findings.md). **모든503이나 #14 해결을 보장하지 않으며 iOS hsc434 재동기화는 추가하지 않았습니다.**

임시 서명(ad-hoc)이며 Apple 공증은 없습니다. 차단되면 해당 앱에 대해 시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기(Open Anyway)를 이용하세요. Mac은 macOS27 arm64 전용, iPhone 앱 최소 iOS17.4이며 실제 기기 검증은 iOS27.2입니다. 외부 ani.jkcoxson.com은 anisette와 연결 메타데이터를 처리하며 암호·2FA는 Apple에만 전송됩니다. DNS·보안 설정은 자동 변경하지 않습니다. [보안 안내](SECURITY.md).

Mac 버전1.8-pr1834-public-v1.3.2 / 183402. [AltStore PR1834](https://github.com/altstoreio/AltStore/pull/1834)(ddb4415), [AltSign PR61](https://github.com/rileytestut/AltSign/pull/61)(832d9ce) 기반입니다. 제한된 Apple 정적 crypto·헤더를 제거하고 시스템 private SRP 어댑터와 CryptoKit/CommonCrypto를 사용합니다. 전체 대응 소스·의존성·라이선스·재빌드 스크립트를 함께 제공합니다.

AltStore·SideStore·Apple과 제휴하지 않은 독립 프로젝트입니다. [GNU AGPLv3](LICENSE).
