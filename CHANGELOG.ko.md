# 변경 기록

[English](CHANGELOG.md) | [한국어](CHANGELOG.ko.md)

## v1.3.0 — 소스 전용 정식 릴리스 (2026-10-15)

- `1.8-pr1834-test/1834`로 표시된 Classic 소스 기반 후보입니다. 공식 AltServer 1.8.1 바이너리를 수정한 앱이 아니며, DMG나 다운로드 링크는 없습니다.
- AltStore PR #1834 head `ddb4415cc6aeeb3145de33a29f7064292a45d895`, AltSign PR #61 commit `832d9cec339ea6ef6891011833dbb7227b028a29`에 고정합니다.
- `ani.jkcoxson.com`에서 Windows ADI anisette v3 데이터를 가져와 동일한 `client_info`와 User-Agent를 GSA에 사용합니다. Apple이 요청을 거부하는 원인에 관한 PR 작성자의 설명은 독립적으로 확정된 정책이 아니라 가설입니다.
- 단일 환경에서 공식 AltServer 로그인은 `-80045`, 이전 Pixel descriptor 실험은 HTTP 503을 반환했습니다. 후보 smoke test는 필수 Windows identity 필드를 받았습니다. 관리자는 로그인과 앱 갱신 성공을 보고했습니다. 앞선 화면에는 YouTube가 6일, 다른 앱 두 개가 7일 남은 것으로 표시됐고, 이후 USB 연결에서 세 앱 모두 갱신됐다고 추가 보고했습니다. 사용자 보고이며 앞선 성공의 연결 방식, 무선 동작, 재부팅 뒤 지속성, 전체 사용자 호환성을 입증하지 않습니다.
- 로컬 테스트 후보는 `libcorecrypto_static.a`를 정적으로 링크합니다. upstream `corecrypto/License.txt`는 Apple Internal Use only 및 재배포 금지를 명시합니다. 제한이 해결될 때까지 바이너리 배포는 불가합니다. `SHA256SUMS.txt`에는 다운로드 검증용 소스 archive SHA-256만 기록하며, 별도 `verification-manifest.txt`에는 테스트한 로컬 실행 파일의 provenance용 해시만 기록합니다. 소스 archive에는 `compatibility/v1.3.0/README.md` 패치 안내를 포함합니다.

## 공개 릴리스

게시된 항목의 날짜는 GitHub UTC 기준입니다. 프로젝트 패키지 버전은 공식 AltServer 버전과 별개입니다. 공개 API에서 v1.0.3–v1.0.7 및 v1.1.0의 release/tag는 확인되지 않았습니다. 저장소 기록의 개발 과정은 아래에 별도로 적었으며, 공개되지 않은 번호의 기능이나 검증 결과는 추측하지 않았습니다.

| 프로젝트 버전 | 게시일 (UTC) | 기반 | 변경 및 확인 범위 |
| --- | --- | --- | --- |
| v1.3.0 | 2026-10-15 (소스 전용 정식 릴리스) | Classic 소스 계열 `1.8-pr1834-test/1834` | Windows ADI v3 로그인 흐름. 앱/DMG 없음, corecrypto 라이선스로 바이너리 배포 불가. |
| [v1.2.0](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.2.0) | 2026-10-14 | 1.8.1/build 98 | `-80045` 대상 getter 호환성 수정. Apple Silicon/macOS 27 한 환경에서 기존 앱 3개의 갱신을 확인했습니다. 연결 방식과 더 넓은 호환성은 확인하지 않았습니다. |
| [v1.0.9](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.9) | 2026-09-16 | 1.7.6/build 94 | `machineID` V3 fallback을 DMG로 배포. 테스트한 Apple Silicon/macOS 27 환경에서 설치, 실행, provisioning, AltStore 설치와 갱신을 확인했다고 기록했습니다. |
| [v1.0.8](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.8) | 2026-09-15 | 1.7.6/build 94 | 같은 `machineID` fallback의 소스 전용 배포. maintainer가 install/sideload/refresh 테스트를 보고했으며, 독립적인 exact-match 검증은 제한적입니다. |
| [v1.0.2](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.2) | 2026-06-13 | 1.7.2/build 90 (이전 버전에서 유지) | Gatekeeper 안내를 추가했습니다. 수정 바이너리는 v1.0.1과 같으며 새 runtime 테스트는 기록되지 않았습니다. |
| [v1.0.1](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.1) | 2026-06-13 | 1.7.2/build 90 (이전 버전에서 유지) | 설치 패키지를 간소화하고 설치 전 만든 로컬 백업에서 공식 앱을 복원하도록 바꿨습니다. 수정 바이너리는 v1.0.0과 같으며 새 runtime 테스트는 기록되지 않았습니다. |
| [v1.0.0](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.0.0) | 2026-06-13 | 1.7.2/build 90 | macOS 27 `machineID` 오류를 위한 V3 fallback 최초 공개. Apple Silicon/macOS 27.0 beta가 호환 범위로 적혀 있지만 별도의 runtime 테스트 결과는 기록되지 않았습니다. |

## 릴리스별 기록

### v1.2.0 — `-80045` 호환성 수정 — 2026-10-14

- 공식 AltServer 1.8.1/build 98 기반으로 갱신하고 Mac의 `deviceDescription` getter가 Android 기기 설명을 반환하도록 수정했습니다. iPhone 앱, 저장된 anisette 필드, provisioning, 로그인 흐름은 바꾸지 않았고 V3 fallback도 포함하지 않습니다.
- macOS 27의 Apple Silicon Mac 한 대에 설치한 테스트 빌드에서 iPhone 한 대의 기존 앱 세 개에 Refresh All을 완료했습니다. 세 앱 모두 남은 기간이 7일로 표시됐고 화면에 오류나 2FA 요청은 없었습니다.
- 최종 배포 앱은 strict 서명 검증과 실행 확인을 통과했지만, 그 배포본에서 세 앱 갱신을 다시 했다고 기록하지 않습니다. USB/Wi-Fi 여부, 원격 anisette, 재부팅, 새 로그인/2FA, Intel, 다른 기기·계정, 전체 호환성은 확인하지 않았습니다. 자세한 내용은 [릴리스 안내](releases/v1.2.0.md)를 참고하세요.
- 이후 테스트 환경에서 `-80045`가 재발했습니다. 원인이 확정되지 않았으며 v1.2.0 패치가 문제를 해결한다고 보장하지 않습니다.
- 별도 환경에서 확인된 범위는 설치와 로컬 anisette까지입니다. 갱신 동작이나 Wi-Fi ServerError 2001 해결은 확인하지 않았습니다.

### v1.0.9 — 완성 앱 DMG — 2026-09-16

- 공식 AltServer 1.7.6/build 94 기반의 `machineID` V3 fallback을 완성 앱 DMG로 제공합니다. 공개된 수정은 Mac 쪽에 한정되며 AltServer의 인증 흐름과 공개 V3 provisioning protocol을 바꾸지 않습니다.
- 테스트한 Apple Silicon/macOS 27 환경에서 설치, 실행, anisette provisioning, AltStore 설치와 갱신을 확인했다고 기록했습니다. 이 결과를 다른 Mac, 계정, 네트워크에 일반화하지 않습니다.
- ad-hoc 서명 앱이며 Apple 공증은 받지 않았습니다. Finder로 교체 설치할 때 자동 백업은 만들어지지 않습니다.

### v1.0.8 — 소스 전용 — 2026-09-15

- 공식 AltServer 1.7.6/build 94 기반의 `machineID` fallback 소스와 빌드·설치·복원 문서를 공개했습니다. GitHub 릴리스 asset은 소스 전용이며 수정된 앱이나 기타 binary payload를 포함하지 않습니다.
- maintainer는 macOS 27/iOS 27 환경의 install, sideload, refresh 테스트를 보고했습니다. 독립적인 exact-match 검증은 제한적이며 Apple Silicon용 로컬 빌드에 한정됩니다.

### v1.0.2 — Gatekeeper 안내 — 2026-06-13

- `Install.command`가 차단될 때의 Gatekeeper 허용 절차와 Apple 안내 링크를 추가하고, Gatekeeper/SIP를 시스템 전체에서 끄지 않도록 안내했습니다.
- 수정 바이너리는 v1.0.1과 같으며, 별도 runtime 테스트 결과는 릴리스 기록에 없습니다.

### v1.0.1 — 설치 패키지 간소화 — 2026-06-13

- 중복 소스 및 원본 앱 복사본을 설치 파일에서 제거하고, 복원 스크립트가 설치 전 생성한 로컬 백업에서 공식 AltServer를 복원하도록 변경했습니다.
- 수정 바이너리는 v1.0.0과 같습니다. 이 패키지 변경에 대한 새 runtime 테스트는 기록되지 않았습니다.

### v1.0.0 — V3 fallback 최초 공개 — 2026-06-13

- macOS 27에서 `machineID`를 가져오지 못하는 문제를 대상으로, Foundation 기반 V3 client와 사용자별 identity, 설치·복원 스크립트를 제공했습니다. 공식 AltServer 1.7.2/build 90 기반입니다.
- 릴리스는 Apple Silicon 및 macOS 27.0 beta를 호환 범위로 적었지만, 별도의 runtime 테스트 결과를 보고하지 않았습니다.

## 공개 개발 기록 (릴리스 아님)

- 2026-09-14의 [v1.0.8 준비 커밋](https://github.com/kimziro/altserver-macos27-anisette-fix/commit/6f372b0)은 공개 준비 과정입니다. 이 커밋 자체는 release/tag가 아닙니다.
- UTC 2026-09-15의 [README 간소화 커밋](https://github.com/kimziro/altserver-macos27-anisette-fix/commit/c2647c6)은 문서 변경이며 앱 바이너리 릴리스가 아닙니다.

기존 v1.0.8/v1.0.9의 V3 fallback 기록은 v1.2.0의 getter 수정 및 v1.3.0 후보와 별개입니다.
