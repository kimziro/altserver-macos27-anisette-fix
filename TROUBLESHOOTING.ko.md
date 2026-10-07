# HTTP 503 이후 Apple 계정 잠금 오류 (-20209)

[English](TROUBLESHOOTING.md) | [한국어](TROUBLESHOOTING.ko.md)

갱신이 실패하면 추가 패치 적용 전에 최신 오류 문구부터 확인하세요.
처음 발생한 HTTP 503과 이후의 Apple 계정 잠금은 서로 다른 문제일 수 있습니다.

## 해결이 확인된 사례 — 2026-10-08

환경: macOS 27.0.1 (26A434), 공식 AltServer 1.8.1 (build 98).
이 사례는 저장소의 1.7.6 기반 패치가 아닌 공식 앱을 사용했습니다.

1. 초기 anisette 등록 중 `Apple SPIM endpoint returned HTTP 503`이
   기록됐지만, 이후 요청에서는 등록 성공이 기록됐습니다.
2. AltServer 재시작 전 3회, 재시작 후 3회 모두 로컬 anisette 요청에
   성공했고 machineID와 일회용 암호 필드가 비어 있지 않았습니다.
3. 이후 iPhone의 갱신 오류가 `This Apple Account has been locked for
   security reasons`와 `-20209`로 바뀌었습니다.
4. 같은 계정으로 웹에서 **패스키 로그인**은 가능했습니다. 그러나
   **비밀번호로 새로 로그인**하자 실제 계정 잠금이 확인됐습니다.
5. 사용자가 Apple 절차로 잠금을 해제한 뒤 AltStore 갱신 성공을 확인했습니다.
   추가 코드 패치는 적용하지 않았습니다.

최초 503은 등록 성공 후 재현되지 않았고, 이후 `-20209`는 계정 잠금 해제로
해결됐습니다. 계정 잠금이 최초 SPIM 503의 원인이었다거나, 잠금 해제가
모든 HTTP 503을 해결한다는 의미는 아닙니다.

## 확인 순서

1. 최신 오류가 `-20209`라면 **AltStore → Settings**의 이메일과 웹에서
   확인하는 Apple 계정이 같은지 비교합니다.
2. 브라우저 비공개 창에서 [account.apple.com](https://account.apple.com/)에
   접속해 **비밀번호로 로그인**하고 필요한 인증을 완료합니다.
   패스키 로그인 성공만으로 AltStore가 사용하는 비밀번호 인증까지
   정상이라고 확인할 수는 없습니다.
3. Apple에서도 잠금이 확인되면 안내된 복구 절차 또는
   [iforgot.apple.com](https://iforgot.apple.com/)을 사용합니다.
   해제 후 **Refresh All**을 한 번 실행합니다.
4. 비밀번호도 변경했다면 AltStore에서 로그아웃 후 새 비밀번호로 로그인합니다.
   비밀번호 웹 로그인은 정상인데 AltStore만 실패한다면 최신 오류를 기록하고
   앱 인증 경로를 별도로 확인해야 합니다.

암호, 인증 코드, anisette identity와 가공하지 않은 로그는 공개 이슈에
올리지 마세요. 계정 복구는 Apple에서 직접 진행합니다.

## 참고 자료

- [Apple: 계정이 잠겼거나 비활성화된 경우](https://support.apple.com/ko-kr/102640)
- [Apple: 패스키](https://support.apple.com/ko-kr/guide/iphone/iphf538ea8d0/ios)
- [AltStore: 계정·비밀번호를 사용하는 설치 절차](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)
- [AltStore 이슈 #283](https://github.com/altstoreio/AltStore/issues/283): 과거 이메일이나
  복구 이메일 때문에 웹 로그인은 가능하지만 `-20209`가 표시된 기존 사례입니다.
  이번 사례에서는 이메일이 일치했으므로 해당 원인은 아니었습니다.
