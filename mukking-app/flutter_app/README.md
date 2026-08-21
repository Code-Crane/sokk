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

- Flutter SDK 3.24.0 이상
- Dart SDK 3.5.0 이상

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
  --dart-define=MUKKING_SUPABASE_URL=https://example.supabase.co \
  --dart-define=MUKKING_SUPABASE_ANON_KEY=public-anon-key
```

현재 첫 마일스톤에서는 실제 서버 연결을 크게 붙이지 않고,
UI / Navigation / Theme 기반과 mock data만 사용합니다.

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
