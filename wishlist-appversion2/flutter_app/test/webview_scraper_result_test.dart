import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:figmadesign/services/webview_extract_host.dart';
import 'package:figmadesign/services/webview_scraper.dart';

class _FakeClock implements ExtractClock {
  _FakeClock() : _now = DateTime(2026, 8, 16, 16, 0, 0);

  DateTime _now;
  final delays = <Duration>[];

  @override
  DateTime now() => _now;

  @override
  Future<void> delay(Duration duration) async {
    delays.add(duration);
    _now = _now.add(duration);
  }
}

String _extractJson({
  String? name,
  int? price,
  int? originalPrice,
  String? image,
  bool blocked = false,
  bool looksLikeProductPage = true,
  String? adapter,
  String? finalUrl,
  String availability = 'unknown',
  String purchasePriceStatus = 'unknown',
  int? optionPriceMin,
  int? optionPriceMax,
}) {
  return jsonEncode({
    'name': name,
    'price': price,
    'originalPrice': originalPrice,
    'image': image,
    'blocked': blocked,
    'looksLikeProductPage': looksLikeProductPage,
    'finalUrl': finalUrl,
    'availability': availability,
    'purchasePriceStatus': purchasePriceStatus,
    'optionPriceMin': optionPriceMin,
    'optionPriceMax': optionPriceMax,
    'source': {if (adapter != null) 'adapter': adapter},
  });
}

void main() {
  test('온디바이스 v2 가격 의미 필드를 파싱한다', () {
    final result = OnDeviceExtract.fromRaw('''
      {
        "name": "상품",
        "price": 30400,
        "originalPrice": 32000,
        "purchasePriceStatus": "option_dependent",
        "priceConfidence": "high",
        "availability": "available",
        "optionDependent": true,
        "optionPriceMin": 30400,
        "optionPriceMax": 33400,
        "priceEvidence": [
          {
            "price_role": "purchase_price",
            "source": "rendered-webview",
            "adapter": "29cm",
            "field": "item.sellPrice"
          }
        ]
      }
    ''');

    expect(result, isNotNull);
    expect(result!.purchasePriceStatus, 'option_dependent');
    expect(result.priceConfidence, 'high');
    expect(result.optionPriceMin, 30400);
    expect(result.optionPriceMax, 33400);
    expect(result.priceEvidence.single['adapter'], '29cm');
  });

  test('실패 이유를 파싱하고 보존한다', () {
    final result = OnDeviceExtract.fromRaw(
      '{"name":"상품","failureReason":"access_blocked","blocked":true}',
    );
    expect(result, isNotNull);
    expect(result!.failureReason, ExtractFailureReason.accessBlocked);
    expect(result.blocked, isTrue);
  });

  test('리다이렉트와 SPA 주소 변경이 멈춘 뒤에만 추출한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(
      clock: clock,
      settleWindow: const Duration(milliseconds: 600),
      pollInterval: const Duration(milliseconds: 200),
    );
    final evalAt = <DateTime>[];
    final startedAt = clock.now();

    loop.onLoadStart('https://shop.example/a');
    loop.onLoadStop('https://shop.example/b');
    loop.onHistoryUpdate('https://shop.example/c');

    final result = await loop.run(
      requestUrl: 'https://shop.example/a',
      maxWait: const Duration(seconds: 4),
      evaluate: (_) async {
        evalAt.add(clock.now());
        return _extractJson(
          name: '상품',
          price: 10000,
          adapter: 'demo',
          finalUrl: 'https://shop.example/c',
        );
      },
      loadUrl: (_) async {},
    );

    expect(evalAt, isNotEmpty);
    expect(
      evalAt.first.difference(startedAt) >= const Duration(milliseconds: 600),
      isTrue,
    );
    expect(result?.price, 10000);
  });

  test('evaluateJavascript timeout 이후에는 같은 세션에 호출을 중첩하지 않는다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(
      clock: clock,
      scriptTimeout: const Duration(milliseconds: 20),
    );
    loop.onLoadStop('https://shop.example/hang');

    final result = await loop.run(
      requestUrl: 'https://shop.example/hang',
      maxWait: const Duration(seconds: 4),
      evaluate: (_) => Completer<dynamic>().future,
      loadUrl: (_) async {},
    );

    expect(loop.evaluateCount, 1);
    expect(result?.failureReason, ExtractFailureReason.scriptTimeout);
    expect(loop.scriptTimedOut, isTrue);
  });

  // 2026-09-08: 이 테스트는 원래 "차단이면 재시도 없이 즉시 종료"를 검증했지만,
  // 같은 날 추가된 홈 웜업 재시도 기능(WebViewExtractLoop.run 참고 — 유니클로
  // 실기기 재검증으로 확인된 그 수정) 때문에 기대값이 낡았었다(loads/reloadCount를
  // 0으로 기대 — 실제로는 홈 방문 1회가 의도된 동작). 홈 웜업 후에도 여전히
  // blocked면 재시도를 한 번만 쓰고 accessBlocked로 종료하는지로 갱신.
  test('명시적 접근 차단은 홈 웜업 재시도 1회 후에도 계속 차단이면 accessBlocked로 종료한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(clock: clock);
    var loads = 0;
    loop.onLoadStop('https://shop.example/blocked');

    final result = await loop.run(
      requestUrl: 'https://shop.example/blocked',
      maxWait: const Duration(seconds: 8),
      evaluate: (_) async => _extractJson(
        blocked: true,
        looksLikeProductPage: false,
        finalUrl: 'https://shop.example/blocked',
      ),
      loadUrl: (url) async {
        loads += 1;
        loop.onLoadStart(url);
        loop.onLoadStop(url);
      },
    );

    expect(result?.blocked, isTrue);
    expect(result?.failureReason, ExtractFailureReason.accessBlocked);
    // 홈 워밍업 방문 1회 + 원래 URL 재요청 1회 = loadUrl 총 2번.
    expect(loads, 2);
    expect(loop.reloadCount, 2);
    // 원본 페이지 평가(웜업 유발) → 홈 페이지 평가(버려짐) → 재요청한 원본 평가(확정).
    expect(loop.evaluateCount, 3);
  });

  test('빈 결과에만 제한적으로 1회 reload 한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(clock: clock);
    var loads = 0;
    loop.onLoadStop('https://shop.example/empty');

    final result = await loop.run(
      requestUrl: 'https://shop.example/empty',
      maxWait: const Duration(seconds: 3),
      evaluate: (_) async => _extractJson(looksLikeProductPage: false),
      loadUrl: (url) async {
        loads += 1;
        loop.onLoadStart(url);
        loop.onLoadStop(url);
      },
    );

    expect(loads, 1);
    expect(loop.reloadCount, 1);
    expect(result?.failureReason, ExtractFailureReason.notProductPage);
  });

  test('품절·가격 충돌·미지원 통화는 reload 하지 않는다', () async {
    Future<int> reloadsFor(String json) async {
      final clock = _FakeClock();
      final loop = WebViewExtractLoop(clock: clock);
      var loads = 0;
      loop.onLoadStop('https://shop.example/x');
      await loop.run(
        requestUrl: 'https://www.gap.com/p/1',
        maxWait: const Duration(milliseconds: 800),
        evaluate: (_) async => json,
        loadUrl: (_) async => loads += 1,
      );
      return loads;
    }

    expect(
      await reloadsFor(
        _extractJson(
          name: '품절',
          availability: 'sold_out',
          image: 'https://x/a',
        ),
      ),
      0,
    );
    expect(
      await reloadsFor(
        _extractJson(
          name: '상품',
          image: 'https://x/a',
          looksLikeProductPage: true,
        ),
      ),
      0,
    );
    expect(
      await reloadsFor(
        _extractJson(
          name: 'Gap item',
          looksLikeProductPage: true,
          finalUrl: 'https://www.gap.com/p/1',
        ),
      ),
      0,
    );
  });

  test('같은 가격 fingerprint가 두 번 연속 일치하면 확정한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(clock: clock);
    loop.onLoadStop('https://shop.example/p');
    var evals = 0;

    final result = await loop.run(
      requestUrl: 'https://shop.example/p',
      maxWait: const Duration(seconds: 8),
      evaluate: (_) async {
        evals += 1;
        return _extractJson(
          name: '상품',
          price: 24800,
          originalPrice: 25800,
          adapter: 'hotping',
          optionPriceMin: 24800,
          optionPriceMax: 25800,
          finalUrl: 'https://shop.example/p',
        );
      },
      loadUrl: (_) async {},
    );

    expect(evals, 2);
    expect(result?.price, 24800);
    expect(result?.failureReason, isNull);
  });

  test('fingerprint가 바뀌면 두 번 연속 같기 전에는 확정하지 않는다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(clock: clock);
    loop.onLoadStop('https://shop.example/p');
    final prices = <int>[10000, 20000, 20000];
    var index = 0;

    final result = await loop.run(
      requestUrl: 'https://shop.example/p',
      maxWait: const Duration(seconds: 8),
      evaluate: (_) async {
        final price = prices[index < prices.length ? index : prices.length - 1];
        index += 1;
        return _extractJson(
          name: '상품',
          price: price,
          adapter: 'demo',
          finalUrl: 'https://shop.example/p',
        );
      },
      loadUrl: (_) async {},
    );

    expect(index, 3);
    expect(result?.price, 20000);
  });

  test('대기 시간이 끝나면 가장 품질 높은 best를 반환한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(
      clock: clock,
      pollInterval: const Duration(milliseconds: 200),
    );
    loop.onLoadStop('https://shop.example/p');
    var evals = 0;

    final result = await loop.run(
      requestUrl: 'https://shop.example/p',
      maxWait: const Duration(milliseconds: 900),
      evaluate: (_) async {
        evals += 1;
        if (evals == 1) {
          return _extractJson(name: '상품', looksLikeProductPage: true);
        }
        return _extractJson(
          name: '상품',
          price: 15900,
          adapter: 'not4u',
          finalUrl: 'https://shop.example/p',
        );
      },
      loadUrl: (_) async {},
    );

    expect(result?.price, 15900);
    expect(evals, lessThan(4));
  });

  test('첫 로드가 없으면 추출을 시도한 뒤 loading_timeout으로 분류한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(
      clock: clock,
      firstLoadTimeout: const Duration(milliseconds: 400),
      pollInterval: const Duration(milliseconds: 200),
    );

    final result = await loop.run(
      requestUrl: 'https://shop.example/slow',
      maxWait: const Duration(seconds: 1),
      evaluate: (_) async => null,
      loadUrl: (_) async {},
    );

    expect(result?.failureReason, ExtractFailureReason.loadingTimeout);
    expect(loop.evaluateCount, greaterThan(0));
    expect(loop.loadWaitTimedOut, isTrue);
  });

  test('네트워크 오류 후 결과가 없으면 network_error로 분류한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(clock: clock);
    loop.onNetworkError();

    final result = await loop.run(
      requestUrl: 'https://shop.example/down',
      maxWait: const Duration(milliseconds: 400),
      evaluate: (_) async => null,
      loadUrl: (_) async {},
    );

    expect(result?.failureReason, ExtractFailureReason.networkError);
  });

  test('상품 페이지인데 가격이 없으면 price_ambiguous로 분류한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(clock: clock);
    loop.onLoadStop('https://shop.example/p');

    final result = await loop.run(
      requestUrl: 'https://shop.example/p',
      maxWait: const Duration(milliseconds: 800),
      evaluate: (_) async => _extractJson(name: '상품', image: 'https://x/a.jpg'),
      loadUrl: (_) async {},
    );

    expect(result?.failureReason, ExtractFailureReason.priceAmbiguous);
    expect(result?.name, '상품');
  });

  test('Gap/NUGU처럼 미지원 통화 호스트는 unsupported_currency로 분류한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(clock: clock);
    loop.onLoadStop('https://www.nugu.jp/product/1');

    final result = await loop.run(
      requestUrl: 'https://www.nugu.jp/product/1',
      maxWait: const Duration(milliseconds: 800),
      evaluate: (_) async => _extractJson(
        name: 'NUGU',
        looksLikeProductPage: true,
        finalUrl: 'https://www.nugu.jp/product/1',
      ),
      loadUrl: (_) async {},
    );

    expect(result?.failureReason, ExtractFailureReason.unsupportedCurrency);
  });

  test('about:blank 로드는 첫 상품 로드로 치지 않는다', () {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(clock: clock);
    loop.onLoadStart('about:blank');
    loop.onLoadStop('about:blank');
    expect(loop.sawFirstLoad, isFalse);
    expect(loop.loading, isFalse);

    loop.onLoadStop('https://www.vans.co.kr/PRODUCT/VN000D6WBOM');
    expect(loop.sawFirstLoad, isTrue);
  });

  test('이전 쇼핑몰 finalUrl 결과는 버리고 요청 호스트만 확정한다', () async {
    final clock = _FakeClock();
    final loop = WebViewExtractLoop(clock: clock);
    loop.onLoadStop('https://www.brandi.co.kr/products/1');

    final result = await loop.run(
      requestUrl: 'https://www.brandi.co.kr/products/1',
      maxWait: const Duration(milliseconds: 800),
      evaluate: (_) async => _extractJson(
        name: '퀸잇 상품',
        price: 12900,
        image: 'https://x/a.jpg',
        finalUrl: 'https://web.queenit.kr/product/old',
      ),
      loadUrl: (_) async {},
    );

    expect(result?.price, isNull);
    expect(result?.name, isNull);
    expect(result?.failureReason, ExtractFailureReason.notProductPage);
  });

  test('같은 사이트의 www/서브도메인은 요청 호스트로 인정한다', () {
    expect(
      isSameExtractSite(
        'https://vans.co.kr/PRODUCT/1',
        'https://www.vans.co.kr/PRODUCT/1',
      ),
      isTrue,
    );
    expect(
      isSameExtractSite(
        'https://a-bly.com/goods/1',
        'https://mobile.a-bly.com/goods/1',
      ),
      isTrue,
    );
    expect(
      isSameExtractSite(
        'https://m.a-bly.com/goods/1',
        'https://mobile.a-bly.com/goods/1',
      ),
      isTrue,
    );
    expect(
      isSameExtractSite(
        'https://www.brandi.co.kr/products/1',
        'https://web.queenit.kr/product/1',
      ),
      isFalse,
    );
    expect(isForeignExtractResult('https://x.example/p', 'about:blank'), isTrue);
    expect(isForeignExtractResult('https://x.example/p', null), isFalse);
  });

  testWidgets('추출 호스트는 트리에 붙으면 인스턴스를 등록한다', (tester) async {
    expect(WebViewExtractHost.maybeInstance, isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: WebViewExtractHost(
          mountWebView: false,
          child: SizedBox.shrink(),
        ),
      ),
    );
    expect(WebViewExtractHost.maybeInstance, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(WebViewExtractHost.maybeInstance, isNull);
  });

  // 2026-09-07 몰별 정확도 점검: 무신사·지그재그 이미지 미추출 후보 원인으로
  // 모바일 UA 목록에 추가. 실기기/에뮬레이터로 검증되지 않은 변경이므로,
  // 베타 전 실기기에서 두 몰의 이미지가 실제로 잡히는지 반드시 확인할 것.
  test('에이블리·무신사·지그재그는 모바일 UA를 쓰고 그 외 몰은 데스크톱 UA를 쓴다', () {
    expect(WebViewScraper.needsMobileUa('a-bly.com'), isTrue);
    expect(WebViewScraper.needsMobileUa('mobile.a-bly.com'), isTrue);
    expect(WebViewScraper.needsMobileUa('musinsa.com'), isTrue);
    expect(WebViewScraper.needsMobileUa('www.musinsa.com'), isTrue);
    expect(WebViewScraper.needsMobileUa('zigzag.kr'), isTrue);
    expect(WebViewScraper.needsMobileUa('m.zigzag.kr'), isTrue);
    expect(WebViewScraper.needsMobileUa('29cm.co.kr'), isFalse);
    expect(WebViewScraper.needsMobileUa('kream.co.kr'), isFalse);
    expect(WebViewScraper.needsMobileUa('musinsa.onelink.me'), isTrue);
  });

  // 2026-09-07 실기기(Tab S7) 재현: 무신사 앱에서 공유한
  // https://musinsa.onelink.me/... 링크가 www.musinsa.com/products/...로
  // 리다이렉트되는데, 두 호스트가 서로 다른 등록 도메인이라 same-site 필터에
  // 걸려 추출 결과 전체가 버려졌었다.
  test('앱 공유 딥링크 리다이렉터(onelink.me)는 다른 도메인으로 넘어가도 foreign 취급하지 않는다', () {
    expect(isKnownDeepLinkRedirectorHost('onelink.me'), isTrue);
    expect(isKnownDeepLinkRedirectorHost('musinsa.onelink.me'), isTrue);
    expect(isKnownDeepLinkRedirectorHost('musinsa.com'), isFalse);

    expect(
      isForeignExtractResult(
        'https://musinsa.onelink.me/ANAQ/jaiyf8v5',
        'https://www.musinsa.com/products/1234567',
      ),
      isFalse,
    );
    // 무관한 일반 사이트가 전혀 다른 도메인으로 튀는 건 여전히 foreign이어야 한다.
    expect(
      isForeignExtractResult(
        'https://x.example/p',
        'https://y.example/p',
      ),
      isTrue,
    );
  });

  // 2026-09-08 실기기(Tab S7) 로그: 무신사·에이블리·지그재그 공유 링크가
  // intent:// 스킴으로 앱을 직접 열려 하고, WebView가 그 스킴을 못 열어
  // onReceivedError→network_error로 즉시 실패하는 게 확인됨.
  test('http/https가 아닌 스킴(intent:// 등)을 판정한다', () {
    expect(
      isNonHttpScheme(
        'intent://products/1234#Intent;scheme=https;package=com.musinsa.store;end',
      ),
      isTrue,
    );
    expect(isNonHttpScheme('musinsa://products/1234'), isTrue);
    expect(isNonHttpScheme('https://www.musinsa.com/products/1234'), isFalse);
    expect(isNonHttpScheme('http://a-bly.com/goods/1'), isFalse);
    expect(isNonHttpScheme(null), isFalse);
    expect(isNonHttpScheme(''), isFalse);
  });

  test('intent:// URI에서 browser_fallback_url을 뽑아낸다', () {
    final intentUrl =
        'intent://www.musinsa.com/products/1234#Intent;scheme=https;'
        'package=com.musinsa.store;'
        'S.browser_fallback_url=https%3A%2F%2Fwww.musinsa.com%2Fproducts%2F1234;'
        'end';
    expect(
      extractIntentFallbackUrl(intentUrl),
      'https://www.musinsa.com/products/1234',
    );
    expect(
      extractIntentFallbackUrl('intent://no-fallback#Intent;scheme=https;end'),
      isNull,
    );
    expect(
      extractIntentFallbackUrl('https://www.musinsa.com/products/1234'),
      isNull,
    );
  });
}
