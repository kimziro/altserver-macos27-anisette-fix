# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

## v1.3.1 실험용 사전 릴리스 — macOS 27, Apple silicon 전용

[**macOS 27용 AltServer v1.3.1 다운로드 — DMG**](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.3.1/AltServer-v1.3.1-macOS27-arm64.dmg)

**현재 상태(2026-10-16): USB 설치 성공 확인. iPhone 앱 갱신의 HTTP503은 조사 중입니다.**

AltServer를 Applications 폴더로 드래그하세요. macOS가 차단하면 **시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기(Open Anyway)**를 선택하세요. macOS 보안을 비활성화하지 마세요.

실험용 사전 릴리스이며 임시 서명(ad-hoc)되어 있고 Apple 공증은 없습니다. macOS 27 및 arm64(Apple silicon)가 필요합니다. 외부 anisette 서비스 `ani.jkcoxson.com`을 사용하므로 서비스 가용성과 개인정보 보호에 영향을 받습니다. Apple 계정 암호와 2단계 인증 코드는 Apple에만 전송됩니다.

AltStore Classic [PR #1834](https://github.com/altstoreio/AltStore/pull/1834) (`ddb4415`)와 [AltSign PR #61](https://github.com/rileytestut/AltSign/pull/61) (`832d9ce`) 기반입니다. 버전은 `1.8-pr1834-public-v1.3.1`, 빌드는 `183401`입니다. 이 빌드에서는 Apple 정적 corecrypto 라이브러리와 제한된 헤더를 제거하고, 불투명 인터페이스를 통한 macOS 시스템 private SRP와 CryptoKit/CommonCrypto를 사용합니다. 이는 빌드 구성에 관한 설명이며 더 넓은 법적 판단을 뜻하지 않습니다.

프로토콜 테스트 5/5 통과: PBKDF2 벡터, 잘못된 CBC padding, GCM AAD 변조, 잘못된 SRP 형식 등을 확인했습니다. 별도 핸드셰이크 테스트는 올바른 M2를 수락하고 잘못된 M2를 거부했으며 세션 키가 정확히 일치했습니다. 앱 빌드·실행·Windows identity smoke test도 통과했습니다. 테스트한 macOS 27.0.1/iOS 27.2 환경에서 실제 계정 로그인과 AltStore USB 설치는 성공했습니다. iPhone Refresh All은 세 앱 중 두 앱만 성공했고, YouTube는 연결 오류2002 후 별도 재시도에서 HTTP503이 발생했습니다. 전체 앱 갱신 문제는 아직 해결되지 않았습니다. [v1.3.1 안내](releases/v1.3.1.md)와 [보안 안내](SECURITY.md)를 참고하세요.

본 프로젝트는 독립 프로젝트이며 AltStore, SideStore 또는 Apple과 제휴하거나 승인을 받지 않았습니다. 소스는 [GNU AGPL v3.0](LICENSE) 라이선스입니다.
