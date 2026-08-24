import Flutter
import UIKit
import WebKit

/// Flutter PlatformView WKWebView는 실기기에서 가려지면 로드/JS가 멈춘다.
/// 추출할 때만 별도 UIWindow에 진짜 WKWebView를 올린다.
enum ProductExtractHost {
  static let methodChannelName = "com.softstudio.wishlist/extract"
  static let eventChannelName = "com.softstudio.wishlist/extractEvents"

  static func bind(to messenger: FlutterBinaryMessenger) {
    Controller.shared.bind(to: messenger)
  }
}

private final class Controller: NSObject, FlutterStreamHandler, WKNavigationDelegate {
  static let shared = Controller()

  private var eventSink: FlutterEventSink?
  private var overlayWindow: UIWindow?
  private var webView: WKWebView?
  private var urlObservation: NSKeyValueObservation?
  private weak var flutterWindow: UIWindow?

  func bind(to messenger: FlutterBinaryMessenger) {
    let methods = FlutterMethodChannel(
      name: ProductExtractHost.methodChannelName,
      binaryMessenger: messenger,
    )
    methods.setMethodCallHandler { [weak self] call, result in
      DispatchQueue.main.async {
        self?.handle(call, result: result)
      }
    }
    let events = FlutterEventChannel(
      name: ProductExtractHost.eventChannelName,
      binaryMessenger: messenger,
    )
    events.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    events(["type": "ready", "url": NSNull()])
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "show":
      showOverlay()
      result(nil)
    case "hide":
      hideOverlay()
      result(nil)
    case "loadUrl":
      guard let value = call.arguments as? String, let url = URL(string: value) else {
        result(FlutterError(code: "bad_url", message: "url required", details: nil))
        return
      }
      showOverlay()
      webView?.load(URLRequest(url: url))
      result(nil)
    case "eval":
      guard let source = call.arguments as? String, let webView else {
        result(nil)
        return
      }
      webView.evaluateJavaScript(source) { value, error in
        if error != nil {
          result(nil)
          return
        }
        result(value)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func showOverlay() {
    if overlayWindow != nil, webView != nil {
      overlayWindow?.isHidden = false
      overlayWindow?.makeKeyAndVisible()
      return
    }

    guard let scene = activeWindowScene() else { return }
    flutterWindow = scene.windows.first { $0.isKeyWindow } ?? scene.windows.first

    let config = WKWebViewConfiguration()
    config.defaultWebpagePreferences.allowsContentJavaScript = true
    config.websiteDataStore = .default()
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = self
    webView.isOpaque = true
    webView.backgroundColor = .white
    webView.scrollView.backgroundColor = .white
    webView.isUserInteractionEnabled = false
    if #available(iOS 16.4, *) {
      #if DEBUG
      webView.isInspectable = true
      #endif
    }
    self.webView = webView
    urlObservation = webView.observe(\.url, options: [.new]) { [weak self] view, _ in
      self?.emit("history", url: view.url?.absoluteString)
    }

    let controller = OverlayViewController(webView: webView)
    let window = UIWindow(windowScene: scene)
    window.windowLevel = .alert + 1
    window.backgroundColor = .white
    window.rootViewController = controller
    window.isHidden = false
    window.makeKeyAndVisible()
    overlayWindow = window
    NSLog("WISHKIT_EXTRACT native webview shown")
  }

  private func hideOverlay() {
    urlObservation?.invalidate()
    urlObservation = nil
    webView?.stopLoading()
    webView?.navigationDelegate = nil
    webView = nil
    overlayWindow?.isHidden = true
    overlayWindow = nil
    flutterWindow?.makeKeyAndVisible()
    flutterWindow = nil
    NSLog("WISHKIT_EXTRACT native webview hidden")
  }

  private func emit(_ type: String, url: String?) {
    eventSink?(["type": type, "url": url as Any? ?? NSNull()])
  }

  private func activeWindowScene() -> UIWindowScene? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    emit("loadStart", url: webView.url?.absoluteString)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    emit("loadStop", url: webView.url?.absoluteString)
  }

  func webView(
    _ webView: WKWebView,
    didFail navigation: WKNavigation!,
    withError error: Error
  ) {
    emit("error", url: webView.url?.absoluteString)
  }

  func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    emit("error", url: webView.url?.absoluteString)
  }
}

private final class OverlayViewController: UIViewController {
  private let webView: WKWebView

  init(webView: WKWebView) {
    self.webView = webView
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)

    let banner = UILabel()
    banner.translatesAutoresizingMaskIntoConstraints = false
    banner.text = "상품 페이지를 읽는 중…"
    banner.textAlignment = .center
    banner.textColor = .white
    banner.backgroundColor = UIColor.black.withAlphaComponent(0.72)
    banner.font = .systemFont(ofSize: 15, weight: .semibold)
    banner.layer.cornerRadius = 12
    banner.clipsToBounds = true
    view.addSubview(banner)

    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.topAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
      banner.heightAnchor.constraint(equalToConstant: 44),
    ])
  }
}
