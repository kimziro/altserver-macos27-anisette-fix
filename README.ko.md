# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

macOS 27에서 AltServer 1.7.2로 앱을 설치할 때 다음 오류가 발생하는 문제를
해결하기 위한 비공식 호환 빌드입니다.

```text
AltServer could not retrieve anisette data value "machineID".
```

[최신 릴리스 다운로드](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/latest)

## 호환 환경

- Apple Silicon Mac (`arm64`)
- macOS 27.0 beta
- AltServer 1.7.2, build 90 기반

macOS 27.0 build `26A5353q`에서 테스트했습니다.

## 설치 방법

1. [Releases](https://github.com/kimziro/altserver-macos27-anisette-fix/releases)에서
   `AltServer-macOS27-V3-Fix-v1.0.0.zip`을 다운로드합니다.
2. ZIP 파일의 압축을 풉니다.
3. `Install.command`를 마우스 오른쪽 버튼으로 클릭하고 **열기**를 선택합니다.
4. iPhone에서 AltStore를 열고 앱을 갱신합니다.

iPhone에 AltStore가 이미 설치되어 있다면 **AltStore를 다시 설치할 필요가
없습니다**. Mac에 수정된 AltServer를 설치한 뒤 AltStore의 **My Apps**에서
**Refresh All**을 누르거나 필요한 앱만 개별적으로 갱신하면 됩니다.
AltStore가 사라졌거나 실행되지 않을 때만 재설치하세요.

설치 프로그램은 현재 설치된 AltServer를 백업한 뒤 호환 빌드로 교체합니다.
공식 AltServer 1.7.2로 되돌리려면 같은 압축 파일에 있는
`Restore.command`를 실행하세요.

Gatekeeper나 SIP를 시스템 전체에서 비활성화하지 마세요.

## Apple 계정 2단계 인증

앱을 설치하거나 갱신하는 동안 신뢰하는 Apple 기기에 **Apple 계정 로그인
요청** 알림이 나타날 수 있습니다. AltStore에서 작업을 시작한 직후에
알림이 나타났다면 다음 순서로 진행하세요.

1. 알림에 표시된 Apple 계정이 본인의 계정인지 확인합니다.
2. **허용**을 누릅니다.
3. 표시된 6자리 인증 코드를 AltStore 또는 AltServer가 표시한 입력창에만
   입력합니다.

이는 수정 패치가 새로 추가한 로그인이 아니라 AltServer의 정상적인 Apple
계정 인증 절차입니다. 이 호환성 helper는 6자리 인증 코드를 전달받지
않으며 anisette V3 서버에도 전송하지 않습니다.

본인이 설치나 갱신을 시작하지 않았다면 **허용 안 함**을 누르세요. 인증
코드, 코드가 표시된 화면 캡처, anisette 헤더를 GitHub 이슈, 채팅 또는
지원 요청에 올리거나 타인에게 공유하지 마세요. Apple 알림에 표시되는
위치는 IP 기반의 대략적인 위치이므로 실제 위치와 다를 수 있습니다.

## 작동 방식

AltServer 1.7.2는 macOS 비공개 프레임워크인 `AOSKit`에 anisette 헤더를
요청합니다. macOS 27에서는 이 호출이 오류 `-45070`과 빈 딕셔너리를
반환하기 때문에 AltServer가 `X-Apple-MD-M` 값을 가져오지 못합니다.

이 프로젝트는 다음과 같이 동작합니다.

1. AltServer 앱 번들 내부에서 작은 호환성 라이브러리를 불러옵니다.
2. 런타임에서 `AOSUtilities.retrieveOTPHeadersForDSID:` 메서드만 교체합니다.
3. 공개 anisette V3 프로토콜을 구현한 별도의 Foundation 기반 helper를
   실행합니다.
4. 생성된 V3 헤더를 AltServer가 기대하는 기존 키에 연결합니다.

AltServer의 나머지 코드 서명, 앱 설치, 기기 통신 로직은 변경하지 않습니다.

자세한 구현 내용은 [TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md)를
참고하세요.

## 개인정보 보호

이 호환성 helper는 Apple 계정 이메일, 암호, 세션 쿠키, 2단계 인증 코드를
anisette 서버에 전송하지 **않습니다**. 다만 AltStore와 AltServer는 정상적인
계정 인증 및 앱 서명 과정에서 Apple 서버와 통신합니다.

다음 서버에 연결합니다.

- Apple provisioning 엔드포인트: `https://gsa.apple.com`
- `wss://ani.sidestore.zip/v3/provisioning_session`
- `https://ani.sidestore.zip/v3/get_headers`

개인화된 V3 기기 identity는 다음 위치에 저장됩니다.

```text
~/Library/Application Support/AltServer/RemoteAnisetteUser.json
```

이 파일은 권한 모드 `0600`으로 생성되며 릴리스 압축 파일에는 포함되지
않습니다. 다른 사람과 공유하지 마세요.

공개 anisette 서버를 사용하기 전에 [SECURITY.md](SECURITY.md)를
읽어보세요.

## 소스에서 빌드

필요한 환경:

- Apple Silicon Mac
- macOS 27 Command Line Tools
- 원본 AltServer 1.7.2 앱

```bash
chmod +x scripts/build_release.sh
./scripts/build_release.sh /path/to/original/AltServer.app
```

결과물은 ad-hoc 방식으로 서명됩니다. 자세한 내용은
[BUILDING.md](BUILDING.md)를 참고하세요.

## 검증 항목

모든 릴리스에는 SHA-256 체크섬이 포함됩니다. 배포 패키지는 다음 항목을
검증했습니다.

- 앱 번들 전체의 재귀적 코드 서명 검증
- 새로운 V3 identity를 사용하는 최초 provisioning
- 동일하게 개인화된 V3 identity 재사용
- 원본 AltServer 복원
- 수정된 AltServer 재설치
- 로컬 사용자 이름, 개인 인증서, identity 파일이 배포본에 없는지 확인

## 제한 사항

- 비공식 빌드이며 Apple 공증을 받지 않았습니다.
- 현재 helper 바이너리는 `arm64`만 지원합니다.
- AltServer를 업데이트하면 이 호환 빌드가 덮어쓰일 수 있습니다.
- macOS beta 업데이트로 비공개 프레임워크의 동작이 다시 바뀔 수 있습니다.
- 설정된 anisette V3 서버의 가용성에 영향을 받습니다.

## 크레딧

- [AltStore](https://github.com/altstoreio/AltStore)
- 프로토콜 참고:
  [SideStore RemoteAnisette](https://github.com/SideStore/RemoteAnisette)
- 프로토콜 참고:
  [anisette-v3-server](https://github.com/Dadoum/anisette-v3-server)

이 저장소에는 RemoteAnisette의 소스 파일을 재배포하지 않습니다.

## 라이선스

이 프로젝트와 수정된 AltServer 배포본은
[GNU Affero General Public License v3.0](LICENSE)에 따라 제공됩니다.

이 저장소는 AltStore, SideStore 또는 Apple과 제휴 관계가 없으며 이들의
승인을 받은 프로젝트가 아닙니다.
