import 'package:flutter_test/flutter_test.dart';

import 'package:figmadesign/services/product_extract_js.dart';

void main() {
  test('Python HTML 어댑터와 guard 61개 도메인이 온디바이스 관리 목록에 있다', () {
    const domains = <String>[
      'musinsa.com',
      'wconcept.co.kr',
      '29cm.co.kr',
      'fila.co.kr',
      'hago.kr',
      'lookpin.co.kr',
      'topten10.goodwearmall.com',
      'mujikorea.co.kr',
      'hmall.com',
      'lotteon.com',
      'mixxo.com',
      'dailyjou.com',
      'leekorea.co.kr',
      'filluminate.com',
      'urbanstoff.com',
      'not4u.kr',
      'insilence.co.kr',
      'fabregat.kr',
      'hotping.co.kr',
      'uniqlo.com',
      'ssg.com',
      'hi.thehyundai.com',
      'a-bly.com',
      'zigzag.kr',
      'kream.co.kr',
      'guesskorea.com',
      'levi.co.kr',
      'vans.co.kr',
      'covernat.co.kr',
      'code-graphy.com',
      'whoau.com',
      'hm.com',
      'gap.com',
      'aritzia.com',
      'noirer.com',
      'liphop.com',
      'marithe-official.com',
      'mahagrid.com',
      'vivastudio.co.kr',
      'amomento.co',
      'anderssonbell.com',
      'yaleapparel.co.kr',
      'ohora.kr',
      'withyoon.com',
      '66girls.co.kr',
      'partimento.com',
      'fashionplus.co.kr',
      'frombeginning.co.kr',
      'lfmall.co.kr',
      'thereformation.com',
      'nike.com',
      'oliveyoung.co.kr',
      'queenit.kr',
      'brandi.co.kr',
      'nugu.jp',
      'cjonstyle.com',
      '4910.kr',
      'ssfshop.com',
      'zara.com',
      'shein.com',
      'elandmall.co.kr',
    ];

    for (final domain in domains) {
      expect(productExtractJs, contains("'$domain'"), reason: domain);
    }
  });

  test('Gap과 LF몰은 양수 추출 없이 guard-only를 유지한다', () {
    expect(productExtractJs, contains("if(hostIs('gap.com'))return null"));
    expect(productExtractJs, contains("if(hostIs('lfmall.co.kr'))return null"));
  });

  test('NUGU와 SHEIN은 통화·세션 조건이 해소될 때까지 guard-only다', () {
    expect(
      productExtractJs,
      contains("if(hostIs('nugu.jp')||hostIs('shein.com'))return null"),
    );
  });

  test('관리 쇼핑몰은 전용 규칙 실패 시 범용 가격으로 우회하지 않는다', () {
    expect(
      productExtractJs,
      contains('structuredPrice=sitePricing?sitePricing.price:'),
    );
    expect(productExtractJs, contains('(managedSite?null:domPrices.price)'));
  });
}
