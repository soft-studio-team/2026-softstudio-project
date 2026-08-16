import 'package:flutter_test/flutter_test.dart';

import 'package:figmadesign/services/webview_scraper.dart';

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
}
