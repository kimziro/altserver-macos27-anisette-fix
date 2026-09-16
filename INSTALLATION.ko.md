# 설치 안내

[English](INSTALLATION.md) | [한국어](INSTALLATION.ko.md) | [README](README.ko.md)

v1.0.9 release asset은 패치된 `AltServer.app`이 들어 있는 완성된 앱 DMG입니다.
대부분의 사용자는 [README.ko.md](README.ko.md)에 따라 이를 받아 앱을
Applications로 드래그하면 됩니다. 이 문서는 v1.0.9 / v3.8의 고급 source build와
installer 안내입니다. 저장소 source tree에는 source, script, reference와 문서가
있고, 이전 v1.0.8 / v3.7 공개는 역사적인 source-only 공개였습니다.
이 문서는 iPhone IPA를 빌드하거나 패키징하지 않습니다.

테스트 대상은 Apple Silicon Mac의 네이티브 `arm64` macOS 27이며 공식
AltServer 1.7.6/build 94를 사용합니다. Rosetta와 다른 macOS 버전은
지원·검증하지 않습니다. 현재 macOS 27/iOS 27 환경에서 maintainer가
설치, sideload 및 refresh를 테스트했지만 독립적인 exact-match 검증은
제한적입니다.

## 1. 공식 입력 다운로드와 검증

다음 버전 고정 공식 archive만 사용하세요.

```text
https://cdn.altstore.io/file/altstore/altserver/1_7_6.zip
SHA-256  ea4c47fa25abc0166bd4e9785f96f82488e6606b2e015ff046f8fceee083e6b9
```

private 임시 파일로 받은 뒤 압축을 풀기 전에 hash를 확인합니다.

```bash
set -euo pipefail
official_zip="$(mktemp -t altserver-1_7_6.XXXXXX.zip)"
curl -fL \
  'https://cdn.altstore.io/file/altstore/altserver/1_7_6.zip' \
  -o "$official_zip"
printf '%s  %s\n' \
  'ea4c47fa25abc0166bd4e9785f96f82488e6606b2e015ff046f8fceee083e6b9' \
  "$official_zip" | shasum -a 256 -c -
official_dir="$(mktemp -d)"
unzip -q "$official_zip" -d "$official_dir"
official_app="$(find -P "$official_dir" -type d -name AltServer.app -print -quit)"
test -n "$official_app" -a -d "$official_app"
```

이미 수정된 앱으로 빌드하지 마세요. build script가 bundle identifier,
version/build, universal 실행 파일, 공식 서명, Gatekeeper 평가,
notarization ticket과 승인된 주 실행 파일 hash를 다시 확인합니다.

## 2. 로컬 payload 빌드

저장소를 clone하거나 checkout한 뒤 루트에서 실행합니다.

```bash
mkdir -p out
./scripts/build_release.sh "$official_app" "$PWD/out/v1.0.9"
```

성공한 출력 디렉터리에는 다음 네 일반 파일만 있습니다.

```text
AltServer-macOS27-v3.8.zip
AltServer-macOS27-v3.8.executables.txt
BUILD-METADATA.txt
CHECKSUMS-SHA256.txt
```

ZIP은 private 로컬 빌드 결과이며 GitHub asset이 아닙니다. 기존
`out/v1.0.9`은 현재 명령이 성공할 때까지 stale입니다. staging 전에
`CHECKSUMS-SHA256.txt`와 `BUILD-METADATA.txt`를 확인하세요. script는 ZIP
옆에 IPA, profile, 인증서 또는 raw app을 만들지 않습니다.

## 3. Installer staging과 검증

현재 `scripts/Install.command`는 flat layout 또는 `Payload/` layout을
지원합니다. 재현 가능한 staging은 top-level에 script를 두고
`Payload/` 바로 아래에 출력 네 파일만 두는 private 디렉터리입니다.

```bash
stage_dir="$(mktemp -d)"
cp scripts/Install.command scripts/Restore.command "$stage_dir/"
mkdir "$stage_dir/Payload"
cp out/v1.0.9/AltServer-macOS27-v3.8.zip \
   out/v1.0.9/AltServer-macOS27-v3.8.executables.txt \
   out/v1.0.9/BUILD-METADATA.txt \
   out/v1.0.9/CHECKSUMS-SHA256.txt "$stage_dir/Payload/"
chmod +x "$stage_dir/Install.command" "$stage_dir/Restore.command"
```

실제 설치 전에 AltServer를 종료하세요. 먼저 staging 디렉터리에서 non-root
dry-run을 실행합니다. 이 명령에는 `sudo`를 붙이지 않습니다.

```bash
(cd "$stage_dir" && ALTSERVER_INSTALL_DRY_RUN=1 ./Install.command)
```

dry-run은 private temporary directory에 압축을 풀고 ZIP, manifest,
metadata, checksum, bundle metadata, architecture, symlink, executable
mode, recursive signature 및 helper/dylib 각각의 정확히 하나인 valid
nonzero `LC_UUID`를 검사합니다. `/Applications`나 Application Support를
변경하지 않았다는 결과가 나와야 합니다. 임시 추출·검증 파일은 정상입니다.

macOS가 script를 차단하면 Finder에서 한 번 열기를 시도한 뒤
**시스템 설정 > 개인정보 보호 및 보안**에서 이 script의 **그래도 열기**를
선택하고 **열기**를 확인하세요. 요청하면 Mac 로그인 암호를 입력합니다.
이 예외는 해당 script에만 적용되며 Gatekeeper나 SIP를 시스템 전체에서
비활성화하지 마세요.

## 4. 수정된 AltServer 설치

dry-run이 성공하고 AltServer가 종료된 상태에서 현재 installer가 요구하는
명령을 실행합니다.

```bash
(cd "$stage_dir" && sudo ./Install.command)
```

`sudo`가 요구하는 것은 Mac 로그인 암호이며 Apple 계정 암호가 아닙니다.
실제 설치는 root 전용이고 유효한 non-root `SUDO_USER`가 필요합니다.
script는 해당 사용자의 canonical home에 백업을 저장하며
`/Applications/AltServer.app`만 검증 후 교체합니다. 트랜잭션 실패 시
관리자용 우회 경로를 시도하지 않고 recovery path를 보존·출력합니다.

백업 구조는 다음과 같습니다.

```text
~/Library/Application Support/AltServer-macOS27-Fix/Backups/
└── AltServer-<UTC>.<pid>.<rand>.backup/
    ├── AltServer.app
    └── metadata
```

Install과 Restore는 shared root lock과 descriptor-bound identity 검사를
사용합니다. 실행 파일 경로가 정확히
`/Applications/AltServer.app/Contents/MacOS/AltServer`인 프로세스만
종료하며 먼저 `TERM`을 보내고 같은 경로가 남을 때만 `KILL`을 보냅니다.
Production transaction에서는 backup-root·target-path override를 거부합니다.
허용되는 유일한 override는 non-root dry-run 검증용 canonical private
owner-owned `$HOME/.altserver-install-*/Backups` fixture입니다.

설치가 끝나면 `/Applications`에서 AltServer를 실행하세요. 버전 표시는
다음과 같아야 합니다.

```text
1.7.6-macOS27-v3.8 (94)
```

공식 AltServer 업데이트가 이 로컬 호환 빌드를 덮어쓸 수 있습니다. macOS
27 오류가 다시 나타나고 수정이 계속 필요하면 검증된 로컬 빌드를 다시
설치하세요. payload 버전을 섞지 마세요.

## 5. iPhone에 AltStore 설치·갱신

iPhone을 연결하고 신뢰(Trust)한 뒤 AltServer의 공식 **Install AltStore…**
절차를 사용합니다. 기기를 선택하고 Apple의 정상적인 안내를 완료하세요.
AltStore가 이미 설치되어 정상적으로 열리면 Mac 앱이 바뀌었다는 이유만으로
재설치하지 말고 **My Apps > Refresh All**을 사용하세요.

정상 흐름에서 **Apple Account Sign-In Requested** 알림과 6자리 코드가
나타날 수 있습니다. 직접 시작한 작업이고 표시된 계정이 본인일 때만
승인하세요. 코드는 AltStore 또는 AltServer의 prompt에만 입력합니다.
예상하지 않은 알림은 **Don't Allow**를 선택하세요. helper는 코드를
보거나 anisette 서비스로 보내지 않습니다.

## 6. 다른 앱 sideload와 refresh

신뢰할 수 있는 출처에서 IPA를 받은 뒤 iPhone의 AltStore에서
**My Apps > +**를 누르고 IPA를 선택합니다. 인증은 AltStore/AltServer의
정상 UI에서만 진행하세요. 이 저장소는 IPA를 제공하지 않으며 Apple의
서명 요구사항을 바꾸지 않습니다.

**My Apps > Refresh All**로 설치된 앱을 갱신합니다. 같은 계정 승인 또는
코드가 필요할 수 있습니다. 버전 표시가 `1.7.6-macOS27-v3.8 (94)`가
아니면 AltServer를 종료하고 local metadata와 staging 경로를 확인한 뒤
payload 버전을 섞지 마세요.

## 7. 공식 앱 복원

AltServer를 종료한 뒤 staging 디렉터리의 restore script를 `sudo`로
실행합니다.

```bash
(cd "$stage_dir" && sudo ./Restore.command)
```

Restore는 Install이 만든 최신 검증 백업을 선택합니다. 검증된 백업 경로를
직접 전달할 수도 있습니다.

```bash
(cd "$stage_dir" && sudo ./Restore.command \
  "$HOME/Library/Application Support/AltServer-macOS27-Fix/Backups/AltServer-<UTC>.<pid>.<rand>.backup")
```

인접한 `.metadata`를 가진 legacy `AltServer-<UTC>.<pid>.<rand>.app`
레코드도 검증합니다. 복원 후 백업은 보존됩니다. 실제 Restore는 root
전용이며 non-root read-only 검증은 다음과 같습니다.

```bash
(cd "$stage_dir" && ALTSERVER_INSTALL_DRY_RUN=1 ./Restore.command)
```

검증된 백업이 없으면 파일을 삭제하거나 추측하지 말고
[altstore.io](https://altstore.io/)에서 공식 앱을 받으세요.

## 문제 해결

| 증상 | 다음 조치 |
| --- | --- |
| `AltServer could not retrieve anisette data value "machineID".` | 네이티브 Apple Silicon, `1.7.6-macOS27-v3.8 (94)` 표시, 설치 성공과 재실행 여부를 확인하세요. |
| HTTP `503`, `401` 또는 `apptokens` | 네트워크와 설정한 anisette 서비스를 확인하세요. 공식 1.7.6에 보고된 503 처리가 있지만 upstream/service 장애는 남을 수 있습니다. |
| `3840`, JSON 안 HTML 또는 parse 오류 | upstream/proxy 오류로 보고 응답 본문·header를 공유하지 말고 나중에 재시도하세요. |
| AltStore가 없음 | 공식 **Install AltStore…** 절차를 사용하세요. 이 프로젝트의 custom IPA는 필요하지 않습니다. |
| iPhone refresh가 계속 실패함 | 이 패치는 Mac 쪽 `machineID` 경로만 다룹니다. 기기 내 transport 또는 AltStore 업데이트가 필요할 수 있습니다. |
| macOS가 command를 차단함 | 위 script별 **그래도 열기** 절차를 따르세요. Gatekeeper나 SIP를 전체 비활성화하지 마세요. |

## 개인정보와 지원 로그

helper의 전용 URLSession은 ephemeral이며 sanitized 상태입니다. cookie,
URL credential storage, cache와 상속된 additional header를 비활성화하거나
비웁니다. HTTPS/WSS 요청은 설정된 secure origin에 머물고 redirect도
scheme, host와 effective port가 같을 때만 허용합니다. HTTP response와
WebSocket message는 각각 1 MiB로 제한됩니다. helper는 Apple ID/Apple 계정 email,
암호, session cookie, 2단계 코드 또는 authorization header를 anisette
서비스에 받거나 보내지 않습니다.

기본 V3 서비스는 `https://ani.sidestore.zip`입니다. 개인화된 identity는
`~/Library/Application Support/AltServer/RemoteAnisetteUser.json`에 mode
`0600`으로 로컬 저장되며 공개되거나 출력 디렉터리에 포함되지 않습니다.
공개 서비스를 사용하기 전에 [SECURITY.md](SECURITY.md)를 읽고, 필요하면
source를 바꾸어 self-hosted service용으로 다시 빌드하세요.

identity는 owner를 확인한 private support 디렉터리 descriptor에 상대적으로
열립니다. 디렉터리는 owner 소유이고 mode `0700`이어야 하며, identity는
owner 소유의 regular file이고 mode가 정확히 `0600`, hard link가 하나여야
합니다. no-follow와 nonblocking open으로 symlink, FIFO와 다른 non-regular
entry를 거부하고, 읽기는 64 KiB로 제한합니다. 새 identity는 고유한 `0600`
exclusive 임시 파일에 쓰고 `fsync`한 뒤 exclusive publish하므로 동시 실행이
기존 entry를 바꿀 수 없습니다. 기존 identity가 이 검사를 통과하지 못하면
helper는 사용하지 않으므로, 검토·격리 후 provisioning을 다시 실행해야 할
수 있습니다.

도움을 요청할 때는 짧게 redacted한 오류, architecture, macOS 버전,
AltServer version/build와 실패 단계만 공유하세요. Apple 계정 정보,
device ID/serial/UDID, 사용자 이름과 home 경로, backup 이름, anisette
header/token, identity file, IP/위치와 개인을 특정할 수 있는 timestamp를
제거하세요. 가공하지 않은 전체 로그·화면 캡처·계정 prompt는 업로드하지
마세요.
