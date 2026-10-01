# 먹킹 외부 ‘동네 씬’ 통합 사전 조사

조사일: 2026-09-29. 대상: `C:\mukking-app` (실제 연결 대상: `C:\Users\User\Desktop\AX\sokk\mukking-app`).

이 문서는 현재 작업 폴더의 소스·패키지 선언·SQL 마이그레이션을 읽어 확인한 결과다. 기존 미커밋 변경도 조사 시점의 구현에 포함한다. 애플리케이션 실행, 로그인, 외부 API 호출, 운영 DB 조회, 테스트·마이그레이션 실행은 하지 않았다. 배포 상태·실제 DB 반영 여부·외부 동네 씬 소스와의 호환성은 **확인 필요**다. 실제 환경 파일 값은 읽거나 인용하지 않았으며 환경변수는 이름만 기록한다. 아래 경로는 대상 프로젝트 루트 기준이다.

## 1. 통합 준비도와 기술 스택

**현재 앱은 Next.js/React 앱이 아니라 Flutter 앱 + Express 서버다. 외부 `src/features/town`을 그대로 넣어 실행할 기존 React 호스트는 확인되지 않는다. 모집·신청·채팅 REST API는 재사용할 수 있다.**

| 항목 | 저장소에서 확인한 내용 | 근거 |
|---|---|---|
| Next.js / React | 루트·server·shared package.json에 선언 없음. 버전 확인 불가 | `package.json`, `server/package.json`, `shared/package.json` |
| TypeScript | server·shared 모두 `^5.5.4` 선언 | 각 package.json |
| @supabase/supabase-js | server에 `^2.112.3` 선언 | `server/package.json` |
| @supabase/ssr | 확인한 package.json에 선언 없음 | 위 세 package.json |
| 라우터 | Next App Router / Pages Router 해당 없음. Flutter go_router `^14.8.1`; Express Router | `flutter_app/pubspec.yaml`, `flutter_app/lib/core/router/app_router.dart`, `server/routes/index.ts` |
| 스타일 | Flutter Material 위젯·ThemeData·자체 테마 토큰. Tailwind 선언/설정 확인되지 않음 | `flutter_app/lib/core/theme/`, pubspec.yaml |
| 상태관리 | flutter_riverpod `^2.6.1`, ProviderScope / FutureProvider / StateNotifierProvider 등 | pubspec.yaml, `flutter_app/lib/main.dart`, features 내 providers |
| HTTP / 서버 | dio `^5.8.0+1`; express `^4.19.2`, cors `^2.8.5`, dotenv `^16.4.5`, helmet `^8.3.0` | pubspec.yaml, server/package.json |
| Flutter Supabase | supabase_flutter `^2.8.4` | pubspec.yaml |
| 지도 | kakao_maps_flutter `^0.2.2`; 서버 Kakao Local REST 연동 | pubspec.yaml, `server/integrations/kakao/kakao-local.client.ts` |
| Dart / Flutter | Dart SDK 범위 `>=3.5.0 <4.0.0`; Flutter 정확한 설치 버전 확인 필요 | pubspec.yaml |
| Phaser | 조사한 자체 소스·패키지 선언에서 미발견. 외부 제공본 버전 확인 필요 | 패키지 및 소스 검색 |

버전은 설치 확정 버전이 아니라 요청한 package.json/pubspec.yaml의 **선언 범위**다. 루트 package.json 및 pnpm-workspace.yaml에 mobile/admin이 나열되어 있으나 현재 대상 루트에는 해당 폴더가 없다. 다른 브랜치·별도 저장소의 React 앱 존재 여부는 확인 필요다.

TypeScript 설정은 `target: ES2020`, `module: CommonJS`, `moduleResolution: Node`, `strict: true`, `esModuleInterop: true`, `skipLibCheck: true`다. server는 `../shared/**/*.ts`도 포함한다. 두 tsconfig에 `baseUrl`/`paths` alias는 없다.

### 지도 로딩

- `flutter_app/lib/main.dart` → `core/map/kakao_map_initializer.dart::initializeKakaoMap` → `KakaoMapsFlutter.init(..., webAPIKey: ...)`. 웹/네이티브별 필요한 설정의 존재를 확인하고 초기화 실패 시 false를 반환한다.
- 표시: `features/discovery/presentation/map/restaurant_map_view_kakao.dart`. 관련 코드: `restaurant_map_view.dart`, `restaurant_map_fallback.dart`, `kakao_marker_adapter.dart`, `kakao_cluster_policy.dart`.
- `flutter_app/web/index.html`은 Flutter bootstrap을 로딩하며 직접 Kakao SDK script를 선언하지 않는다. 자체 소스에서 `autoload=false`/`kakao.maps.load()` 직접 호출은 미발견. 플러그인 내부 로딩 세부와 실행 결과는 확인 필요다.
- 서버의 Kakao Local 검색은 브라우저 지도 SDK와 별개다. 네이버 SDK 사용은 조사한 자체 소스에서 미발견.
- 기존 위치 기능은 `features/discovery/data/geolocator_location_service.dart`와 위치 providers에 있다. 동네 씬의 가상 이동에 이를 재사용해야 한다는 근거는 없으며, 가상 좌표와 식당 지리 좌표는 별도 계약이 필요하다.

## 2. 폴더 구조와 규칙

루트 `src/`·`app/`은 없다. 아래는 실제 앱 소스 루트인 `flutter_app/lib` 아래 깊이 3까지의 폴더 목록이다. 중괄호는 같은 깊이의 실제 형제 폴더를 압축 표기한 것이다. node_modules와 생성물은 제외했다.

```text
flutter_app/lib/
├── main.dart
├── core/
│   ├── config/
│   ├── constants/
│   ├── map/
│   ├── network/
│   ├── platform/
│   ├── router/
│   └── theme/
├── features/
│   ├── auth/          {data, domain, presentation, providers}/
│   ├── chat/          {data, domain, presentation, providers}/
│   ├── discovery/     {data, domain, presentation, providers}/
│   ├── home/          {data, domain, presentation, providers}/
│   ├── matching/      {data, domain, presentation, providers}/
│   ├── notifications/ {data, domain, presentation, providers}/
│   ├── pet/           {data, domain, presentation, providers}/
│   ├── profile/       {data, domain, presentation, providers}/
│   └── settings/      {data, domain, presentation}/
└── widgets/
```

서버·공유 코드의 주요 폴더는 다음과 같다.

```text
server/
├── app.ts
├── server.ts
├── config/
├── controllers/
├── integrations/kakao/
├── middleware/
├── models/
├── repositories/{interfaces, memory, supabase}/
├── routes/
├── scripts/
└── services/
    ├── auth/
    ├── block/
    ├── chat/
    ├── matching/
    ├── notification/
    ├── pet/
    ├── push/providers/
    ├── rating/
    ├── report/
    ├── restaurant/
    ├── sanction/
    └── verification/
shared/
├── types/
└── utils/
supabase/
├── migrations/
└── tests/
```

- Flutter 파일은 `snake_case.dart`, 클래스는 PascalCase, 함수·필드는 lowerCamelCase. feature별 data/domain/presentation/providers 구분. 공용 위젯은 widgets, 설정·네트워크·라우터·테마는 core.
- 서버는 `matching.routes.ts`, `matching.controller.ts`, `matching.service.ts`, `matching.supabase.repository.ts`처럼 역할 접미사 사용. 여러 단어는 `kakao-restaurant-discovery.service.ts`처럼 kebab-case. 타입은 `shared/types/*.types.ts`가 중심이며 `pet.ts` 예외가 있다.
- TS import는 상대 경로이며 `@/` alias 없음. Dart는 package import와 상대 import 사용. React 컴포넌트/훅 폴더 규칙은 확인 필요.
- DB는 snake_case, API/TS 모델은 camelCase이며 repository에서 변환한다.

## 3. Supabase, 인증, Realtime

### 클라이언트 생성과 인증 흐름

| 구분 | 경로·메서드 | 확인한 방식 |
|---|---|---|
| Flutter 클라이언트 | `flutter_app/lib/main.dart` | 설정이 있으면 `Supabase.initialize` |
| Flutter 주입 | `core/network/supabase_provider.dart::supabaseClientProvider` | `Supabase.instance.client`, 설정 없으면 null |
| 서버 Auth 클라이언트 | `server/config/supabase.ts::getSupabaseAuthClient` | createClient 싱글턴; 자동 토큰 갱신·세션 저장 비활성 |
| 서버 데이터 클라이언트 | `server/config/supabase.ts` | 별도 클라이언트로 분리 |
| React 브라우저/SSR 클라이언트 | 해당 구현 미발견 | 쿠키 기반 Next middleware/SSR 연결 확인 필요 |

Flutter 로그인·가입·로그아웃은 `features/auth/data/auth_repository.dart::SupabaseAuthRepository`의 `signInWithPassword`/`signUp`/`signOut`을 사용한다. 세션은 `auth.currentSession`, 변화는 `onAuthStateChange`로 관찰한다. `features/auth/providers/auth_provider.dart`에 currentUserProvider/currentSessionProvider가 있다. 사용자 ID는 앱의 currentUserProvider 사용자 id 또는 Supabase session.user.id에서 얻는다.

프로필은 `AuthApi.me()`로 서버 확인한다. API 실패 시 세션 정보로 fallback하는 경로가 있으므로 이를 참가 권한의 증거로 사용하면 안 된다. `core/network/auth_interceptor.dart`와 dio_provider가 Authorization Bearer 헤더를 붙인다. 토큰의 실제 값은 문서에 기록하지 않는다.

서버 `authMiddleware` → `authenticateToken` → auth repository의 `verifyAccessToken` 흐름이다. Supabase 구현은 `auth.getUser(token)`으로 확인하고 `AuthenticatedRequest.userId = session.user.id`를 지정한다. 프로필이 없으면 초기 프로필을 만들며, 로그인 단계에서 permanent_ban 제재도 확인한다. Next 쿠키 미들웨어는 없다.

서버에도 `POST /api/auth/signup`, `POST /api/auth/login`, `GET /api/auth/me`, `GET /api/auth/verification/status`가 있다. 서버 logout 라우트는 미발견. 개발용 mock 인증 라우트는 환경 조건부 등록이다. `server/repositories/index.ts`는 AUTH_PROVIDER와 REPOSITORY_PROVIDER에 따라 auth 및 각 데이터 저장소를 선택하므로 운영에서 실제 선택된 provider는 확인 필요다.

### service_role 관련 경로 (값·코드 인용 없이 경로만)

```text
server/config/environment.ts
server/config/supabase.ts
server/repositories/supabase/admin.supabase.repository.ts
server/repositories/supabase/auth.supabase.repository.ts
server/repositories/supabase/block.supabase.repository.ts
server/repositories/supabase/chat.supabase.repository.ts
server/repositories/supabase/matching.supabase.repository.ts
server/repositories/supabase/notification.supabase.repository.ts
server/repositories/supabase/pet.supabase.repository.ts
server/repositories/supabase/push-device.supabase.repository.ts
server/repositories/supabase/rating.supabase.repository.ts
server/repositories/supabase/report.supabase.repository.ts
server/repositories/supabase/restaurant-favorite.supabase.repository.ts
server/repositories/supabase/restaurant.supabase.repository.ts
server/repositories/supabase/sanction.supabase.repository.ts
server/repositories/supabase/user.supabase.repository.ts
server/repositories/supabase/verification.supabase.repository.ts
server/scripts/chatSupabasePersistence.cjs
server/scripts/discoveryPartySeed.cjs
server/scripts/identityIsolationSmoke.cjs
server/scripts/kakaoRestaurantLocalValidation.cjs
server/scripts/kakaoRestaurantSupabaseUpsert.cjs
server/scripts/matchingChatRecoverySupabase.cjs
server/scripts/matchingJoinFlowValidation.cjs
server/scripts/matchingSupabasePersistence.cjs
server/scripts/matchingSupabaseSecurity.cjs
server/scripts/notificationSupabasePersistence.cjs
server/scripts/petDogCatLive.cjs
server/scripts/petSupabasePersistence.cjs
server/scripts/phase3bSmoke.cjs
server/scripts/phase3bSupabasePersistence.cjs
server/scripts/pushSupabasePersistence.cjs
server/scripts/ratingSupabasePersistence.cjs
server/scripts/restaurantPostgisSupabase.cjs
server/scripts/restaurantSupabasePersistence.cjs
server/scripts/scanSecrets.cjs
server/scripts/supabaseAuthSmoke.cjs
server/scripts/userProfileSupabaseFollowup.cjs
server/scripts/userProfileSupabasePersistence.cjs
```

위에는 실행 구현 외에 스크립트의 참조·검사 경로도 포함한다.

### Realtime

자체 서버·Flutter 소스에서 channel, Presence, Broadcast, postgres_changes/onPostgresChanges 구독 구현을 발견하지 못했다. 현재 채팅은 REST API와 FutureProvider 기반 조회/갱신이다. `onAuthStateChange`는 인증 상태 관찰이며 멀티플레이 채널 구현이 아니다. Realtime publication, 채널 권한, 동네별 접속 검증, 재접속/해제, 외부 제공본 구현은 **확인 필요**다.

## 4. 모집·식당·채팅 서버 경로

`server/app.ts`가 `/api` 아래 routes를 마운트한다. 아래 경로는 실제 HTTP 경로다. Next API Route나 server action은 없다. 일반 성공은 200, 생성 API는 표에 201 표시. 공통 오류 응답은 `{message}`이며 error.statusCode 또는 500을 사용한다.

### 4.1 모집·신청

라우트: `server/routes/matching.routes.ts` → `controllers/matching.controller.ts` → `services/matching/matching.service.ts`.

| 메서드·경로 | 입력 | 출력 / 서비스 | 내부 규칙 |
|---|---|---|---|
| GET /api/matching/posts | 컨트롤러가 query를 사용하지 않음 | MatchingPost[] / listMatchingPosts | 인증 미들웨어 없음. status/장소 필터 없는 목록 |
| POST /api/matching/posts | restaurantName, address, scheduledAt, maxParticipants, intro; 선택 restaurantId, location | 201 MatchingPost / createMatchingPost | 인증·모집 권한, 식당 ID 존재, 필수값, 미래 일정, 정원 1~8 |
| POST /api/matching/posts/:postId/requests | postId; body 사용 안 함 | 201 JoinRequest / createJoinRequest | 인증·rate limit·모집 권한, open, 본인 글 금지, 차단, 기존 참가/중복 pending 금지 |
| GET /api/matching/posts/:postId/request/me | postId | JoinRequest 또는 null / getMyJoinRequest | 인증; 요청자 본인의 최신 신청 |
| GET /api/matching/posts/:postId/requests | postId | JoinRequest[] / listJoinRequestsForPost | 인증·본인인증·글 존재·주최자만 |
| POST /api/matching/requests/:requestId/respond | decision: accepted 또는 rejected (TS 계약) | {request, chatRoom?} / respondToJoinRequest | 인증·본인인증·주최자, pending; 수락 때 신청자 모집 권한·양방향 matching/chat 차단 검사 |
| POST /api/matching/posts/:postId/complete | postId | MatchingPost / completeMatchingPost | 인증·본인인증·주최자 또는 참가자·closed만 완료 |

자료형: `shared/types/matching.types.ts`. MatchingPost는 id, authorId, 선택 restaurantId, restaurantName, address, 선택 location{latitude,longitude}, scheduledAt, maxParticipants, intro, status, participantIds, 선택 completedAt, createdAt, updatedAt. JoinRequest는 id, postId, requesterId, status, createdAt, updatedAt.

`assertCanUseMatching`은 본인인증, matching 제재, 미완료 평가, 매너 점수를 검사한다. 최저 매너 점수는 30이다. 개발/테스트에서는 verificationStatus=verified를 인정하고 production은 verification claim의 사용자 일치·verified·pass·유효한 verifiedAt까지 요구한다. 근거: auth.service.ts, verification-policy.ts, rating.service.ts, shared/utils/rating.ts.

제재: 로그인은 permanent_ban, 모집은 matching_suspension/temporary_suspension/permanent_ban, 채팅은 chat_suspension/temporary_suspension/permanent_ban. 활성 상태·취소 여부·만료를 확인한다. 차단은 `assertNoActiveBlockBetween` → blocks repository 검사다. 승인자에게는 assertVerifiedUser를 적용하며, 신청자에게 적용하는 assertCanUseMatching과 동일하지 않다.

수락은 `matching.supabase.repository.ts::acceptJoinRequest` → `accept_join_request` RPC. SQL은 신청·모집 행 잠금, pending/open, 중복 참가, 정원을 검사하고 신청 수락·참가자 추가·마감 상태를 함께 변경한다. 신청 단계 자체에는 별도 인원수 검사가 없고 open 여부를 확인하며, 수락 단계에서 정원을 강제한다. 인증·차단·제재 전체가 RPC 내부에 있는 것은 아니다.

수락 후 `ensureChatForAcceptedPost`가 채팅방/참가자와 시스템 메시지를 보장한다. 이미 accepted인 신청을 다시 수락하는 경로는 채팅 복구를 시도한다. 모집 수락과 채팅 생성 전체가 하나의 트랜잭션이라는 근거는 없다.

**정원 표시 불일치:** DB/RPC는 participant_ids에서 주최자를 제외하고 그 길이를 max_participants와 비교한다. Flutter `matching_mapper.dart`는 currentMembers에 주최자 1명을 더하지만 maxMembers는 post.maxParticipants 그대로 쓴다. 동네 씬 n/m의 ‘m이 주최자를 포함하는지’는 **확인 필요**이며 현 UI 계산을 그대로 복제하지 않아야 한다.

**입력 검증 한계:** decision은 TypeScript union이지만 서비스에 accepted/rejected만 허용하는 명시적 런타임 검사가 없다. 생성 정원도 서비스에서는 범위 비교이며 정수·타입의 완전한 검사와 같지 않다. 외부 클라이언트의 TS 타입만으로 서버 검증이 완료된 것으로 판단하면 안 된다.

### 4.2 식당

라우트: `server/routes/restaurant.routes.ts` → `controllers/restaurant.controller.ts` → `services/restaurant/restaurant.service.ts` 및 `kakao-restaurant-discovery.service.ts`. 전체 라우트에 authMiddleware 적용.

| 메서드·경로 | 입력 | 출력 / 함수 | 검사 |
|---|---|---|---|
| GET /api/restaurants | category, lat/lng, radiusKm, limit, offset | RestaurantResponse[] / listRestaurants | 좌표 쌍·범위, 반경 0 초과~100, limit 정수 1~100, offset 음수 금지 |
| GET /api/restaurants/:restaurantId | restaurantId | RestaurantResponse / getRestaurant | 존재 확인 |
| POST /api/restaurants | CreateRestaurantInput | 201 Restaurant / createRestaurant | write rate limit, 필수 문자열·좌표·metadata, provider ID 중복 409 |
| POST /api/restaurants/discover | latitude, longitude, 선택 radiusKm | RestaurantResponse[] / discoverNearbyRestaurantsFromKakao | discovery rate limit, 유한 좌표·범위, 반경 0 초과~20 |
| GET /api/restaurants/favorites/me | 없음 | RestaurantResponse[] / listMyRestaurantFavorites | 현재 사용자 |
| POST /api/restaurants/:restaurantId/favorite | restaurantId | 201 RestaurantResponse / addRestaurantFavorite | write rate limit, 식당 존재 |
| DELETE /api/restaurants/:restaurantId/favorite | restaurantId | {ok:true} / removeRestaurantFavorite | write rate limit, 현재 사용자 |

CreateRestaurantInput 필수: name/address/latitude/longitude/category/placeProvider/placeProviderId. 선택: imageUrl/phone/roadAddress/metadata. 응답은 `shared/types/restaurant.types.ts` 기준 id와 시간 필드를 포함하며 RestaurantResponse에는 isFavorite, activePartyCount, 선택 distanceMeters가 추가된다. activePartyCount는 해당 restaurantId의 open 모집 수이며 신청 인원수가 아니다. 식당 API에 본인인증·매너·모집 제재 검사가 공통 적용되는 것은 아니다.

DB `restaurants` 주요 필드: id, name, address, latitude, longitude, category, place_provider, place_provider_id, image_url, phone, road_address, metadata, created_at, updated_at. TS/API는 placeProvider/placeProviderId 등으로 변환한다. `place_provider,place_provider_id` 조합을 공급자 식당 식별에 사용한다.

### 4.3 Kakao → restaurants 등록 및 ID

1. `POST /api/restaurants/discover` → `discoverNearbyRestaurantsFromKakao` → KakaoRestaurantDiscoveryService.discover/sync.
2. `server/integrations/kakao/kakao-local.client.ts`의 카테고리 검색 결과를 최대 3페이지 수집.
3. `kakao-restaurant.normalizer.ts::normalizeKakaoRestaurant(s)`: id→placeProviderId, place_name→name, y→latitude, x→longitude. 도로명 주소 우선, 유효성 검사 및 ID 중복 제거.
4. `repositories.restaurants.upsertMany`로 등록/갱신 후 근처 식당 목록 반환. 발견 결과 동기화 캐시는 기본 30초.
5. `server/models/id.ts::createProviderEntityId`는 공급자 문자열을 정규화하고 SHA-256(provider + ":" + providerId)의 앞 24자리 hex를 사용한다. 새 Kakao upsert ID는 **restaurant_kakao_<24자리 해시>**이며 Kakao 원본 ID를 단순히 뒤에 붙이지 않는다.
6. 기존 공급자 식당이 있으면 기존 id를 유지한다. 일반 `POST /restaurants`의 create는 `createEntityId("restaurant")`로 시간·카운터 기반 ID를 만든다. 따라서 Kakao 장소 ID로 DB id를 무조건 합성하면 기존 식당을 놓친다.

근거: `server/repositories/supabase/restaurant.supabase.repository.ts`의 create/upsertMany/findByProviderId.

### 4.4 채팅

라우트: `server/routes/chat.routes.ts` → `controllers/chat.controller.ts` → `services/chat/chat.service.ts`.

| 메서드·경로 | 입력 | 출력 / 함수 | 검사 |
|---|---|---|---|
| GET /api/chat/rooms | 없음 | ChatRoom[] / listChatRooms | 인증·본인인증; 자신의 방 |
| GET /api/chat/rooms/:roomId/messages | roomId | ChatMessage[] / listMessages | 인증·본인인증·방 존재·참가자 |
| POST /api/chat/rooms/:roomId/messages | text | 201 ChatMessage / sendMessage | 인증·채팅 권한·참가자·타 참가자와 차단·공백 메시지 금지 |

타입은 `shared/types/chat.types.ts`. 저장은 `chat.supabase.repository.ts`의 listRoomsForUser/listMessages/createMessage/touchRoom 등. ensureRoom은 `create_or_reuse_chat_room` RPC를 사용한다. 관련 테이블은 chat_rooms/chat_room_participants/chat_messages다. 공개 ‘채팅방 만들기’ API는 없으며 모집 수락 결과의 chatRoom을 이용한다.

Flutter 진입점은 `core/router/app_routes.dart` 및 app_router.dart: `/create-party?restaurantId=...`, `/party/:partyId`, `/chat?roomId=...`, `/restaurants/:restaurantId`. UI는 CreatePartyScreen/PartyDetailScreen/ChatScreen/RestaurantDetailScreen. MatchingApi의 createPost/createJoinRequest/respondJoinRequest와 ChatApi/ChatRepository가 기존 통합 경계다. Dart 메서드를 외부 React에서 그대로 import할 수는 없다.

### 4.5 상태와 DB 접근 경계

- MatchingPostStatus: open/closed/cancelled/completed. 생성→open, 승인으로 정원 도달→closed, closed→complete API→completed. cancelPost 저장소 메서드는 있으나 등록된 matching 라우트에 취소 API는 없다.
- JoinRequestStatus: pending/accepted/rejected/cancelled. 생성→pending, 승인/거절→accepted/rejected. cancelled는 스키마·타입에 있으나 전용 취소 API는 미발견. 이미 처리한 신청은 일반적으로 409, accepted 재수락은 채팅 복구 예외.
- 완료 시 pending evaluations 생성 및 펫 XP 보상 경로가 있다. 신규 기능에서 완료 로직을 복제하면 이 부수 동작을 누락할 수 있다.
- 마이그레이션: `supabase/migrations/YYYYMMDDNNNN_*.sql`. 실제 DB 적용 여부 확인 필요.
- `202608220002_matching_posts_and_join_requests.sql` 및 `202608230001_chat_rooms_and_messages.sql`: RLS 활성화, anon/authenticated 테이블 접근 철회, 서버 전용 쓰기. accept_join_request RPC도 공개 실행권을 철회한다. 직접 브라우저 CRUD로 기존 서비스 검사를 대체할 수 없다.
- restaurants는 인증 사용자 SELECT 정책, restaurant_favorites는 본인 행 정책. profiles/manner/pets는 해당 마이그레이션에서 서버 접근 중심이다.
- 확인된 테이블: reports, report_events, blocks, sanctions, admin_audit_logs, restaurants, restaurant_favorites, matching_posts, join_requests, chat_rooms, chat_room_participants, chat_messages, pending_evaluations, user_manner_profiles, manner_ratings, user_profiles, verification_claims, verification_failure_logs, notifications, user_push_devices, user_pets, pet_xp_events. 근거는 migrations의 CREATE TABLE이며 운영 DB 전체 목록이라는 의미는 아니다.

## 5. 사용자 닉네임·매너·인증·펫

| 데이터 | 서버 함수·저장소 | 사용 가능한 API/Flutter |
|---|---|---|
| user_profiles.nickname | `user.supabase.repository.ts::findById` → getRow/toUser | GET /api/auth/me; AuthApi.me, ProfileApi.me |
| user_manner_profiles.manner_grade | `rating.supabase.repository.ts::getMannerProfile`; user repository도 조회; auth.service.ts의 toPublicUser가 반영 | GET /api/auth/me → mannerGrade/mannerScore |
| 인증 상태 | `auth.service.ts::assertVerifiedUser`, `verification-policy.ts`, verification service/repository | GET /api/auth/verification/status; ApiProfileRepository.currentProfile |
| user_pets | `pet.supabase.repository.ts::findByUser` → `pet.service.ts::getMyPet` | GET /api/pets/me → PetResponse 또는 null |
| 펫 선택 | `pet.service.ts::selectPet` → pets.create | POST /api/pets/me, body petType; 201 PetResponse |

매너 등급은 sprout/regular/foodie/mukking이며 shared/utils/rating.ts에 점수 구간이 있다. 펫은 종류·XP·성장 정보이며 몸/헤어/옷/소품 조합 아바타와 같은 모델이 아니다.

**다른 사용자의 프로필 표시 API는 확인 필요:** 현재 /auth/me와 /pets/me는 본인 정보용이다. JoinRequest 응답에는 requesterId만 있고 닉네임·매너·인증 요약이 조합되어 있지 않다. 참가 신청 UI용 타인 공개 프로필 일괄 조회는 등록된 일반 라우트에서 미발견. 관리자 API를 이 용도로 재사용하는 근거는 없다.

**성별/나이 인증 상태는 확인 필요:** MockVerificationInput에 gender/birthDate 입력은 있으나 `202608240001_user_profiles_and_verification.sql`은 실명·생년월일·성별을 저장하지 않는다고 명시하고, PublicUserProfile에도 성별/나이별 인증 필드가 없다. verificationStatus=verified만으로 성별/나이 인증 배지를 만들어서는 안 된다. 외부 아바타의 외형 선택값 저장 모델도 현재 확인되지 않는다.

## 6. 환경변수 이름

예시 파일의 활성 항목과 주석 처리된 설정 예를 포함하고 중복은 제거했다. 값·기본값·인증정보는 생략한다.

### server/.env.example

```text
PORT
NODE_ENV
MOCK_VERIFICATION_ENABLED
AUTH_PROVIDER
REPOSITORY_PROVIDER
AUTH_JWT_SECRET
AUTH_JWT_EXPIRES_IN_SECONDS
SUPABASE_URL
SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
KAKAO_REST_API_KEY
PUSH_PROVIDER
FIREBASE_USE_ADC
GOOGLE_APPLICATION_CREDENTIALS
FIREBASE_PROJECT_ID
FIREBASE_CLIENT_EMAIL
FIREBASE_PRIVATE_KEY
ADMIN_UID_WHITELIST
ADMIN_EMAIL_WHITELIST
ADMIN_REQUIRE_MFA
CORS_ALLOWED_ORIGINS
RATE_LIMIT_WINDOW_MS
RATE_LIMIT_AUTH_SIGNUP_MAX
RATE_LIMIT_AUTH_LOGIN_MAX
RATE_LIMIT_VERIFICATION_MAX
RATE_LIMIT_MATCHING_REQUEST_MAX
RATE_LIMIT_REPORT_CREATE_MAX
RATE_LIMIT_BLOCK_CREATE_MAX
RATE_LIMIT_RESTAURANT_WRITE_MAX
RATE_LIMIT_RESTAURANT_WRITE_WINDOW_MS
RATE_LIMIT_RESTAURANT_DISCOVERY_MAX
RATE_LIMIT_RESTAURANT_DISCOVERY_WINDOW_MS
RATE_LIMIT_PUSH_DEVICE_MAX
RATE_LIMIT_ADMIN_AUTH_MAX
RATE_LIMIT_ADMIN_SENSITIVE_MAX
```

### flutter_app/.env.example

```text
MUKKING_API_BASE_URL
MUKKING_DATA_PROVIDER
MUKKING_ENABLE_MOCK_VERIFICATION
MUKKING_SUPABASE_URL
MUKKING_SUPABASE_ANON_KEY
MUKKING_KAKAO_NATIVE_APP_KEY
MUKKING_KAKAO_JAVASCRIPT_KEY
```

추가로 `server/config/environment.ts`에서 읽는 항목:

```text
RATE_LIMIT_AUTH_SIGNUP_WINDOW_MS
RATE_LIMIT_AUTH_LOGIN_WINDOW_MS
RATE_LIMIT_VERIFICATION_WINDOW_MS
RATE_LIMIT_MATCHING_REQUEST_WINDOW_MS
RATE_LIMIT_REPORT_CREATE_WINDOW_MS
RATE_LIMIT_BLOCK_CREATE_WINDOW_MS
RATE_LIMIT_PUSH_DEVICE_WINDOW_MS
RATE_LIMIT_ADMIN_AUTH_WINDOW_MS
RATE_LIMIT_ADMIN_SENSITIVE_WINDOW_MS
```

Flutter는 `core/config/app_config.dart`의 컴파일 환경 읽기, 서버는 `config/environment.ts`를 사용한다. Next의 NEXT_PUBLIC 네이밍이 이미 적용되어 있다는 근거는 없다. 외부 기능에 필요한 새 변수는 외부 빌드 구성 확인 후 결정해야 한다.

## 7. 확인된 경계에 근거한 통합 제안

이 절은 위 사실에 기반한 제안이며 이미 구현되어 있다는 의미가 아니다. 외부 기능 소스·package.json·배포 방식은 제공되지 않아 확인 필요다.

### 폴더 배치

현재 저장소에는 React src 루트가 없으므로 `src/features/town`을 넣을 ‘기존 위치’가 없다. Flutter 쪽 진입·화면·어댑터를 둔다면 기존 관례에 맞는 후보는 `flutter_app/lib/features/town/{data,domain,presentation,providers}`다. 단 React/Phaser TSX 파일을 Dart feature에 넣어 실행할 수는 없다.

외부 React/Phaser 기능은 별도 웹 패키지/호스트에 원래 feature 구조를 유지하고 Flutter와 API·화면 이동·인증 전달 경계를 연결하는 방안을 검토할 수 있다. 이는 신규 호스트 구성이며 현재 존재하지 않는다. 웹 전용인지 모바일도 필요한지, 임베딩 방식, 빌드·배포 위치, 토큰 갱신·로그아웃 공유, CORS 허용 범위는 확인 필요다. Next SSR/StrictMode 처리와 Phaser 해제 로직도 외부 제공본에서 확인해야 하며 현재 Flutter 코드에 존재한다고 볼 수 없다.

### 벽보 동작별 재사용 범위

| 동작 | 확인된 재사용 경계 | 부족한 부분 / 제안 |
|---|---|---|
| 특정 Kakao ID 목록의 모집 조회 | restaurants.findByProviderId; upsertMany의 provider+ID 일괄 조회 패턴; matching.listPosts; 기존 restaurant_id/status 인덱스 | HTTP GET /matching/posts는 필터를 읽지 않고 MatchingPostFilter에도 장소 ID 목록 기능이 없다. 장소 일괄 매핑+모집 필터의 서버 확장이 필요 |
| 모집 상세 열기 | /party/:partyId 화면; 기존 MatchingApi.listPosts | 단건 GET /matching/posts/:id API 미발견. 현 목록을 통한 화면 진입은 가능; 독립 웹의 단건 로딩 필요 시에만 API 확장 |
| 새 모집 열기/작성 | /create-party?restaurantId=...; POST /api/matching/posts → createMatchingPost | DB에 등록된 실제 restaurantId 사용. 동일 생성 API를 새로 만들 필요 없음 |
| 참가 신청 | POST /api/matching/posts/:postId/requests | 기존 검사를 유지해 호출. 신청 즉시 채팅 참가가 아니라 주최자 승인 단계 필요 |
| 승인·채팅 연결 | respond API → chatRoom; GET /api/chat/rooms; /chat?roomId=... | 승인 응답을 받는 주최자와 신청자의 UI 갱신 경로 구분. 신청자는 자기 신청 상태·자기 채팅방 목록 재조회로 연결 가능 |
| 미등록 Kakao 장소 | POST /restaurants/discover, POST /restaurants | discover는 좌표 기반 검색이고 임의 ID 목록 조회가 아님. 일반 create는 필수 장소 정보가 필요하며 중복 409. ID만 제공된 경우 정확한 장소 해석·등록 계약 확인 필요 |
| 참가자 표시 | 서버 users.findById/rating.getMannerProfile/pets.findByUser | 타인 공개 요약 API가 없으므로 이 UI가 필요하면 서버에서 허용 필드만 결합하는 조회 확장 필요 |
| 가상 이동 | 기존 재사용할 Realtime 모듈 미발견 | 동네 채널·가상 좌표·사용자 식별·권한·수명 관리 신규 설계 필요 |
| 꾸미기 | user_pets는 펫 성장만 담당 | 아바타 선택값 저장이 외부 제공본에 있는지 확인 필요. 펫 API에 임의 외형 필드를 넣을 수 없음 |

### 정말 필요한 API 확장과 불필요한 중복

1. **Kakao 장소 ID 목록으로 서버에서 정확히 제한한 모집 조회를 하려면 조회 확장이 필요하다.** 기존 GET /api/matching/posts에 선택 필터를 추가하는 방안이 우선이며 새 endpoint를 반드시 만들 필요는 없다. 제안 계약은 Kakao place ID 목록 → restaurants의 공급자/원본 ID로 실제 id 매핑 → matching_posts.restaurant_id + 상태 필터. 목록 크기 제한·페이지 처리·미등록 ID 처리·반환 필드·조회 접근 권한은 확인 필요다. 전체 목록을 받은 뒤 클라이언트 필터링하는 것은 가능하지만 서버의 목록 제한과 같지 않다.
2. **생성·참가·승인·채팅 전용 town API는 기본적으로 불필요하다.** 기존 서비스의 인증·매너·미평가·차단·제재·정원·알림·채팅 복구 규칙을 재사용한다.
3. **타인의 닉네임/매너/인증/펫 표시가 필수라면 공개 요약 조회 확장이 필요하다.** 신청 목록 응답에 안전한 요약을 포함하거나 권한 있는 일괄 조회를 추가할 수 있다. /auth/me 응답 전체나 관리자 프로필 응답을 타인에게 재전송하지 않는다. 성별/나이별 인증은 데이터가 없으므로 API 이름만 추가해서 해결되지 않는다.
4. **Realtime용 별도 HTTP API 필요 여부는 확인 필요다.** 현 저장소에는 입장권·채널 권한 구현이 없어 외부 기능의 채널 보안 설계를 본 뒤 판단해야 한다. 기존 매칭 테이블 직접 쓰기 권한을 열어 이동 기능을 구현할 필요는 없다.
5. **외형 저장 API 필요 여부는 확인 필요다.** 외부 제공본 저장 계층을 확인한 뒤 결정한다. 현재 펫 성장 API와 별개라는 점은 확인됐다.

### 통합 착수 전 확인 필요

- 외부 feature 실제 소스, React/Phaser/Supabase 버전, 호스트와 모바일 지원 범위.
- DB 마이그레이션 실제 반영, 실행 중 auth/repository provider, 운영 본인인증 연결.
- 주최자 포함 여부를 통일한 정원 계약.
- API 공개 목록의 노출 범위와 새 장소 필터의 권한 정책.
- 외부 Realtime 접속자의 사용자 ID 검증, 동네별 입장·차단/제재 반영, 재접속/해제.
- 실제 GPS를 가상 캐릭터 좌표·Presence/Broadcast payload에 섞지 않는 경계.
- 성별/나이 인증 정보의 존재 여부 및 허용되는 표시 범위.
- 로컬·브라우저·운영 환경 실행 검증. 기존 smoke/security 테스트 스크립트는 존재하지만 이번 조사에서 실행하지 않았다.
