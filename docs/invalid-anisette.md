# Invalid anisette / 이슈 #14 조사

[Issue #14](https://github.com/kimziro/altserver-macos27-anisette-fix/issues/14) reports macOS27 / Apple silicon, initially HTTP503 during USB refresh with LocalDevVPN on and Prefer Remote AltServer off. The reporter later confirms invalid anisette even with v1.3.1. Their running Mac binary, iPhone AltStore version/build, numeric error and failing authentication stage remain unverified.

The date/time and reinstall wording is generic recovery advice; it does not establish clock skew. AltSign maps Apple's ec=-22421 to invalidAnisetteData (API3021). The pinned authentication source also throws that error for hsc434 when no resync handler exists or resync repeats. This is conditional source evidence, not proof that the reporter received434. hsc is a protocol field, not an HTTP status.

Sources: [original error mapping](https://github.com/rileytestut/AltSign/commit/38e932822b0db9ac50613d2e18df4d9c08fa6948), [pinned resync path](https://github.com/kisnner26/AltSign/blob/832d9cec339ea6ef6891011833dbb7227b028a29/AltSign/Sources/ALTAppleAPI%2BAuthentication.swift#L83-L98), [community comparisons](community-findings.md).

Please provide only: (1) Mac/iPhone app version/build and OS versions; (2) full error domain/code/underlying code, existing HTTP/hsc/ec values; (3) install/refresh, before/after2FA, USB/Wi-Fi, LocalDevVPN and Prefer Remote settings. Never publish credentials, OTPs, anisette payloads, identity files, certificates or pairing records.

Inspect automatic date/time and actual clock agreement, relaunch both apps and retry once. Avoid deleting identities or reinstalling as the initial diagnostic step. The new integrated installer does not add iOS hsc434 resynchronization and is not a confirmed fix for #14.

## 한국어

제보자는 v1.3.1에서도 같은 오류라고 밝혔지만, iPhone 앱 버전·빌드와 숫자 오류 코드·발생 단계는 알 수 없습니다. 시간 안내는 일반 복구 문구이므로 시계 오차라고 단정할 수 없습니다. 같은 오류는 Apple ec=-22421 또는 hsc434 재동기화 불가 등에서도 나올 수 있으나, 제보자의 실제 응답은 확인되지 않았습니다.

두 기기의 자동 날짜·시간과 실제 시각을 확인하고 앱을 다시 실행해 한 번 재시도하세요. 필요한 정보는 양쪽 앱·OS 버전, 상세 오류, 설치/갱신 단계와 연결 경로 세 항목입니다. 계정·identity 초기화나 무작정 재설치는 첫 진단 단계로 권하지 않습니다. v1.3.2는 iOS hsc434 재동기화를 추가하지 않으며 #14 해결을 보장하지 않습니다. [커뮤니티 해결·미해결 비교](community-findings.md).
