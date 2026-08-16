import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'webview_scraper.dart';

/// 위젯 트리에 항상 붙어 있는 InAppWebView로 추출한다.
///
/// Headless는 Activity content 자식이 없으면 뷰 계층에 붙지 못한다.
/// 추출 순간에만 WebView를 만들면 `onWebViewCreated`가 15초 안에
/// 오지 않을 수 있어, about:blank로 미리 붙여 둔다.
class WebViewExtractHost extends StatefulWidget {
  const WebViewExtractHost({
    super.key,
    required this.child,
    this.mountWebView = true,
  });

  final Widget child;
  final bool mountWebView;

  static WebViewExtractHostState? get maybeInstance =>
      WebViewExtractHostState._instance;

  @override
  State<WebViewExtractHost> createState() => WebViewExtractHostState();
}

class WebViewExtractHostState extends State<WebViewExtractHost> {
  static WebViewExtractHostState? _instance;

  bool _busy = false;
  InAppWebViewController? _controller;
  WebViewExtractLoop? _loop;
  final Completer<InAppWebViewController> _created =
      Completer<InAppWebViewController>();

  bool get isReady => _controller != null;

  /// 컨트롤러가 붙은 뒤 단순 JS가 도는지 확인한다.
  Future<Object?> probeJavascript([String source = '1+1']) async {
    final controller = await _created.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('webview not created'),
    );
    return controller.evaluateJavascript(source: source).timeout(
      const Duration(seconds: 4),
    );
  }

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }

  Future<OnDeviceExtract?> extract(
    String url, {
    required Duration maxWait,
    required ExtractClock clock,
  }) async {
    if (_busy) {
      return OnDeviceExtract(
        failureReason: ExtractFailureReason.loadingTimeout,
      );
    }
    _busy = true;
    final loop = WebViewExtractLoop(clock: clock);

    try {
      final controller = await _created.future.timeout(
        loop.firstLoadTimeout,
        onTimeout: () => throw TimeoutException('webview not created'),
      );
      // 이전 상품 페이지의 load 콜백이 새 루프를 오염시키지 않게 먼저 비운다.
      _loop = null;
      await controller.stopLoading();
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
      _loop = loop;
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      return loop.run(
        requestUrl: url,
        maxWait: maxWait,
        isAlive: () => mounted && _controller != null,
        evaluate: (source) => controller.evaluateJavascript(source: source),
        loadUrl: (target) =>
            controller.loadUrl(urlRequest: URLRequest(url: WebUri(target))),
      );
    } on TimeoutException {
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
      _loop = null;
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.mountWebView && WebViewScraper.isSupported)
          Positioned(
            left: 0,
            top: 0,
            width: 360,
            height: 640,
            child: IgnorePointer(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri('about:blank')),
                initialSettings: WebViewScraper.extractSettings,
                onWebViewCreated: (controller) {
                  _controller = controller;
                  if (!_created.isCompleted) _created.complete(controller);
                },
                onLoadStart: (controller, uri) {
                  _controller = controller;
                  _loop?.onLoadStart(uri?.toString());
                },
                onLoadStop: (controller, uri) {
                  _controller = controller;
                  _loop?.onLoadStop(uri?.toString());
                },
                onUpdateVisitedHistory: (controller, uri, _) {
                  _controller = controller;
                  _loop?.onHistoryUpdate(uri?.toString());
                },
                onReceivedError: (controller, _, __) {
                  _controller = controller;
                  _loop?.onNetworkError();
                },
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}
