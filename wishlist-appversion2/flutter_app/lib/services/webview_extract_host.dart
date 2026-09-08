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
    final requestHost = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    final isAbly = requestHost == 'a-bly.com' ||
        requestHost.endsWith('.a-bly.com');
    // 지그재그 공유 링크(s.zigzag.kr)도 무신사 onelink.me와 같은 종류의
    // 1회성 공유 리다이렉터다. 2026-09-08 실기기 로그에서 intent:// 스킴을
    // 못 열어 network_error로 즉시 실패하는 게 확인됐고, 아래
    // shouldOverrideUrlLoading 수정으로 실제 상품 페이지까지 갈 수 있게
    // 되면 그 리다이렉트 홉만큼 여유 시간이 더 필요하다.
    final isZigzagShareLink =
        requestHost == 'zigzag.kr' || requestHost.endsWith('.zigzag.kr');
    // 무신사 앱 등에서 공유된 딥링크 리다이렉터(onelink.me 등)는 에이블리의
    // 봇 챌린지 리다이렉트와 같은 이유로 same-site 필터에 걸린다 — 아래
    // _acceptAnyHostLoad에서 함께 취급한다.
    final isDeepLinkRedirector = isKnownDeepLinkRedirectorHost(requestHost);
    // 2026-09-07: 같은 상품을 다시 공유해도 onelink.me 링크 자체가 매번
    // 새로 발급된다(공유 이벤트별 1회성 트래킹 코드가 붙는 AppsFlyer OneLink
    // 특성) — 즉 캐시／워밍 없이 매번 AppsFlyer 서버를 거쳐 실제 상품
    // 페이지로 리다이렉트되는 추가 홉이 필요하므로, 에이블리와 동일하게
    // 여유 있는 타임아웃을 준다.
    final firstLoadTimeout = (isAbly || isDeepLinkRedirector || isZigzagShareLink)
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
      _acceptAnyHostLoad = isAbly || isDeepLinkRedirector || isZigzagShareLink;
      _loop = loop;
      try {
        await controller.setSettings(
          settings: InAppWebViewSettings(
            userAgent: WebViewScraper.needsMobileUa(requestHost)
                ? WebViewScraper.mobileUa
                : WebViewScraper.desktopUa,
            // setSettings()는 전체 설정을 갈아치운다 — extractSettings의
            // useShouldOverrideUrlLoading:true가 여기서 안 지워지게 다시 켜야
            // intent:// 딥링크 가로채기(아래 shouldOverrideUrlLoading)가 계속 동작한다.
            useShouldOverrideUrlLoading: true,
          ),
        );
      } catch (_) {}
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      final result = await loop.run(
        requestUrl: url,
        maxWait: maxWait,
        isAlive: () => mounted && _controller != null,
        evaluate: (source) => controller.evaluateJavascript(source: source),
        loadUrl: (target) =>
            controller.loadUrl(urlRequest: URLRequest(url: WebUri(target))),
      );
      // TEMP(mall-accuracy-audit 2026-09-07): 무신사·지그재그 이미지 미추출 진단용
      // 로그. UA 후보 수정이 맞는지 실기기에서 확인하는 동안만 남겨두고, 원인이
      // 확정되면 지울 것.
      debugPrint(
        '[mall-audit] host=$requestHost '
        'ua=${WebViewScraper.needsMobileUa(requestHost) ? "mobile" : "desktop"} '
        'blocked=${result?.blocked} looksLikeProductPage=${result?.looksLikeProductPage} '
        'hasJsonLd=${result?.hasJsonLd} name=${result?.name} price=${result?.price} '
        'image=${result?.image} imageSource=${result?.source['image']} '
        'finalUrl=${result?.finalUrl} failureReason=${result?.failureReason}',
      );
      return result;
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
    }
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.mountWebView && WebViewScraper.isSupported)
          Positioned(
            // 2026-09-07: 태블릿(Tab S7)에서 공유 담기 모달이 화면 전체를 덮지
            // 않아 (0,0) 위치의 이 WebView가 모달 옆으로 그대로 보이는 게
            // 확인됨. IgnorePointer는 터치만 막지 실제로 안 보이게 하진
            // 않으므로, 화면 크기와 무관하게 항상 뷰포트 밖에 위치하도록
            // 큰 음수 오프셋으로 옮긴다(레이아웃/렌더링 자체는 유지 — JS는
            // 계속 돈다).
            left: -2000,
            top: -2000,
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
                shouldOverrideUrlLoading: (controller, action) async {
                  _controller = controller;
                  final requested = action.request.url?.toString();
                  if (_isResetting || !isNonHttpScheme(requested)) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  // 2026-09-08: 무신사(onelink.me)·에이블리(applink.a-bly.com)·
                  // 지그재그(s.zigzag.kr) 공유 링크는 intent://로 앱을 직접 열려
                  // 하고, 이 WebView는 그 스킴을 못 열어 onReceivedError→
                  // network_error로 즉시 실패했다(2026-09-08 실기기 로그로 확인).
                  // 인텐트 URI의 browser_fallback_url을 대신 로드해 실제 상품
                  // 페이지까지 이어지게 한다.
                  final fallback = extractIntentFallbackUrl(requested!);
                  // TEMP(mall-accuracy-audit 2026-09-08): 지그재그가 이 경로를
                  // 실제로 타는지, 탄다면 browser_fallback_url을 못 찾는 건지
                  // (다른 딥링크 SDK라 파라미터명이 다를 수 있음) 확인하기 위한
                  // 진단용 로그. 원인이 확정되면 지울 것.
                  debugPrint(
                    '[mall-audit intent] activeRequestUrl=$_activeRequestUrl '
                    'intentUrl=$requested fallback=$fallback',
                  );
                  if (fallback != null) {
                    await controller.loadUrl(
                      urlRequest: URLRequest(url: WebUri(fallback)),
                    );
                  }
                  return NavigationActionPolicy.CANCEL;
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
        widget.child,
      ],
    );
  }
}
