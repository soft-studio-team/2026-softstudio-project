# 릴리즈 빌드 R8 축소/난독화 활성화에 따른 최소 keep 규칙.
# 근거 없이 광범위하게 keep 하지 않고, 실제로 문제가 보고된 항목만 남긴다.

# Flutter 엔진이 참조하는 Play Core(분할 설치/컴팻) 클래스 — 앱이 동적 기능 모듈을
# 쓰지 않아도 엔진 코드 경로에 참조가 남아있어 R8이 제거하면 릴리즈에서만 크래시가
# 나는 사례가 보고되어 있다. 실사용 여부와 무관하게 keep.
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# flutter_local_notifications(dexterous)는 내부적으로 Gson을 써서 예약 알림을
# 직렬화한다. R8이 제네릭 타입 정보(Signature)나 알림 관련 클래스를 지우면 예약
# 알림이 조용히 깨지는 문제가 알려져 있어, 패키지 전체와 Gson 제네릭 정보를 keep.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn org.xmlpull.v1.**
