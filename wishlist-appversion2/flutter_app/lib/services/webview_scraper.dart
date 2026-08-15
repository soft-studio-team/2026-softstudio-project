import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'product_extract_js.dart';

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

  bool get hasAnything => name != null || price != null || image != null;

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
      );
    } catch (_) {
      return null;
    }
  }
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
  static const String _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36';

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// [url] 페이지를 열어 상품정보를 추출한다. 실패하면 null.
  Future<OnDeviceExtract?> extract(
    String url, {
    Duration maxWait = const Duration(seconds: 12),
  }) async {
    if (!isSupported) return null;

    final loaded = Completer<void>();
    InAppWebViewController? controller;
    HeadlessInAppWebView? headless;

    try {
      headless = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          userAgent: _desktopUa,
          javaScriptEnabled: true,
          clearCache: false,
          // 상품정보만 필요하므로 미디어 자동재생·팝업은 막아 자원을 아낀다.
          mediaPlaybackRequiresUserGesture: true,
          transparentBackground: true,
        ),
        onLoadStop: (c, _) {
          controller = c;
          if (!loaded.isCompleted) loaded.complete();
        },
        onReceivedError: (c, _, __) {
          controller = c;
          if (!loaded.isCompleted) loaded.complete();
        },
      );
      await headless.run();

      // 첫 로드 완료 대기 (최대 15초)
      await loaded.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
      controller ??= headless.webViewController;
      if (controller == null) return null;

      final deadline = DateTime.now().add(maxWait);
      OnDeviceExtract? best;
      var warmedUp = false;

      // 상품 정보(특히 가격)는 페이지 로드 후 JS로 늦게 채워진다.
      // 가격이 보일 때까지 폴링하되, 최대 시간을 넘기면 그때까지의 결과를 쓴다.
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        final raw = await controller!.evaluateJavascript(
          source: productExtractJs,
        );
        final parsed = OnDeviceExtract.fromRaw(raw);

        // 쿠팡처럼 상품 URL 직행을 막는 곳: 홈을 한 번 거친 뒤 재시도(1회).
        final looksBlocked =
            parsed == null ||
            parsed.blocked ||
            !parsed.looksLikeProductPage ||
            !parsed.hasAnything;
        if (looksBlocked && !warmedUp) {
          warmedUp = true;
          final origin = Uri.tryParse(url)?.origin;
          if (origin != null && origin.startsWith('http')) {
            await controller!.loadUrl(
              urlRequest: URLRequest(url: WebUri(origin)),
            );
            await Future<void>.delayed(const Duration(seconds: 3));
            await controller!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
            await Future<void>.delayed(const Duration(seconds: 2));
          }
          continue;
        }

        if (parsed != null &&
            parsed.looksLikeProductPage &&
            parsed.hasAnything) {
          best = parsed;
          if (parsed.price != null) return parsed; // 가격까지 확보 → 종료
        }
      }
      return best;
    } catch (_) {
      return null;
    } finally {
      await headless?.dispose();
    }
  }
}
