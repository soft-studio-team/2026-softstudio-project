import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'webview_scraper.dart';

/// 위젯 트리에 붙은 숨은 InAppWebView로 추출한다.
///
/// Headless WebView는 Activity content 자식이 없으면 뷰 계층에 붙지 못해
/// 로드 콜백과 evaluateJavascript가 멈춘다. 감사 러너와 앱 모두 이 호스트를
/// 트리에 올려 실제 PlatformView로 페이지를 연다.
class WebViewExtractHost extends StatefulWidget {
  const WebViewExtractHost({super.key, required this.child});

  final Widget child;

  static WebViewExtractHostState? get maybeInstance =>
      WebViewExtractHostState._instance;

  @override
  State<WebViewExtractHost> createState() => WebViewExtractHostState();
}

class WebViewExtractHostState extends State<WebViewExtractHost> {
  static WebViewExtractHostState? _instance;

  bool _active = false;
  String? _url;
  InAppWebViewController? _controller;
  WebViewExtractLoop? _loop;
  Completer<InAppWebViewController>? _created;

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
    if (_active) {
      return OnDeviceExtract(
        failureReason: ExtractFailureReason.loadingTimeout,
      );
    }

    final loop = WebViewExtractLoop(clock: clock);
    final created = Completer<InAppWebViewController>();
    _loop = loop;
    _url = url;
    _created = created;
    _controller = null;
    setState(() => _active = true);

    try {
      final controller = await created.future.timeout(
        loop.firstLoadTimeout,
        onTimeout: () => throw TimeoutException('webview not created'),
      );
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
      _created = null;
      _controller = null;
      _url = null;
      if (mounted) setState(() => _active = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_active && _url != null)
          Positioned(
            left: 0,
            top: 0,
            width: 360,
            height: 640,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.01,
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_url!)),
                  initialSettings: WebViewScraper.extractSettings,
                  onWebViewCreated: (controller) {
                    _controller = controller;
                    if (_created != null && !_created!.isCompleted) {
                      _created!.complete(controller);
                    }
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
          ),
      ],
    );
  }
}
