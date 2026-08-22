import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'webview_scraper.dart';

/// 위젯 트리에 항상 붙어 있는 InAppWebView로 추출한다.
///
/// Headless는 Activity content 자식이 없으면 뷰 계층에 붙지 못한다.
/// 추출 순간에만 WebView를 만들면 `onWebViewCreated`가 15초 안에
/// 오지 않을 수 있어, about:blank로 미리 붙여 둔다.
///
/// 시뮬레이터는 앱 뒤에 가려 둬도 JS가 도는 경우가 많다. 실기기 iPhone은
/// 가려진 WKWebView를 멈추므로, 웹뷰는 항상 앱 **앞**에 두고 추출 중에만 키운다.
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

  final _webViewKey = GlobalKey();
  bool _busy = false;
  InAppWebViewController? _controller;
  WebViewExtractLoop? _loop;
  Completer<void>? _blankReady;
  String? _activeRequestUrl;
  bool _acceptAnyHostLoad = false;
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
    if (mounted) setState(() {});
    // 레이아웃이 커진 뒤에만 로드한다. 가려진 채로 만든 WKWebView는
    // 앞으로 옮겨도 프로세스가 안 살아나는 경우가 있다.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await WidgetsBinding.instance.endOfFrame;
    final requestHost = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    final isAbly = requestHost == 'a-bly.com' ||
        requestHost.endsWith('.a-bly.com');
    final firstLoadTimeout = isAbly
        ? const Duration(seconds: 40)
        : const Duration(seconds: 15);
    final loop = WebViewExtractLoop(
      clock: clock,
      firstLoadTimeout: firstLoadTimeout,
    );

    try {
      final controller = await _created.future.timeout(
        loop.firstLoadTimeout,
        onTimeout: () => throw TimeoutException('webview not created'),
      );
      // 이전 상품 페이지의 load 콜백·DOM이 새 루프를 오염시키지 않게
      // about:blank onLoadStop까지 기다린 뒤에만 대상 URL을 연다.
      _loop = null;
      _activeRequestUrl = null;
      _acceptAnyHostLoad = false;
      await _resetToBlank(controller);
      _activeRequestUrl = url;
      // 에이블리는 봇 챌린지/중간 호스트로 리다이렉트되며 same-site 필터에
      // 막히면 onLoadStop이 루프에 안 들어온다.
      _acceptAnyHostLoad = isAbly;
      _loop = loop;
      final ua = WebViewScraper.userAgentForHost(requestHost);
      if (ua != null) {
        try {
          await controller.setSettings(
            settings: InAppWebViewSettings(userAgent: ua),
          );
        } catch (_) {}
      }
      await _waitUntilJavascriptReady(controller);
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
      _activeRequestUrl = null;
      _acceptAnyHostLoad = false;
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<bool> _waitUntilJavascriptReady(
    InAppWebViewController controller,
  ) async {
    for (var i = 0; i < 15; i++) {
      try {
        final probe = await controller
            .evaluateJavascript(source: '1+1')
            .timeout(const Duration(milliseconds: 800));
        if (probe == 2 || probe == 2.0 || probe == '2') return true;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  bool get _isResetting => _blankReady != null;

  void _finishBlankReset() {
    final pending = _blankReady;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  Future<void> _resetToBlank(InAppWebViewController controller) async {
    _blankReady = Completer<void>();
    try {
      try {
        await controller.stopLoading();
      } catch (_) {}
      try {
        await controller.loadUrl(
          urlRequest: URLRequest(url: WebUri('about:blank')),
        );
      } catch (_) {
        return;
      }
      try {
        await _blankReady!.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // blank 콜백이 안 와도 대상 URL 로드는 진행한다.
      }
    } finally {
      _finishBlankReset();
      _blankReady = null;
    }
  }

  bool _shouldForward(String? url) {
    if (_isResetting) return false;
    if (isAboutBlankUrl(url)) return false;
    final active = _activeRequestUrl;
    if (active == null) return false;
    if (_acceptAnyHostLoad) return true;
    if (url == null || url.isEmpty) return true;
    return isSameExtractSite(active, url);
  }

  Widget _extractWebView(double width, double height) {
    return Positioned(
      left: 0,
      top: 0,
      width: width,
      height: height,
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.white,
          child: InAppWebView(
            key: _webViewKey,
            initialUrlRequest: URLRequest(url: WebUri('about:blank')),
            initialSettings: WebViewScraper.extractSettings,
            onWebViewCreated: (controller) {
              _controller = controller;
              if (!_created.isCompleted) _created.complete(controller);
            },
            onLoadStart: (controller, uri) {
              _controller = controller;
              final url = uri?.toString();
              if (_isResetting || !_shouldForward(url)) return;
              _loop?.onLoadStart(url);
            },
            onLoadStop: (controller, uri) {
              _controller = controller;
              final url = uri?.toString();
              if (_isResetting) {
                if (isAboutBlankUrl(url)) _finishBlankReset();
                return;
              }
              if (!_shouldForward(url)) return;
              _loop?.onLoadStop(url);
            },
            onUpdateVisitedHistory: (controller, uri, _) {
              _controller = controller;
              final url = uri?.toString();
              if (_isResetting || !_shouldForward(url)) return;
              _loop?.onHistoryUpdate(url);
            },
            onReceivedError: (controller, _, __) {
              _controller = controller;
              if (_isResetting) {
                _finishBlankReset();
                return;
              }
              _loop?.onNetworkError();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final show = widget.mountWebView && WebViewScraper.isSupported;
    // 스택 순서를 바꾸지 않는다. 가렸다가 앞으로 옮기면 실기기 WKWebView가
    // 죽은 채로 남는다. 항상 앱 앞에 두고, 추출 중에만 화면만 키운다.
    final width = _busy ? size.width : 8.0;
    final height = _busy ? size.height : 8.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (show) _extractWebView(width, height),
        if (_busy)
          const Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: IgnorePointer(
              child: Material(
                color: Color(0xB8000000),
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    '상품 페이지를 읽는 중…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
