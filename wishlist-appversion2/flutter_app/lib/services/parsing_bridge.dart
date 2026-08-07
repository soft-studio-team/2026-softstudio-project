import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// HTTP client for the unmodified parsing-engine server.
///
/// Run the engine separately:
///   cd parsing-engine/server
///   pip install -r requirements.txt
///   python3 -m uvicorn api_server_engine:app --reload --port 8000
///
/// This file never imports or edits engine Python modules.
class ParsingBridge {
  ParsingBridge({this.baseUrl = 'http://127.0.0.1:8000'});

  final String baseUrl;

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
        return ParsedProductInfo.fromEngineResponse(data);
      }
    } catch (_) {
      // Offline / engine not running → keep share flow usable.
    }
    return _heuristicFromUrl(url);
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
        return ParsedProductInfo.fromEngineProduct(product);
      }
    } catch (_) {}
    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(input);
    if (urlMatch != null) {
      return parseProductUrl(urlMatch.group(0)!);
    }
    return _heuristicFromUrl(input);
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
