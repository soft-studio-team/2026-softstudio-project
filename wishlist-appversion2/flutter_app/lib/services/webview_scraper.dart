import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'product_extract_js.dart';
import 'webview_extract_host.dart';

/// WebView 추출이 확정 가격을 못 냈을 때 남기는 실패 이유.
class ExtractFailureReason {
  static const loadingTimeout = 'loading_timeout';
  static const scriptTimeout = 'script_timeout';
  static const accessBlocked = 'access_blocked';
  static const networkError = 'network_error';
  static const notProductPage = 'not_product_page';
  static const priceAmbiguous = 'price_ambiguous';
  static const unsupportedCurrency = 'unsupported_currency';
}

/// 폴링·안정화 대기에서 실제 시각을 주입하기 위한 시계.
abstract class ExtractClock {
  DateTime now();
  Future<void> delay(Duration duration);
}

class SystemExtractClock implements ExtractClock {
  const SystemExtractClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Future<void> delay(Duration duration) => Future<void>.delayed(duration);
}

/// 단말에서 안 보이는 WebView 로 뽑아낸 상품정보 (Tier 2.5 결과).
class OnDeviceExtract {
  OnDeviceExtract({
    this.name,
    this.price,
    this.originalPrice,
    this.brand,
    this.image,
    this.siteName,
    this.hasJsonLd = false,
    this.looksLikeProductPage = false,
    this.blocked = false,
    this.finalUrl,
    this.source = const {},
    this.purchasePriceStatus = 'unknown',
    this.priceConfidence = 'unknown',
    this.availability = 'unknown',
    this.optionDependent,
    this.optionPriceMin,
    this.optionPriceMax,
    this.priceEvidence = const [],
    this.failureReason,
  });

  final String? name;
  final int? price;
  final int? originalPrice;
  final String? brand;
  final String? image;
  final String? siteName;
  final bool hasJsonLd;
  final bool looksLikeProductPage;
  final bool blocked;
  final String? finalUrl;
  final Map<String, dynamic> source;
  final String purchasePriceStatus;
  final String priceConfidence;
  final String availability;
  final bool? optionDependent;
  final int? optionPriceMin;
  final int? optionPriceMax;
  final List<Map<String, dynamic>> priceEvidence;
  final String? failureReason;

  bool get hasAnything => name != null || price != null || image != null;

  bool get isSoldOut {
    final value = availability.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return value == 'soldout' || value == 'outofstock';
  }

  OnDeviceExtract withFailureReason(String? reason) {
    if (failureReason == reason) return this;
    return OnDeviceExtract(
      name: name,
      price: price,
      originalPrice: originalPrice,
      brand: brand,
      image: image,
      siteName: siteName,
      hasJsonLd: hasJsonLd,
      looksLikeProductPage: looksLikeProductPage,
      blocked: blocked,
      finalUrl: finalUrl,
      source: source,
      purchasePriceStatus: purchasePriceStatus,
      priceConfidence: priceConfidence,
      availability: availability,
      optionDependent: optionDependent,
      optionPriceMin: optionPriceMin,
      optionPriceMax: optionPriceMax,
      priceEvidence: priceEvidence,
      failureReason: reason,
    );
  }

  static OnDeviceExtract? fromRaw(dynamic raw) {
    if (raw == null) return null;
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return null;
      final map = decoded.cast<String, dynamic>();
      return OnDeviceExtract(
        name: (map['name'] as String?)?.trim().isNotEmpty == true
            ? (map['name'] as String).trim()
            : null,
        price: (map['price'] as num?)?.toInt(),
        originalPrice: (map['originalPrice'] as num?)?.toInt(),
        brand: map['brand'] as String?,
        image: map['image'] as String?,
        siteName: map['siteName'] as String?,
        hasJsonLd: map['hasJsonLd'] == true,
        looksLikeProductPage: map['looksLikeProductPage'] == true,
        blocked: map['blocked'] == true,
        finalUrl: map['finalUrl'] as String?,
        source: (map['source'] as Map?)?.cast<String, dynamic>() ?? const {},
        purchasePriceStatus: map['purchasePriceStatus'] as String? ?? 'unknown',
        priceConfidence: map['priceConfidence'] as String? ?? 'unknown',
        availability: map['availability'] as String? ?? 'unknown',
        optionDependent: map['optionDependent'] as bool?,
        optionPriceMin: (map['optionPriceMin'] as num?)?.toInt(),
        optionPriceMax: (map['optionPriceMax'] as num?)?.toInt(),
        priceEvidence:
            (map['priceEvidence'] as List?)
                ?.whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList() ??
            const [],
        failureReason: map['failureReason'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 리다이렉트/SPA 안정화, 스크립트 timeout, 차단 조기 종료, 빈 결과 1회 재시도를
/// WebView 구현과 분리해 단위 테스트할 수 있게 한 추출 루프.
class WebViewExtractLoop {
  WebViewExtractLoop({
    ExtractClock? clock,
    this.settleWindow = const Duration(milliseconds: 600),
    this.scriptTimeout = const Duration(seconds: 8),
    this.pollInterval = const Duration(milliseconds: 200),
    this.firstLoadTimeout = const Duration(seconds: 15),
  }) : clock = clock ?? const SystemExtractClock();

  final ExtractClock clock;
  final Duration settleWindow;
  final Duration scriptTimeout;
  final Duration pollInterval;
  final Duration firstLoadTimeout;

  DateTime? lastNavigationAt;
  bool loading = false;
  bool sawFirstLoad = false;
  bool loadWaitTimedOut = false;
  bool sawNetworkError = false;
  bool scriptTimedOut = false;
  int evaluateCount = 0;
  int reloadCount = 0;

  bool get isSettled {
    if (loading || lastNavigationAt == null) return false;
    return !clock.now().difference(lastNavigationAt!).isNegative &&
        clock.now().difference(lastNavigationAt!) >= settleWindow;
  }

  void onLoadStart(String? url) {
    if (isAboutBlankUrl(url)) return;
    loading = true;
    lastNavigationAt = clock.now();
  }

  void onLoadStop(String? url) {
    if (isAboutBlankUrl(url)) return;
    loading = false;
    sawFirstLoad = true;
    lastNavigationAt = clock.now();
  }

  void onHistoryUpdate(String? url) {
    if (isAboutBlankUrl(url)) return;
    // pushState만 반복하는 SPA(에이블리 등)가 settle을 영원히 미루지 않게,
    // 실제 문서 로딩 중일 때만 안정화 타이머를 갱신한다.
    if (loading) {
      lastNavigationAt = clock.now();
    }
  }

  void onNetworkError() {
    sawNetworkError = true;
    loading = false;
    sawFirstLoad = true;
    lastNavigationAt = clock.now();
  }

  Future<OnDeviceExtract?> run({
    required String requestUrl,
    required Future<dynamic> Function(String source) evaluate,
    required Future<void> Function(String url) loadUrl,
    required Duration maxWait,
    String extractSource = productExtractJs,
    bool Function()? isAlive,
  }) async {
    final loadDeadline = clock.now().add(firstLoadTimeout);
    while (!sawFirstLoad && clock.now().isBefore(loadDeadline)) {
      await clock.delay(pollInterval);
    }
    if (!sawFirstLoad) {
      // Headless WebView가 onLoadStop을 안 주는 경우가 있어, 컨트롤러가 있으면
      // 바로 포기하지 않고 추출을 한 번 시도한다.
      loadWaitTimedOut = true;
      loading = false;
      lastNavigationAt ??= clock.now();
    }

    final deadline = clock.now().add(maxWait);
    OnDeviceExtract? best;
    OnDeviceExtract? lastParsed;
    String? lastFingerprint;
    var emptyReloaded = false;
    // 2026-09-08: 봇 차단 페이지(blocked)를 만나면 그 사이트 홈(origin root)을 한 번
    // 방문한 뒤 원래 URL을 재요청한다. Claude 브라우저 pane으로 실측 확인: 유니클로
    // 상품 URL을 콜드 상태로 바로 열면 Akamai 챌린지 페이지가 뜨지만, 같은 세션에서
    // 홈(uniqlo.com)을 먼저 한 번 방문한 뒤엔 이후 상품 페이지가 매번 정상 로드됨
    // (이름·가격 전부 카탈로그와 일치 확인). `blocked` 필드 자체는 이미 이 재시도를
    // 염두에 두고 만들어져 있었으나(주석 "홈 웜업 재시도 신호") 실제 재시도 코드는
    // 없었다 — 이번에 구현. 세션(쿠키/신뢰)당 1회만 시도하고, 그래도 안 되면
    // access_blocked로 확정한다.
    var warmedUp = false;
    var awaitingWarmupReload = false;

    while (clock.now().isBefore(deadline)) {
      if (isAlive != null && !isAlive()) {
        return _finish(best ?? lastParsed, requestUrl);
      }
      if (!isSettled) {
        final wait = _remaining(deadline);
        if (wait == null) break;
        await clock.delay(wait < pollInterval ? wait : pollInterval);
        continue;
      }

      var parsed = await _evaluateOnce(evaluate, extractSource);
      if (scriptTimedOut) {
        return _finish(best ?? lastParsed, requestUrl);
      }
      if (parsed != null &&
          isForeignExtractResult(requestUrl, parsed.finalUrl)) {
        parsed = null;
      }
      if (parsed != null) lastParsed = parsed;

      if (awaitingWarmupReload) {
        // 방금 평가한 건 홈 웜업 페이지 자체 — 결과로 쓰지 않고 원래 URL을 재요청한다.
        awaitingWarmupReload = false;
        reloadCount += 1;
        // 2026-09-08 재수정: loadUrl()은 네이티브에 내비게이션을 "요청"만 하고 실제
        // onLoadStart/onLoadStop 콜백은 나중에 비동기로 온다 — 그런데 바로 다음 while
        // 반복에서 isSettled가 "이전 페이지"의 lastNavigationAt 기준으로 이미 true로
        // 남아있으면(대개 그렇다) 새 페이지가 뜨기도 전에 곧장 재평가해버려서, 재요청한
        // 원래 URL이 아직 로드되지도 않은 상태(=직전의 홈/차단 페이지 그대로)를 읽는
        // 레이스가 있었다(실기기 재검증에서 유니클로 3건 전부 elapsedMs~1.3초라는
        // 비정상적으로 짧고 균일한 시간으로 재현·확인됨 — 실제로 재시도가 전혀 대기되지
        // 않고 곧바로 stale 상태를 재평가해 실패했던 것). loading/lastNavigationAt을
        // 직접 갱신해 isSettled를 강제로 false로 만들어, 아래 루프의 원래 대기 분기가
        // 진짜 onLoadStop이 올 때까지 정상적으로 기다리도록 고침.
        loading = true;
        lastNavigationAt = clock.now();
        await loadUrl(requestUrl);
        continue;
      }

      if (parsed != null && parsed.blocked) {
        if (!warmedUp) {
          final homeUrl = homeWarmupUrl(requestUrl);
          if (homeUrl != null && homeUrl != requestUrl) {
            warmedUp = true;
            awaitingWarmupReload = true;
            reloadCount += 1;
            loading = true;
            lastNavigationAt = clock.now();
            await loadUrl(homeUrl);
            continue;
          }
        }
        return parsed.withFailureReason(ExtractFailureReason.accessBlocked);
      }

      if (_isEmpty(parsed)) {
        if (!emptyReloaded &&
            best == null &&
            !_isNonRetryable(parsed, requestUrl)) {
          emptyReloaded = true;
          reloadCount += 1;
          await loadUrl(requestUrl);
          continue;
        }
      } else if (parsed != null) {
        best = _prefer(best, parsed);
        final fingerprint = priceFingerprint(parsed);
        if (fingerprint != null) {
          if (fingerprint == lastFingerprint) {
            return parsed;
          }
          lastFingerprint = fingerprint;
        }
      }

      final wait = _remaining(deadline);
      if (wait == null) break;
      await clock.delay(wait < pollInterval ? wait : pollInterval);
    }

    return _finish(best ?? lastParsed, requestUrl);
  }

  Future<OnDeviceExtract?> _evaluateOnce(
    Future<dynamic> Function(String source) evaluate,
    String extractSource,
  ) async {
    evaluateCount += 1;
    try {
      final raw = await evaluate(extractSource).timeout(scriptTimeout);
      return OnDeviceExtract.fromRaw(raw);
    } on TimeoutException {
      scriptTimedOut = true;
      return null;
    }
  }

  Duration? _remaining(DateTime deadline) {
    final left = deadline.difference(clock.now());
    if (left <= Duration.zero) return null;
    return left;
  }

  OnDeviceExtract? _finish(OnDeviceExtract? best, String requestUrl) {
    if (best != null && (best.price != null || best.optionPriceMin != null)) {
      return best;
    }
    final reason = _classify(best, requestUrl);
    if (best != null) return best.withFailureReason(reason);
    return OnDeviceExtract(failureReason: reason);
  }

  String _classify(OnDeviceExtract? best, String requestUrl) {
    if (scriptTimedOut) return ExtractFailureReason.scriptTimeout;
    if (best?.blocked == true) return ExtractFailureReason.accessBlocked;
    final hostUrl = best?.finalUrl ?? requestUrl;
    if (best == null) {
      if (sawNetworkError) return ExtractFailureReason.networkError;
      if (loadWaitTimedOut && !sawFirstLoad) {
        return ExtractFailureReason.loadingTimeout;
      }
      if (evaluateCount > 0) return ExtractFailureReason.notProductPage;
      return ExtractFailureReason.loadingTimeout;
    }
    if (!best.looksLikeProductPage) {
      return ExtractFailureReason.notProductPage;
    }
    if (best.price == null) {
      if (isUnsupportedCurrencyHost(hostUrl)) {
        return ExtractFailureReason.unsupportedCurrency;
      }
      return ExtractFailureReason.priceAmbiguous;
    }
    return ExtractFailureReason.loadingTimeout;
  }
}

bool _isEmpty(OnDeviceExtract? parsed) =>
    parsed == null || (!parsed.hasAnything && !parsed.blocked);

bool _isNonRetryable(OnDeviceExtract? parsed, String requestUrl) {
  if (parsed == null) return false;
  if (parsed.blocked || parsed.isSoldOut) return true;
  if (parsed.looksLikeProductPage &&
      parsed.hasAnything &&
      parsed.price == null) {
    return true;
  }
  if (isUnsupportedCurrencyHost(parsed.finalUrl ?? requestUrl) &&
      parsed.price == null) {
    return true;
  }
  return false;
}

OnDeviceExtract _prefer(OnDeviceExtract? current, OnDeviceExtract next) {
  if (current == null) return next;
  return _quality(next) >= _quality(current) ? next : current;
}

int _quality(OnDeviceExtract value) {
  if (value.blocked) return -1;
  var score = 0;
  if (value.price != null) score += 100;
  if (value.optionPriceMin != null) score += 20;
  if (value.name != null) score += 10;
  if (value.image != null) score += 10;
  if (value.looksLikeProductPage) score += 5;
  switch (value.purchasePriceStatus) {
    case 'confirmed':
      score += 4;
    case 'option_dependent':
      score += 3;
    case 'provisional':
      score += 1;
  }
  switch (value.priceConfidence) {
    case 'high':
      score += 3;
    case 'medium':
      score += 2;
    case 'low':
      score += 1;
  }
  return score;
}

String? priceFingerprint(OnDeviceExtract value) {
  if (value.price == null && value.optionPriceMin == null) return null;
  return [
    value.finalUrl ?? '',
    value.source['adapter'] ?? '',
    value.price?.toString() ?? '',
    value.originalPrice?.toString() ?? '',
    value.optionPriceMin?.toString() ?? '',
    value.optionPriceMax?.toString() ?? '',
  ].join('|');
}

bool isUnsupportedCurrencyHost(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  return host == 'gap.com' ||
      host.endsWith('.gap.com') ||
      host == 'nugu.jp' ||
      host.endsWith('.nugu.jp');
}

bool isAboutBlankUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final value = url.trim().toLowerCase();
  return value == 'about:blank' || value.startsWith('about:blank?');
}

/// http/https(또는 about:blank)가 아닌 스킴인지 판정한다. `intent://...`나
/// 몰 전용 커스텀 스킴(`musinsa://`, `a-bly://` 등)은 실제 앱을 열려는
/// 딥링크라 WebView가 못 열고 onReceivedError로 network_error를 만든다 —
/// shouldOverrideUrlLoading에서 미리 걸러야 한다.
///
/// 2026-09-08 실기기(Tab S7) 로그로 확인: 무신사(musinsa.onelink.me)·
/// 에이블리(applink.a-bly.com)·지그재그(s.zigzag.kr) 공유 링크가 전부 이
/// 경로로 실패했다(무신사는 finalUrl=chrome-error://chromewebdata/로 착지,
/// 나머지 둘은 finalUrl=null·failureReason=network_error).
bool isNonHttpScheme(String? url) {
  if (url == null || url.isEmpty) return false;
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase() ?? '';
  return scheme.isNotEmpty && scheme != 'http' && scheme != 'https';
}

/// `intent://...#Intent;...;S.browser_fallback_url=<encoded>;end` 형태의
/// 안드로이드 인텐트 URI에서 브라우저 폴백 URL을 뽑아낸다. 앱 미설치·
/// WebView 등 인텐트를 못 여는 환경을 위해 이 서비스들이 함께 실어 보내는
/// 값이다. 없으면 null.
///
/// 2026-09-09 실기기 로그로 확인: 지그재그(Airbridge 기반 딥링크)는 이 방식을
/// 안 쓴다 — `S.browser_fallback_url`이 아예 없고, 대신
/// `intent://details?id=<패키지>&url=<인코딩된 커스텀스킴 딥링크>#Intent;...end`
/// 형태(플레이스토어 폴백용 인텐트 표준 형식)를 쓴다. 그 "url" 쿼리파라미터를
/// 한 번 디코드하면 `zigzag://open/product_detail?...&url=<진짜 https 상품
/// 페이지>` 같은 앱 전용 스킴 링크가 나오고, 그 안에 다시 "url" 파라미터로
/// 진짜 목적지가 한 번 더 들어있다 — 두 겹을 풀어서 최종 URL을 뽑는다.
String? extractIntentFallbackUrl(String url) {
  final match = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
  final raw = match?.group(1);
  if (raw != null && raw.isNotEmpty) {
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }
  return _extractNestedIntentUrlParam(url);
}

/// [extractIntentFallbackUrl]의 보조 경로 — `S.browser_fallback_url`이 없는
/// Airbridge류 인텐트(`intent://details?id=...&url=<encoded>#Intent;...end`)에서
/// 중첩된 "url" 쿼리파라미터를 풀어 실제 https 목적지를 찾는다.
String? _extractNestedIntentUrlParam(String url) {
  final hashIndex = url.indexOf('#Intent;');
  final head = hashIndex >= 0 ? url.substring(0, hashIndex) : url;
  final outerUri = Uri.tryParse(head);
  final outerUrlParam = outerUri?.queryParameters['url'];
  if (outerUrlParam == null || outerUrlParam.isEmpty) return null;

  // 바깥 "url" 파라미터 자체가 이미 http(s)면 그대로 쓴다.
  final asUri = Uri.tryParse(outerUrlParam);
  if (asUri != null &&
      (asUri.scheme == 'http' || asUri.scheme == 'https')) {
    return outerUrlParam;
  }

  // 커스텀 스킴(zigzag:// 등) 문자열 안에 실제 목적지가 "url=" 쿼리로 한 번 더
  // 들어있는 경우 — 이 안쪽 값은 이스케이프가 일관되지 않아(내부 https URL의
  // '&'/'?'가 인코딩 안 된 채 섞여 있음) Uri로 다시 파싱하면 값이 잘릴 수 있어,
  // 정규식으로 다음 '&' 앞까지만 직접 뽑는다(트래킹용 쿼리 일부가 빠질 순
  // 있지만, 상품 페이지 경로 자체는 온전해 정상 로드에는 지장 없다).
  final nested = RegExp(r'[?&]url=(https?://[^&]+)').firstMatch(outerUrlParam);
  return nested?.group(1);
}

String? extractHost(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  return host;
}

/// `m.a-bly.com` / `mobile.a-bly.com`처럼 같은 등록 도메인의 형제 서브도메인을
/// 동일 사이트로 본다. `co.kr` 등 2단 TLD는 마지막 3라벨을 쓴다.
String? registrableDomain(String? host) {
  if (host == null || host.isEmpty) return null;
  final parts = host.toLowerCase().split('.');
  if (parts.length < 2) return host.toLowerCase();
  const multi = {'co', 'or', 'ne', 'ac', 'go', 'com', 'net', 'org'};
  if (parts.length >= 3 && multi.contains(parts[parts.length - 2])) {
    return parts.sublist(parts.length - 3).join('.');
  }
  return parts.sublist(parts.length - 2).join('.');
}

/// 봇 차단 페이지(blocked)를 만났을 때 신뢰를 얻기 위해 한 번 들러볼 origin 홈 URL.
/// scheme+host만 남기고 path/query/fragment는 버린다. 파싱 실패 시 null.
String? homeWarmupUrl(String requestUrl) {
  final uri = Uri.tryParse(requestUrl);
  if (uri == null || uri.host.isEmpty) return null;
  return uri.replace(path: '/', query: '', fragment: '').toString();
}

bool isSameExtractSite(String requestUrl, String? candidateUrl) {
  if (candidateUrl == null || candidateUrl.isEmpty) return false;
  if (isAboutBlankUrl(candidateUrl)) return false;
  final requestHost = extractHost(requestUrl);
  final candidateHost = extractHost(candidateUrl);
  if (requestHost == null || candidateHost == null) return false;
  if (requestHost == candidateHost) return true;
  if (requestHost.endsWith('.$candidateHost') ||
      candidateHost.endsWith('.$requestHost')) {
    return true;
  }
  final requestRoot = registrableDomain(requestHost);
  final candidateRoot = registrableDomain(candidateHost);
  return requestRoot != null &&
      candidateRoot != null &&
      requestRoot == candidateRoot;
}

/// 몰 앱에서 직접 "공유"하면 몰 URL이 아니라 딥링크 리다이렉터 링크가 오는 경우가
/// 있다 — 예: 무신사 앱 공유는 `musinsa.onelink.me/...`(AppsFlyer OneLink)를 주고,
/// 이 링크가 최종적으로 `www.musinsa.com/products/...`로 리다이렉트된다. 이런
/// 호스트는 태생적으로 요청 도메인과 다른 곳으로 넘어가는 게 정상 동작이므로,
/// same-site 검사 대상에서 제외한다.
///
/// 2026-09-07 실기기(Tab S7, `R54RB01SMVB`)에서 확인: 무신사 앱에서 공유한
/// `musinsa.onelink.me/...` 링크가 same-site 필터에 걸려 이름·가격·이미지가
/// 전부(이미지만이 아니라) 비워지는 게 재현됨.
bool isKnownDeepLinkRedirectorHost(String? host) {
  if (host == null || host.isEmpty) return false;
  final h = host.toLowerCase();
  return h == 'onelink.me' || h.endsWith('.onelink.me');
}

bool isForeignExtractResult(String requestUrl, String? finalUrl) {
  if (finalUrl == null || finalUrl.isEmpty) return false;
  if (isAboutBlankUrl(finalUrl)) return true;
  if (isKnownDeepLinkRedirectorHost(extractHost(requestUrl))) return false;
  return !isSameExtractSite(requestUrl, finalUrl);
}

/// Tier 2.5 — 안 보이는 WebView 로 렌더링된 페이지에서 상품정보를 추출한다.
///
/// 서버 엔진(Tier 1 API / Tier 2 HTTP GET)이 가격을 못 얻었을 때만 부른다.
/// 사용자 단말·사용자 세션으로 자기가 저장하려는 상품 페이지 1건을 여는 것이라
/// 서버측 크롤링보다 차단·약관 리스크가 훨씬 낮다.
///
/// WebView 가 있는 플랫폼(Android/iOS)에서만 동작한다. 그 외(웹·데스크톱)에서는
/// [isSupported] 가 false 이며 [extract] 는 null 을 반환해 기존 흐름을 유지한다.
class WebViewScraper {
  WebViewScraper({ExtractClock? clock})
    : _clock = clock ?? const SystemExtractClock();

  static const String _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// 모바일 상품 URL(m.a-bly.com 등)은 데스크톱 UA면 로드가 안 끝나거나 빈 페이지가 된다.
  static const String mobileUa =
      'Mozilla/5.0 (Linux; Android 13; SM-T870) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static const String desktopUa = _desktopUa;

  /// 데스크톱 UA로는 로드가 안 끝나거나 og:image/JSON-LD가 안 채워지는 것으로
  /// 보이는 모바일 위주 상품 페이지 몰.
  ///
  /// a-bly.com은 실기기 확인으로 이미 검증됨. musinsa.com·zigzag.kr은
  /// 2026-09-07 몰별 정확도 점검에서 "사진이 안 잡힘" 버그의 후보 원인으로
  /// 추가한 것으로, 정적 분석(이 UA 분기 자체 + 위 주석)만으로 판단했고
  /// 실기기/에뮬레이터로는 검증하지 못했다 — 베타 전 실기기에서 두 몰의
  /// 이미지가 실제로 잡히는지 반드시 확인할 것. 아니라면 이 목록에서 빼야 한다.
  static bool needsMobileUa(String host) {
    final h = host.toLowerCase();
    bool isOrEnds(String domain) => h == domain || h.endsWith('.$domain');
    return isOrEnds('a-bly.com') ||
        isOrEnds('musinsa.com') ||
        isOrEnds('zigzag.kr') ||
        isOrEnds('onelink.me');
  }

  static final InAppWebViewSettings extractSettings = InAppWebViewSettings(
    userAgent: _desktopUa,
    javaScriptEnabled: true,
    clearCache: false,
    mediaPlaybackRequiresUserGesture: true,
    transparentBackground: true,
    useHybridComposition: true,
    // 2026-09-08: intent:// 딥링크(무신사·에이블리·지그재그 공유 링크)를
    // shouldOverrideUrlLoading에서 가로채려면 이 설정이 true여야 콜백이 온다.
    useShouldOverrideUrlLoading: true,
  );

  final ExtractClock _clock;

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// [url] 페이지를 열어 상품정보를 추출한다. 실패하면 실패 이유가 있는 결과 또는 null.
  Future<OnDeviceExtract?> extract(
    String url, {
    Duration maxWait = const Duration(seconds: 12),
  }) async {
    if (!isSupported) return null;

    final requestHost = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    // 2026-09-08: 유니클로는 봇 차단(blocked) 시 홈 웜업 재시도 1회가 추가로 들어갈 수
    // 있어(위 WebViewExtractLoop.run 참고) 기본 12초로는 부족할 수 있다.
    final needsWarmupBudget =
        requestHost == 'uniqlo.com' || requestHost.endsWith('.uniqlo.com');
    final effectiveMaxWait = requestHost.endsWith('anderssonbell.com')
        ? const Duration(seconds: 20)
        : (requestHost == 'a-bly.com' || requestHost.endsWith('.a-bly.com')
            ? const Duration(seconds: 28)
            : (requestHost == '4910.kr' || requestHost.endsWith('.4910.kr')
                ? const Duration(seconds: 20)
                : (needsWarmupBudget
                    ? const Duration(seconds: 25)
                    : maxWait)));

    final host = WebViewExtractHost.maybeInstance;
    if (host != null) {
      return host.extract(url,
          maxWait: effectiveMaxWait, clock: _clock);
    }

    InAppWebViewController? controller;
    HeadlessInAppWebView? headless;
    final firstLoadTimeout = requestHost == 'a-bly.com' ||
            requestHost.endsWith('.a-bly.com')
        ? const Duration(seconds: 40)
        : const Duration(seconds: 15);
    final loop = WebViewExtractLoop(
      clock: _clock,
      firstLoadTimeout: firstLoadTimeout,
    );

    try {
      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSize: const Size(360, 640),
        initialSettings: extractSettings,
        onWebViewCreated: (c) {
          controller = c;
        },
        onLoadStart: (c, uri) {
          controller = c;
          loop.onLoadStart(uri?.toString());
        },
        onLoadStop: (c, uri) {
          controller = c;
          loop.onLoadStop(uri?.toString());
        },
        onUpdateVisitedHistory: (c, uri, _) {
          controller = c;
          loop.onHistoryUpdate(uri?.toString());
        },
        shouldOverrideUrlLoading: (c, action) async {
          controller = c;
          final requested = action.request.url?.toString();
          if (!isNonHttpScheme(requested)) {
            return NavigationActionPolicy.ALLOW;
          }
          final fallback = extractIntentFallbackUrl(requested!);
          if (fallback != null) {
            await c.loadUrl(urlRequest: URLRequest(url: WebUri(fallback)));
          }
          return NavigationActionPolicy.CANCEL;
        },
        onReceivedError: (c, _, __) {
          controller = c;
          loop.onNetworkError();
        },
      );
      await headless.run();
      await headless.setSize(const Size(360, 640));
      controller ??= headless.webViewController;
      if (controller == null) {
        return OnDeviceExtract(
          failureReason: ExtractFailureReason.loadingTimeout,
        );
      }

      return loop.run(
        requestUrl: url,
        maxWait: effectiveMaxWait,
        isAlive: () => headless?.isRunning() == true,
        evaluate: (source) async {
          final view = headless;
          final current = view?.webViewController ?? controller;
          if (view == null || !view.isRunning() || current == null) {
            throw TimeoutException('webview not running');
          }
          return current.evaluateJavascript(source: source);
        },
        loadUrl: (target) async {
          final view = headless;
          final current = view?.webViewController ?? controller;
          if (view == null || !view.isRunning() || current == null) return;
          await current.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
        },
      );
    } catch (_) {
      return OnDeviceExtract(
        failureReason: loop.sawNetworkError
            ? ExtractFailureReason.networkError
            : ExtractFailureReason.loadingTimeout,
      );
    } finally {
      await headless?.dispose();
    }
  }
}
