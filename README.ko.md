# AltServer macOS 27 Anisette Fix

[English](README.md) | [한국어](README.ko.md)

AltStore Classic 소스를 바탕으로 한 macOS 27 로그인 실험입니다. **v1.3.0은 2026-10-15 소스 전용 사전 릴리스이며 앱이나 DMG가 없습니다.** 공식 AltServer 업데이트가 아닙니다. 이전 v1.2.0 앱에서는 `-80045`가 재발해 사용을 권하지 않습니다.

## 변경 내용

v1.2.0은 anisette 기기 설명 getter만 바꿨고, 이후 `-80045`가 다시 발생했습니다. v1.3.0 후보는 대신 `ani.jkcoxson.com`에서 Windows ADI anisette 데이터를 가져오고, 이에 맞는 client identity와 User-Agent로 Mac 로그인 요청을 보냅니다. 문자열만 바꾸는 수정은 아닙니다. [release 안내](releases/v1.3.0.md), [보안 안내](SECURITY.md), [upstream 출처](UPSTREAM_SOURCE.md)를 참고하세요.

## 검증 범위

테스트에서 공식 앱은 `-80045`를 반환했고, 이전 Pixel descriptor 실험은 HTTP 503을 반환했습니다. v1.3.0 후보 smoke test는 Windows identity에 필요한 anisette 필드를 모두 받았습니다. 관리자는 로그인 및 앱 갱신 성공을 보고했습니다. 앞선 화면에는 YouTube가 6일, 다른 앱 두 개가 7일 남은 것으로 표시됐고, 이후 iPhone을 USB로 연결한 상태에서 세 앱 모두 갱신됐다고 추가 보고했습니다. 이는 제한된 사용자 보고입니다. USB 결과로 앞선 테스트의 연결 방식이 USB였는지는 알 수 없으며, 무선 동작·재부팅 뒤 지속성·Apple 측 원인·폭넓은 호환성은 확인되지 않았습니다.

후보는 [AltStore PR #1834](https://github.com/altstoreio/AltStore/pull/1834)와 [AltSign PR #61](https://github.com/rileytestut/AltSign/pull/61)에 기반합니다. `1.8-pr1834-test/1834`로 표시된 Classic 소스 기반 앱이며, 공식 AltServer 1.8.1 바이너리 패치가 아닙니다. upstream [corecrypto 라이선스](https://github.com/rileytestut/AltSign/blob/832d9cec339ea6ef6891011833dbb7227b028a29/Dependencies/corecrypto/License.txt)는 Apple Internal Use only 및 재배포 금지를 명시합니다. 소스 전용 사전 릴리스에 앱/DMG/바이너리는 없으며, 바이너리 배포는 이 제한이 해결될 때까지 보류됩니다. 소스 archive에는 `compatibility/v1.3.0/README.md` 패치 안내를 포함합니다.

## 버전 이력

프로젝트 패키지 버전과 AltServer 앱 버전은 서로 다릅니다.

| 프로젝트 버전 | 요약 |
| --- | --- |
| v1.3.0 (2026-10-15 소스 전용 사전 릴리스) | Windows ADI anisette identity와 User-Agent를 맞추는 Classic 소스 기반 로그인 흐름. 앱/DMG 없음, 바이너리 배포 제한 |
| v1.2.0 | getter만 변경한 AltServer 1.8.1/build 98 기반 패키지. 이후 `-80045` 재발 |
| v1.0.9 | 이전 `machineID` V3 fallback DMG |
| v1.0.8 | 이전 `machineID` V3 fallback 소스 공개 |

이전 v1.0.8/v1.0.9 V3 fallback 문서는 과거 구현을 설명하며 이 후보와 다릅니다. 이 독립 프로젝트는 AltStore, SideStore 또는 Apple과 제휴하거나 승인을 받지 않았습니다. 소스는 [GNU AGPL v3.0](LICENSE) 라이선스입니다.
