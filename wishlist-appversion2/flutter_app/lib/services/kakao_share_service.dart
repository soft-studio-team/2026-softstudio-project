import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../models/models.dart';

enum KakaoShareOutcome {
  openedKakaoTalk,
  openedShareSheet,
  failed,
}

class KakaoSharePayload {
  static String title(SharedBasket basket) => '${basket.ownerName} 님의 살까말까';

  static String description(SharedBasket basket) {
    final names = basket.items.map((p) => p.name).take(3).join(', ');
    if (names.isEmpty) return '상품 ${basket.items.length}개';
    if (basket.items.length > 3) {
      return '$names 외 ${basket.items.length - 3}개';
    }
    return names;
  }

  static String text({required SharedBasket basket, required String url}) {
    return '${title(basket)}\n${description(basket)}\n$url';
  }
}

class KakaoShareService {
  KakaoShareService._();

  static Future<KakaoShareOutcome> shareBasket({
    required SharedBasket basket,
    required String url,
    Rect? sharePositionOrigin,
  }) async {
    if (AppConfig.hasKakaoNativeAppKey) {
      try {
        return await _shareWithKakaoSdk(basket: basket, url: url);
      } catch (_) {
        // Native key/template issues should not block sharing.
      }
    }
    return _shareWithSystemSheet(
      basket: basket,
      url: url,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<KakaoShareOutcome> _shareWithKakaoSdk({
    required SharedBasket basket,
    required String url,
  }) async {
    final template = _feedTemplate(basket, url);
    final available =
        await ShareClient.instance.isKakaoTalkSharingAvailable();
    if (available) {
      final uri = await ShareClient.instance.shareDefault(template: template);
      await ShareClient.instance.launchKakaoTalk(uri);
      return KakaoShareOutcome.openedKakaoTalk;
    }
    final shareUrl =
        await WebSharerClient.instance.makeDefaultUrl(template: template);
    await launchBrowserTab(shareUrl, popupOpen: true);
    return KakaoShareOutcome.openedKakaoTalk;
  }

  static Future<KakaoShareOutcome> _shareWithSystemSheet({
    required SharedBasket basket,
    required String url,
    Rect? sharePositionOrigin,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: KakaoSharePayload.text(basket: basket, url: url),
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    if (result.status == ShareResultStatus.dismissed) {
      return KakaoShareOutcome.failed;
    }
    return KakaoShareOutcome.openedShareSheet;
  }

  static FeedTemplate _feedTemplate(SharedBasket basket, String url) {
    final link = Uri.parse(url);
    final image = basket.items
        .map((p) => p.image)
        .firstWhere(
          (src) => src.startsWith('https://'),
          orElse: () =>
              'https://developers.kakao.com/assets/img/about/logos/kakaolink/kakaolink_btn_medium.png',
        );
    return FeedTemplate(
      content: Content(
        title: KakaoSharePayload.title(basket),
        description: KakaoSharePayload.description(basket),
        imageUrl: Uri.parse(image),
        link: Link(
          webUrl: link,
          mobileWebUrl: link,
          androidExecutionParams: {'shared': basket.id},
          iosExecutionParams: {'shared': basket.id},
        ),
      ),
      buttonTitle: '살까말까 보기',
    );
  }
}

Future<void> shareBasketToKakaoTalk(
  BuildContext context, {
  required SharedBasket basket,
  required String url,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
  final outcome = await KakaoShareService.shareBasket(
    basket: basket,
    url: url,
    sharePositionOrigin: origin,
  );
  if (!context.mounted) return;
  if (outcome == KakaoShareOutcome.failed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('카카오톡 공유를 완료하지 못했어요')),
    );
  }
}
