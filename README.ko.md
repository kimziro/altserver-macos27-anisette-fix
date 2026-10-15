# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

macOS 27의 Apple 로그인·앱 갱신 `-80045` 오류를 수정합니다.

## v1.2.0 다운로드

[AltServer-macOS27-Anisette-Fix-v1.2.0.dmg 다운로드](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.2.0/AltServer-macOS27-Anisette-Fix-v1.2.0.dmg)

## 설치

1. AltServer를 종료합니다.
2. 교체 전에 현재 앱을 안전한 곳에 복사해 둡니다. DMG를 열고 `AltServer.app`을 **Applications**로 드래그한 뒤 **Replace(교체)**를 선택합니다.
3. Applications에서 앱을 더블클릭합니다. macOS가 차단하면 아래 Gatekeeper 안내를 따르세요.

> **Gatekeeper:** 이 비공식 앱은 ad-hoc 서명만 되어 있고 Apple 공증을 받지 않았습니다. 경고가 표시될 수 있습니다. 먼저 앱을 한 번 더블클릭해야 **그래도 열기** 버튼이 나타날 수 있습니다. 차단되면 **시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기**로 이동한 뒤 **열기**를 확인하세요. Gatekeeper나 SIP를 시스템 전체에서 끄지 마세요.

## 수정 내용

- Mac 앱을 AltServer **1.8.1 (build 98)**로 업데이트합니다. `v1.2.0`은 이 프로젝트의 패키지 버전입니다.
- Mac 쪽만 수정합니다. iPhone 앱을 변경하지 않으며 AltStore를 다시 설치할 필요가 없습니다.

iPhone에 AltStore가 이미 설치되어 있으면 다시 설치하지 마세요. 이 Mac 앱으로 새로 고침할 때는 **Prefer Remote**를 끄세요. 무선 새로 고침을 별도로 시험한다면 Mac과 iPhone을 같은 Wi-Fi에 연결하세요. 이 release의 무선 동작은 검증되지 않았습니다.

## 검증 범위

2026-10-14, macOS 27을 실행하는 Apple Silicon Mac 한 대에서 설치된 v1.2.0 테스트 빌드로 기존 앱 세 개에 Refresh All을 완료했고, 세 앱 모두 남은 기간이 7일로 표시됐습니다. 화면에 오류나 2FA 요청은 없었습니다. 무선 연결, 원격 anisette, 재부팅, 새 로그인/2FA, Intel 또는 전체 환경 호환성을 입증한 결과는 아닙니다.

## 버전 이력

아래는 이 프로젝트의 패키지 버전이며 공식 AltServer 앱 버전과 다릅니다.

| 프로젝트 버전 | 요약 |
| --- | --- |
| v1.2.0 | 공식 AltServer 1.8.1/build 98 기반, `-80045` getter 호환성 수정 |
| v1.0.9 | `machineID` V3 fallback 완성 앱 DMG |
| v1.0.8 | `machineID` V3 fallback 소스 전용 공개 |
| v1.0.2 | Gatekeeper 설치 안내 |
| v1.0.1 | 설치 패키지 간소화 및 로컬 백업 복원 흐름 |
| v1.0.0 | AltServer 1.7.2/build 90 기반 V3 fallback 최초 공개 |

날짜와 버전별 변경·검증 범위·한계는 [CHANGELOG.ko.md](CHANGELOG.ko.md)를 참고하세요.

앱은 ad-hoc 서명만 되었고 Apple 공증을 받지 않았습니다. 설치 전에 [SECURITY.md](SECURITY.md)를 읽으세요. [release 안내](releases/v1.2.0.md), [빌드 안내](BUILDING.md), [upstream 출처](UPSTREAM_SOURCE.md), [제3자 고지](THIRD_PARTY_NOTICES.md), [변경 기록](CHANGELOG.md)을 참고하세요. 이전 [설치 안내](INSTALLATION.ko.md)와 [기술 설명](TECHNICAL_DETAILS.md)은 v1.0.8/v1.0.9 V3 fallback 문서이며 이 release에 해당하지 않습니다.

이 프로젝트는 AltStore, SideStore 또는 Apple과 제휴하거나 승인을 받지 않았습니다. 소스는 [GNU AGPL v3.0](LICENSE) 라이선스입니다.
