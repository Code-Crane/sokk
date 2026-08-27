# Mukking Flutter App

먹킹 모바일 앱을 Flutter로 새로 구현하는 독립 프로젝트입니다.
기존 `mobile`, `server`, `admin`, Supabase migration은 수정하지 않습니다.

## Stack

- Flutter / Dart
- Riverpod
- go_router
- Dio
- supabase_flutter

## Required SDK

- Flutter SDK 3.44.0 이상
- Dart SDK 3.12.0 이상

검증 기준:

- Flutter 3.47.1
- Dart 3.13.1

현재 저장소에는 Flutter 코드와 설정 파일을 먼저 구성했습니다.
이 PC에서 `flutter` 명령이 PATH에 없으면 Flutter SDK 설치 후 아래 명령을 실행하세요.

## Clone and run on another PC

다른 PC에서는 한글이 없는 짧은 경로에 clone하는 것을 권장합니다.

권장 예:

```bash
cd C:\dev
git clone https://github.com/Code-Crane/sokk.git
cd sokk/mukking-app/flutter_app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

일반 실행:

```bash
cd mukking-app/flutter_app
flutter pub get
flutter run
```

iOS 실기기/TestFlight 개발은 macOS + Xcode + Apple Developer 계정이 필요합니다.
이번 단계에서는 iOS 실제 빌드를 검증하지 않았습니다.

## Development environment notes

- `android/`, `ios/`, `.metadata`, `pubspec.lock`은 Flutter 앱 프로젝트를 다른 PC에서 이어서 실행하기 위한 정상 파일입니다.
- `build/`, `.dart_tool/`, `.idea/`, `.env` 같은 로컬/빌드 산출물은 commit하지 않습니다.
- 프로젝트 경로에 한글이 포함되어 있으면 일부 Flutter 버전에서 `flutter analyze`가 LSP JSON 파싱 오류로 실패할 수 있습니다.
- 이 경우 `C:\dev\sokk`처럼 한글이 없는 경로에 clone하거나, 한글 없는 junction 경로를 통해 실행하세요.
- 앱 자체 실행과 테스트는 같은 코드 기준으로 정상 확인되었습니다.

## Environment

실제 비밀값은 커밋하지 않습니다.
필요한 공개 환경변수 이름은 `.env.example`에만 기록합니다.

실행 예시:

```bash
flutter run \
  --dart-define=MUKKING_API_BASE_URL=http://localhost:4000 \
  --dart-define=MUKKING_DATA_PROVIDER=mock \
  --dart-define=MUKKING_SUPABASE_URL=https://example.supabase.co \
  --dart-define=MUKKING_SUPABASE_ANON_KEY=public-anon-key \
  --dart-define=MUKKING_KAKAO_NATIVE_APP_KEY=your-native-app-key \
  --dart-define=MUKKING_KAKAO_JAVASCRIPT_KEY=your-javascript-key
```

데이터 소스:

- `MUKKING_DATA_PROVIDER=mock`: 로컬 mock data로 UI 확인
- `MUKKING_DATA_PROVIDER=api`: 기존 Node/Express `/api` endpoint 호출

주의: 이 앱은 `.env` 파일을 자동으로 읽지 않습니다. `flutter run`만 실행하면
`MUKKING_DATA_PROVIDER` 기본값인 `mock`으로 동작합니다. 로컬 `.env`를 사용할 때는
값을 출력하거나 커밋하지 말고 다음처럼 명시적으로 전달하세요.

```bash
flutter run -d chrome --dart-define-from-file=.env
```

현재 backend 개발 기본 CORS 허용 목록에는 `http://localhost:8081`이 포함되어
있습니다. Web API 검증에서는 랜덤 포트 대신 다음 고정 포트를 사용하세요.

```bash
flutter run -d chrome --web-port=8081 --dart-define-from-file=.env
```

`8080`을 사용하려면 backend 실행 환경의 CORS 허용 origin에도
`http://localhost:8080`이 포함되어야 합니다.

API 모드 예시:

```bash
flutter run -d chrome \
  --dart-define=MUKKING_DATA_PROVIDER=api \
  --dart-define=MUKKING_API_BASE_URL=http://localhost:4000 \
  --dart-define=MUKKING_SUPABASE_URL=https://example.supabase.co \
  --dart-define=MUKKING_SUPABASE_ANON_KEY=public-anon-key
```

Flutter bundle에는 Supabase service role key를 넣지 않습니다.
클라이언트에는 공개 가능한 Supabase URL과 anon key만 사용합니다.

## Kakao Map and location

- `kakao_maps_flutter`은 Android/iOS/Web의 Kakao Map SDK를 하나의 Flutter API로 연결합니다.
- Android/iOS에서는 `MUKKING_KAKAO_NATIVE_APP_KEY`, Web에서는 `MUKKING_KAKAO_JAVASCRIPT_KEY`를 사용합니다.
- REST API key, Admin key, Client Secret은 Flutter 앱에 넣지 않습니다.
- 키가 없거나 지도 초기화가 실패하면 지도 fallback을 표시하며 Restaurant API, 목록, 찜 기능은 계속 동작합니다.
- Kakao Developers의 Native app key에 Android 패키지 `com.example.mukking_flutter_app`과 개발/배포 인증서 key hash를 등록합니다.
- 같은 Native app key에 iOS Bundle ID `com.example.mukkingFlutterApp`을 등록합니다.
- JavaScript key의 JavaScript SDK domain에는 Web 개발 주소 `http://localhost:8081`을 등록합니다.
- Kakao Map > 사용 설정에서 지도 API를 활성화해야 합니다.
- 위치 권한은 앱 시작 시 요청하지 않고 발견 화면의 `내 주변 식당` 버튼을 눌렀을 때만 요청합니다.
- 현재 좌표는 메모리에서 nearby API 쿼리에만 사용하며 서버 DB나 위치 이력에 저장하지 않습니다.

Web 확인:

```bash
flutter run -d chrome --web-port=8081 --dart-define-from-file=.env
```

`.env`에는 사용하는 플랫폼의 키 이름만 채우고 실제 값은 커밋하지 마세요.

```dotenv
MUKKING_KAKAO_NATIVE_APP_KEY=
MUKKING_KAKAO_JAVASCRIPT_KEY=
```

## Project structure

```text
lib/
  core/
    config/
    constants/
    network/
    router/
    theme/
  features/
    auth/
    home/
    discovery/
    matching/
    chat/
    profile/
    settings/
  widgets/
```

각 feature는 필요에 따라 `presentation`, `domain`, `data`로 분리합니다.
화면 UI, API 호출, 상태관리, 비즈니스 로직을 한 파일에 섞지 않습니다.

## Native platform folders

`android/`, `ios/` 폴더는 commit 대상입니다.
clone 후에는 보통 아래 명령을 다시 실행할 필요가 없습니다.

만약 플랫폼 폴더를 실수로 삭제했을 때만 아래 명령으로 재생성하세요.

```bash
cd mukking-app/flutter_app
flutter create . --platforms=android,ios
```

이미 `lib`, `pubspec.yaml`, README가 있으므로 앱 코드 구조는 유지됩니다.
