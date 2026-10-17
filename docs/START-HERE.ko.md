# AltServer Setup v1.3.2 — 설치 안내

macOS27 / Apple silicon 전용 비공식 실험용 배포본입니다. Mac 1.8-pr1834-public-v1.3.2 / 183402, iPhone AltStore2.3.1 / 6402를 포함합니다.

## 1. Mac에 설치

DMG에서 AltServer를 Applications로 옮기고, 실행 중인 이전 AltServer를 종료한 뒤 새 앱을 여세요. 임시 서명(ad-hoc)이며 Apple 공증은 없습니다. 차단되면 시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기(Open Anyway)의 일반 승인 절차를 따르세요.

## 2. iPhone 연결 및 설치

iPhone을 USB로 연결하고 잠금을 해제한 뒤 신뢰 안내를 직접 완료하세요. 필요한 경우 시스템이 요청하는 개발자 모드·앱 신뢰도 완료하세요. Mac 메뉴 막대 AltServer → **Install AltStore → 자신의 iPhone**을 선택하면 동봉된 패치 앱을 자동 선택합니다. 본인의 Apple 계정과 인증코드를 직접 입력하세요. 기존 AltStore를 교체한다면 같은 계정을 쓰고 먼저 삭제하지 마세요. Safari에서 IPA를 누르는 것만으로 설치되지는 않습니다.

설치 후 iPhone AltStore Settings에서 **2.3.1 / build6402**인지 확인하세요. 받는 사람이 자기 계정으로 서명하며 배포자의 계정이나 페어링 기록은 포함하지 않습니다.

## 3. 처음 갱신할 때

Mac과 iPhone을 같은 Wi-Fi에 두고 USB도 유지하세요. Prefer Remote AltServer를 끄고 한 앱만 갱신하세요. 이 Mac 보조 USB 경로에는 LocalDevVPN이 필요하지 않습니다. 인증서가 바뀌어 큰 앱 전체를 다시 설치하면 1분 이상 걸릴 수 있습니다.

## 4. Wi-Fi에서 HTTP503이 발생하면

USB를 유지하고 iPhone Wi-Fi만 꺼 LTE/5G에서 한 번 비교하세요. 같은 빌드로 이 경로에서는 성공한 사례가 있습니다.

Wi-Fi로 돌아온 뒤 원래 DNS 설정을 기록하세요. 설정 → Wi-Fi → 연결한 망의 ⓘ → DNS 구성 → 수동에서 기존 서버 대신 **1.1.1.1 / 1.0.0.1**을 넣어 저장하고 한 앱만 다시 갱신할 수 있습니다. 시험 환경에서는 이 변경 후 두 번 연속 성공했고 새 프로파일 발급을 확인했습니다. 모든503이 DNS 문제라는 뜻은 아닙니다. 효과가 없거나 접속 문제가 생기면 원래 설정으로 복구하세요.

이 설정은 해당 Wi-Fi에만 적용됩니다. 공유기 내부 이름·DNS 필터에 영향을 줄 수 있고, 수동 DNS만으로 DNS 조회가 암호화되지는 않습니다. [Cloudflare 공식 절차](https://developers.cloudflare.com/1.1.1.1/setup/ios/).

## 다른 오류와 한계

invalid anisette는 별도 조사 중입니다. 두 기기의 자동 날짜·시간과 실제 시각, 양쪽 앱 버전·빌드, 상세 오류 코드·발생 단계를 확인하세요. 날짜 안내만으로 시계가 원인이라고 단정할 수 없습니다. v1.3.2는 iOS hsc434 재동기화를 추가하지 않습니다.

일반 Refresh All은 현재 앱 캐시 또는 프로파일을 사용합니다. 캐시 누락으로 소스에서 다시 다운로드하거나 공식 업데이트를 설치하면 패치가 교체될 수 있으니 문제가 재발하면 버전을 확인하세요.

외부 anisette 서비스 ani.jkcoxson.com은 연결 메타데이터를 볼 수 있습니다. 계정 암호·2FA는 Apple에만 전송됩니다. 추가 인증 진단은 고정 단계와 상태 코드만 기록합니다. DNS·보안 설정은 자동 변경하지 않습니다. 실제 기기 증거는 macOS27.0.1 / iOS27.2 / USB 환경에 한정되며, 다른 OS·계정·기기와 USB 없는 갱신은 보장하지 않습니다.

[503 조사](refresh-http-503.md) · [invalid anisette 조사](invalid-anisette.md) · [커뮤니티 성공·실패 사례](community-findings.md) · [릴리스 및 전체 소스](https://github.com/kimziro/altserver-macos27-anisette-fix/releases/tag/v1.3.2)
