# 먹킹 개발 인수인계 — 2026-10-01

## 저장소와 범위

- GitHub: https://github.com/Code-Crane/sokk.git, 브랜치: main.
- Git 루트는 sokk이며 앱 프로젝트는 mukking-app 하위에 있다.
- 이번 체크포인트는 기존 작업을 보존한다. 제품 동작을 추가 수정하지 않았다.
- Green UI: Home, 탐색, 식당 상세, 모집 생성/상세, 채팅, MY, 내비게이션과 먹킹 로고/마스코트.
- 펫: healthy/night/hearty 기존 식별자와 성장 데이터 호환성 유지, dog/cat 서버 타입 및 이미지 포함. 현재 UI는 단일 먹킹 마스코트를 표시하고 신규 펫 선택 대신 준비 중 안내를 표시한다. 임의 데이터 변환은 하지 않는다.
- TOWN은 별도 웹 작업이다. 현재 Flutter 앱 개발 범위에서 제외한다. mukking-integration-report.md는 과거 조사와 미래 제안이며 앱 통합 지시가 아니다. 향후 공유 API의 restaurantId, partyId, userId, chatRoomId 의미를 일치시킨다.

## 검증

- flutter analyze --no-pub: No issues found.
- flutter test --no-pub: 249 tests passed.
- 서버/공유 TypeScript typecheck 및 서버 build: 통과.
- node server/scripts/petMemorySmoke.cjs: 109 checks passed (메모리 전용).
- node --check server/scripts/petDogCatLive.cjs: 통과. 실제 DB 테스트는 실행하지 않았다.
- git diff --check: 통과.
- 변경 파일 비밀정보 패턴 및 금지 생성물 검사: 발견 없음. 커밋별 index도 검사한다.
- 이번 체크포인트에서 브라우저 육안 QA, 실기기 QA, 실제 DB 반영 상태는 확인하지 않았다.

## 의도적으로 제외한 항목

- pnpm-lock.yaml: package.json 변경 없이 mobile/admin 항목 제거 등 대규모 재작성 발생. 기존 커밋 버전을 유지한다.
- pnpm-workspace.yaml: 로컬 allowBuilds 추가는 이번 앱/서버 소스 변경에 필요하지 않아 제외한다.
- .env, 키/인증정보, node_modules, build/dist, .dart_tool, 스크린샷과 편집기 생성물은 포함하지 않는다.
- 위 두 pnpm 파일의 로컬 수정은 원래 PC에 그대로 남는다.

## 다른 PC에서 시작하기 (PowerShell)

Flutter/Dart, Git, Node.js와 pnpm을 준비한다. Flutter SDK 기준은 flutter_app/README.md를 참고한다.

```powershell
git clone --branch main https://github.com/Code-Crane/sokk.git
cd sokk/mukking-app/flutter_app
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter run -d chrome --web-port=8081 --dart-define=MUKKING_DATA_PROVIDER=mock
```

이미 복제한 저장소는 작업 변경을 먼저 확인한 뒤 Git 루트에서 실행한다.

```powershell
git status
git switch main
git pull --ff-only origin main
cd mukking-app/flutter_app
flutter pub get
flutter run -d chrome --web-port=8081 --dart-define=MUKKING_DATA_PROVIDER=mock
```

서버 개발이 필요하면 mukking-app 폴더에서 실행한다.

```powershell
pnpm install --frozen-lockfile
pnpm --filter @mukking/server run typecheck
pnpm --filter @mukking/shared run typecheck
pnpm --filter @mukking/server run build
node server/scripts/petMemorySmoke.cjs
```

새 PC에서의 의존성 설치 자체는 이번 세션에서 재현하지 않았다. frozen-lockfile 설치가 실패하면 출력과 pnpm 버전을 먼저 확인하고, lockfile을 무작정 재작성하지 않는다.

## 환경 설정과 이어서 할 일

- 실제 API 연결에는 각 .env.example을 참고하여 인증정보를 별도 안전한 경로로 설정한다. Git에는 실제 값을 넣지 않는다.
- Flutter는 .env를 자동으로 읽지 않는다. API 설정 완료 후 flutter run -d chrome --web-port=8081 --dart-define-from-file=.env를 사용한다.
- supabase/migrations/202609090001_pet_dog_cat.sql은 준비된 변경 파일이다. 이번 작업에서 적용하지 않았고 원격 DB 적용 여부도 확인하지 않았다. 운영 적용은 별도 검토 후 진행한다.
- petDogCatLive.cjs는 실제 계정 생성/삭제가 있는 명시적 수동 검증 도구다. 일반 재개 절차에서 실행하지 않는다.
- 선택적 시각 캡처 테스트는 Windows의 C:/Windows/Fonts/malgun.ttf에 의존한다. 기본 테스트는 캡처 모드를 켜지 않으며 다른 OS에서 캡처하려면 폰트 경로를 준비해야 한다. 생성 이미지는 build 아래에만 둔다.
- 다음 작업: 실제 브라우저에서 Home → 탐색 → 식당 → 모임 → 채팅 → MY 육안 확인. 운영 본인인증 provider, FCM production, 실기기 QA, legacy 펫 정리 여부는 별도 확인한다.
