# iPhone refresh: HTTP 503 after successful Mac installation

Updated 2026-10-16. This is an investigation record from one setup, not a universal fix.

## What was observed

The released AltServer v1.3.1 signed in and installed AltStore over USB on macOS 27.0.1 / Apple silicon with an iPhone on iOS 27.2. Refresh from the iPhone still failed intermittently.

A **local, unpublished experimental iPhone client**, AltStore 2.3.1/build 6402, was used for further diagnosis. Its results do not establish that the public DMG plus the official iPhone client fixes refresh.

| Test with the same experimental iPhone client | Observed result |
| --- | --- |
| Same Wi-Fi as the Mac, before the DNS change; iPhone VPN off | HTTP 503 at the first GrandSlam `init` request; one successful refresh followed by another 503 |
| USB retained; iPhone Wi-Fi off; LTE/5G | Refresh succeeded |
| USB retained; original Wi-Fi with only DNS changed to `1.1.1.1` / `1.0.0.1` | Two consecutive refreshes succeeded; device profile renewal independently confirmed |

This comparison suggests that the network path contributes to the failure. The successful Wi-Fi test after the DNS change identifies a working configuration for this setup; it does not establish a universal DNS fault, ISP block, or Apple policy. The Mac's anisette requests returning HTTP 200 does not establish that the iPhone's separate Apple authentication requests succeeded.

For a similar failure, a useful comparison is to retain the trusted USB connection, unlock the iPhone, temporarily turn off only its Wi-Fi, and refresh the affected app over cellular. The maintainer confirmed success in this configuration. The maintainer then changed only the iPhone’s per-network Wi-Fi DNS to `1.1.1.1` and `1.0.0.1` and reported success. The Mac logged provisioning-profile installation, and the device held a newly issued profile expiring seven days later. A second consecutive Wi-Fi refresh also succeeded. Both tests completed provisioning-profile installation, and the device’s profile creation and expiry dates advanced.

To try the same per-network DNS configuration, record the original settings, then follow [Cloudflare’s official iOS instructions](https://developers.cloudflare.com/1.1.1.1/setup/ios/): Settings → Wi-Fi → ⓘ → Configure DNS → Manual, use only `1.1.1.1` and `1.0.0.1`, and save. Restore the original settings if it does not help. This test retained USB and used the unpublished experimental iPhone client; wireless-only refresh and the official client are not established by it.

A separate [AltStore community report](https://github.com/altstoreio/AltStore/issues/1825) describes network-dependent HTTP 503 on another ISP. It is supporting context, not proof of this setup's cause.

## Why the first successful refresh took longer

The old and new YouTube provisioning profiles used different signing certificates. AltStore's [app manager](https://github.com/altstoreio/AltStore/blob/ddb4415cc6aeeb3145de33a29f7064292a45d895/AltStore/Managing%20Apps/AppManager.swift) chooses full signing and reinstallation when the certificate changes. File transfer took about 57 seconds and device installation about 9 seconds in this test. A later cellular refresh used only provisioning-profile installation, with about 8 seconds between the first observed Mac response and completion. These are observations, not timing guarantees.

ServerError 2002 means the AltServer connection was lost. It is a separate failure from AppleDeveloperError 3000 / HTTP 503 during Apple authentication.

## 한국어

공개 AltServer v1.3.1의 Mac 로그인과 USB 설치는 성공했지만, iPhone 갱신의 503은 간헐적으로 재발했습니다. 추가 진단에는 **아직 공개하지 않은 iPhone 시험판 2.3.1/build 6402**를 사용했습니다. 이 결과를 공개 DMG와 공식 iPhone 앱 조합의 갱신 성공으로 확대하면 안 됩니다.

동일 시험판에서 같은 Wi-Fi/VPN 꺼짐 상태는 첫 인증 요청 `init`에서 503이 재발했고, USB를 유지한 채 iPhone Wi-Fi를 끈 LTE/5G 상태에서는 갱신이 성공했습니다. 이후 같은 Wi-Fi에서 iPhone의 해당 네트워크 DNS만 `1.1.1.1` / `1.0.0.1`로 변경하자 갱신이 성공했습니다. 사용자 보고와 별도로 Mac의 프로파일 설치 완료 및 기기의 새 프로파일을 확인했습니다. 같은 설정에서 두 번째 연속 갱신도 성공했고, 기기의 새 프로파일 발급 시각이 다시 갱신됐습니다. 이 환경에서 동작한 설정이며 모든 503의 원인이 DNS라는 뜻은 아닙니다.

동일하게 시험하려면 원래 DNS 설정을 기록한 뒤 설정 → Wi-Fi → 연결한 망의 ⓘ → DNS 구성 → 수동에서 위 두 주소만 넣고 저장합니다. 효과가 없으면 원래 설정으로 복구합니다. USB와 미공개 iPhone 시험판을 사용한 결과이므로 USB 없는 무선 갱신이나 공식 iPhone 앱의 성공까지 입증하지는 않습니다.

처음 오래 걸린 갱신은 서명 인증서가 바뀌어 앱 전체를 다시 설치한 경우였습니다. 파일 전송 약 57초, 설치 약 9초였고, 이후 LTE 갱신은 프로파일만 교체해 Mac의 첫 응답부터 완료까지 약 8초였습니다. 모든 환경의 갱신 시간을 보장하는 수치는 아닙니다.

시험판의 자체 갱신이나 Refresh All 과정에서 공식 iPhone 앱으로 교체될 수 있으므로, 진단 시에는 설치된 버전과 빌드를 다시 확인하고 대상 앱만 갱신합니다. 계정 암호, 인증코드, anisette 값, 인증서 및 페어링 자료는 공개하지 마세요.
