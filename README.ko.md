# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

macOS 27에서 다음 오류가 발생할 때 사용하는 비공식 호환성 패치입니다.

```text
AltServer could not retrieve anisette data value "machineID".
```

## [⬇️ v1.0.9 release에서 다운로드](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/download/v1.0.9/AltServer-macOS27-Anisette-Fix-v1.0.9.dmg)

v1.0.9 release가 게시되면 이 링크를 사용할 수 있습니다.
v1.0.9 release의 완성된 앱 asset
`AltServer-macOS27-Anisette-Fix-v1.0.9.dmg`를 다운로드하세요. Mac 쪽 문제를
수정한 `AltServer.app`이 포함되어 있습니다.

## 설치 (3단계)

1. **AltServer를 종료합니다.**
2. **DMG를 열어 설치합니다.** DMG를 더블클릭한 다음 `AltServer.app`을
   **Applications**로 드래그하세요. 기존 앱을 교체할지 묻는 경우
   **Replace**를 선택합니다. 선택 사항으로, Replace 전에 현재 공식 앱을
   안전한 폴더에 직접 복사해 두세요. 드래그 설치는 자동 백업을 만들지
   않습니다.
3. **Finder에서 올바르게 엽니다.** Applications에서 `AltServer.app`을
   Control-click하고 **Open**을 선택한 뒤 다시 **Open**을 확인합니다.

> **Gatekeeper 안내:** 비공식 앱이며 ad-hoc 서명만 되어 있고 Apple 공증
> (notarized)을 받지 않았으므로 경고가 표시되는 것이 정상입니다. macOS가
> 차단하면 한 번 열기를 시도한 뒤 `System Settings → Privacy & Security → Security → Open Anyway → Open`
> 순서로 진행하세요. Mac 로그인 암호를 요구할 수 있습니다. **Gatekeeper나
> SIP를 끄거나 `xattr` 명령으로 우회하지 마세요.**

## 호환성 및 범위

- Apple Silicon Mac에서 macOS 27을 실행해야 합니다.
- 포함된 Mac 앱 버전은 `1.7.6-macOS27-v3.8` (build 94)입니다.
- Mac 쪽 anisette 경로만 수정합니다. 공식 Mac AltServer를 사용하면 iPhone의
  AltStore 1.8.0 앱에서 `machineID` 오류가 계속 발생할 수 있습니다. 이 DMG는
  Mac AltServer만 교체하며 AltStore 앱이나 iPhone 전송 방식을 교체하지
  않습니다.

## 설치 후

1. AltServer를 실행하고 메뉴 막대에 아이콘이 나타나는지 확인합니다.
2. iPhone을 연결하고 신뢰(Trust)합니다.
3. 처음 설치할 때는 **Install AltStore…**, 이후에는 필요할 때 **Refresh**를
   사용합니다. 처음 anisette 데이터를 provision할 때 네트워크 연결이
   필요합니다.

## 복원 및 업데이트

공식 앱으로 되돌리려면 AltServer를 종료하고 Applications의 패치된
`AltServer.app`을 제거하거나 다른 곳으로 이동한 뒤, 직접 저장해 둔 공식
앱을 복원하세요. 저장한 사본이 없으면 [공식 AltServer 1.7.6
archive](https://cdn.altstore.io/file/altstore/altserver/1_7_6.zip)를 다시
다운로드하세요.

macOS 또는 AltServer 업데이트가 패치를 덮어쓸 수 있습니다. workaround가
작동하지 않으면 DMG를 다시 설치하세요. 이 프로젝트는 비공식이며 AltStore,
SideStore 또는 Apple과 제휴·승인을 받지 않았습니다.

## 개인정보와 보안

Anisette provisioning data는 민감할 수 있습니다. 신뢰하는 서비스와
네트워크만 사용하고 실행 전에 [SECURITY.md](SECURITY.md)를 읽으세요. Apple
계정 자격 증명·코드, identity file, device ID 또는 가공하지 않은 로그를
공유하지 마세요.

## 고급 사용 및 자세한 문서

소스 빌드와 구현 세부사항은 [BUILDING.md](BUILDING.md),
[INSTALLATION.ko.md](INSTALLATION.ko.md), [TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md),
[UPSTREAM_SOURCE.md](UPSTREAM_SOURCE.md)를 참고하세요. 이전 v1.0.8 release는
source-only였습니다.

- [SECURITY.md](SECURITY.md) — 개인정보와 threat model
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) — 의존성 고지
- [CHANGELOG.md](CHANGELOG.md) — release 기록
- [LICENSE](LICENSE) — 이 source에 적용되는 GNU AGPL v3.0
