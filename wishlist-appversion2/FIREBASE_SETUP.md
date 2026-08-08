# Firebase 앱 등록 & 연결 가이드

프로젝트: `softstudio-wishlist-app`  
Bundle ID / Application ID: `com.softstudio.wishlist`

앱 출시(스토어 등록)는 필요 없습니다. 개발용으로 Firebase에 “이 앱이에요”라고 등록만 하면 됩니다.

---

## 1) Authentication (이미 하셨다면 스킵)

1. [Firebase Console](https://console.firebase.google.com) → `softstudio-wishlist-app`
2. 왼쪽 메뉴 펼치기 (`>`) → **Build → Authentication**
3. **이메일/비밀번호** 사용 설정 ON → 저장

---

## 2) Firestore 만들기

1. **Build → Firestore Database → 데이터베이스 만들기**
2. 위치: `asia-northeast3 (Seoul)` 권장
3. 처음엔 **테스트 모드**로 시작해도 됩니다 (아래 규칙을 나중에 적용)

콘솔에서 규칙 탭에 `firestore.rules` 내용을 붙여넣으면  
각 사용자는 자기 `users/{uid}` 아래 데이터만 읽고 쓸 수 있습니다.

---

## 3) 앱 등록 (= 번호표 발급)

### iOS (시뮬레이터/맥)

1. 프로젝트 설정(톱니바퀴) → **내 앱** → **Apple** 아이콘
2. Apple 번들 ID: `com.softstudio.wishlist`
3. 앱 닉네임: 아무거나 (예: `wishlist-ios`)
4. `GoogleService-Info.plist` 다운로드
5. 파일을 여기로 복사:
   `flutter_app/ios/Runner/GoogleService-Info.plist`
6. Xcode로 `ios/Runner.xcworkspace` 를 열었다면 Runner에 파일이 포함돼 있는지 확인

### Android

1. 프로젝트 설정 → **내 앱** → **Android** 아이콘
2. Android 패키지 이름: `com.softstudio.wishlist`
3. `google-services.json` 다운로드
4. 파일을 여기로 복사:
   `flutter_app/android/app/google-services.json`

---

## 4) `firebase_options.dart` 값 채우기 (필수)

Flutter 코드가 Firebase에 붙으려면 키가 필요합니다.

### 방법 A — 자동 (추천)

```bash
dart pub global activate flutterfire_cli
cd flutter_app
flutterfire configure --project=softstudio-wishlist-app
```

`lib/firebase_options.dart` 가 자동으로 채워집니다.

### 방법 B — 수동

1. Firebase 콘솔 → 프로젝트 설정 → 내 앱 → 앱 선택
2. **SDK 설정 및 구성** / 구성 값에서 `apiKey`, `appId`, `messagingSenderId` 확인
3. `flutter_app/lib/firebase_options.dart` 의 `YOUR_...` 자리를 실제 값으로 교체

`YOUR_` 로 시작하는 값이 하나라도 있으면 앱은 로그인 화면에  
“Firebase 앱 등록이 필요해요” 안내를 보여 주고, 실제 로그인은 막습니다.

---

## 5) 실행 & 확인

```bash
cd flutter_app
flutter pub get
flutter run
```

1. **회원가입**으로 계정 생성
2. Firebase Console → Authentication → Users 에 이메일 보이는지 확인
3. Firestore → `users/{uid}/tabs`, `users/{uid}/products` 생성 확인
4. 다른 이메일로 한 명 더 가입 → 친구 탭에서 팔로우
5. 각자 위시 상품이 계정별로 분리되는지 확인

---

## 데이터 구조 (코드가 쓰는 경로)

```
users/{uid}
  email, name, handle, avatarUrl, followers, following
  tabs/{tabId}
  products/{productId}
  following/{otherUid}
  followers/{otherUid}
```

- 로그인/회원가입 → Firebase Auth
- 위시리스트·팔로우 → Cloud Firestore (`users/{내 uid}` 아래)
- 파싱 엔진(FastAPI)은 그대로 URL → 상품 정보용 (계정과 분리)
