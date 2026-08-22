import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'webview_scraper.dart';

/// 실기기 iOS는 Flutter PlatformView WKWebView가 가려지면 멈춘다.
/// 네이티브 UIWindow 위의 WKWebView로 추출 루프를 돌린다.
class IosNativeExtractHost {
  IosNativeExtractHost({
    MethodChannel? methods,
    EventChannel? events,
    ExtractClock? clock,
  }) : _methods = methods ?? const MethodChannel('com.softstudio.wishlist/extract'),
       _events =
           events ?? const EventChannel('com.softstudio.wishlist/extractEvents'),
       _clock = clock ?? const SystemExtractClock();

  final MethodChannel _methods;
  final EventChannel _events;
  final ExtractClock _clock;

  static bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<OnDeviceExtract?> extract(
    String url, {
    required Duration maxWait,
  }) async {
    final requestHost = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    final isAbly =
        requestHost == 'a-bly.com' || requestHost.endsWith('.a-bly.com');
    final firstLoadTimeout = isAbly
        ? const Duration(seconds: 40)
        : const Duration(seconds: 15);
    final loop = WebViewExtractLoop(
      clock: _clock,
      firstLoadTimeout: firstLoadTimeout,
    );

    final ready = Completer<void>();
    final sub = _events.receiveBroadcastStream().listen((event) {
      if (event is! Map) return;
      final type = event['type'] as String?;
      final target = event['url'] is String ? event['url'] as String : null;
      switch (type) {
        case 'ready':
          if (!ready.isCompleted) ready.complete();
        case 'loadStart':
          loop.onLoadStart(target);
        case 'loadStop':
          loop.onLoadStop(target);
        case 'history':
          loop.onHistoryUpdate(target);
        case 'error':
          loop.onNetworkError();
      }
    });

    try {
      await ready.future.timeout(const Duration(seconds: 4));
      await _methods.invokeMethod('show');
      await _methods.invokeMethod('loadUrl', url);
      return loop.run(
        requestUrl: url,
        maxWait: maxWait,
        evaluate: (source) => _methods.invokeMethod('eval', source),
        loadUrl: (target) => _methods.invokeMethod('loadUrl', target),
      );
    } on TimeoutException {
      return OnDeviceExtract(
        failureReason: ExtractFailureReason.loadingTimeout,
      );
    } on MissingPluginException {
      return OnDeviceExtract(
        failureReason: ExtractFailureReason.loadingTimeout,
      );
    } catch (_) {
      return OnDeviceExtract(
        failureReason: loop.sawNetworkError
            ? ExtractFailureReason.networkError
            : ExtractFailureReason.loadingTimeout,
      );
    } finally {
      await sub.cancel();
      try {
        await _methods.invokeMethod('hide');
      } catch (_) {}
    }
  }
}
