import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';
import 'webview_scraper.dart';

/// HTTP client for the unmodified parsing-engine server.
///
/// Run the engine separately:
///   cd parsing-engine/server
///   pip install -r requirements.txt
///   python3 -m uvicorn api_server_engine:app --reload --port 8000
///
/// This file never imports or edits engine Python modules.
class ParsingBridge {
  ParsingBridge({String? baseUrl, WebViewScraper? webViewScraper})
      : baseUrl = baseUrl ?? AppConfig.engineBaseUrl,
        _webView = webViewScraper ?? WebViewScraper();

  final String baseUrl;
  final WebViewScraper _webView;

  Future<ParsedProductInfo> parseProductUrl(String url) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/parse'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return _fillOnDevice(ParsedProductInfo.fromEngineResponse(data), url);
      }
    } catch (_) {
      // Offline / engine not running → keep share flow usable.
    }
    return _fillOnDevice(_heuristicFromUrl(url), url);
  }

  /// Share text may include title hint + URL (engine /api/scrap).
  Future<ParsedProductInfo> scrapShareInput(String input) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/scrap'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'input': input}),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final product = data['product'] as Map<String, dynamic>? ?? data;
        final info = ParsedProductInfo.fromEngineProduct(product);
        return _fillOnDevice(info, info.productUrl);
      }
    } catch (_) {}
    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(input);
    if (urlMatch != null) {
      return parseProductUrl(urlMatch.group(0)!);
    }
    return _heuristicFromUrl(input);
  }

  /// Tier 2.5 — 서버가 가격을 못 채웠을 때만 단말 WebView 로 보완한다.
  ///
  /// 이미 가격이 있으면(서버 Tier 1/2 성공) 그대로 두고, WebView 는
  /// 지원 플랫폼(Android/iOS)에서만 시도한다. 실패해도 원래 결과를 반환하므로
  /// 저장 흐름은 절대 깨지지 않는다.
  Future<ParsedProductInfo> _fillOnDevice(
      ParsedProductInfo info, String url) async {
    final needsPrice = info.price <= 0 || info.missingFields.contains('price');
    final target = info.productUrl.isNotEmpty ? info.productUrl : url;
    if (!needsPrice || !WebViewScraper.isSupported || target.isEmpty) {
      return info;
    }
    try {
      final ex = await _webView.extract(target);
      if (ex == null || !ex.hasAnything) return info;
      return info.mergeOnDevice(
        name: ex.name,
        price: ex.price,
        image: ex.image,
        platform: ex.siteName,
      );
    } catch (_) {
      return info;
    }
  }

  ParsedProductInfo _heuristicFromUrl(String url) {
    final lower = url.toLowerCase();
    String platform = '쇼핑몰';
    if (lower.contains('musinsa')) platform = '무신사';
    if (lower.contains('zigzag') || lower.contains('kakaostyle')) {
      platform = '지그재그';
    }
    if (lower.contains('29cm')) platform = '29CM';
    if (lower.contains('coupang')) platform = '쿠팡';
    if (lower.contains('wconcept')) platform = 'W CONCEPT';

    return ParsedProductInfo(
      name: '공유된 상품',
      price: 0,
      platform: platform,
      image:
          'https://images.unsplash.com/photo-1524275406383-49f669cf763a?w=400&h=400&fit=crop',
      productUrl: url,
      missingFields: const ['title', 'price', 'image_url'],
      resolvedTier: 3,
      engineUsed: false,
    );
  }
}
