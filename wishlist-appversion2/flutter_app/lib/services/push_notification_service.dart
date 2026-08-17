import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../models/models.dart';
import 'account_repository.dart';

const _channelId = 'wishkit_social';
const _channelName = 'wishkit 알림';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && isFirebaseConfigured) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

/// System banners on iOS/Android.
///
/// App open: local heads-up from the inbox listener.
/// App background/killed: FCM (needs the Cloud Function deployed).
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _messaging = FirebaseMessaging.instance;

  VoidCallback? onBannerTap;
  bool _ready = false;
  String? _uid;
  AccountRepository? _repo;
  String? _token;

  Future<void> init() async {
    if (_ready || kIsWeb) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: (_) => onBannerTap?.call(),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: '팔로우, 살까말까',
        importance: Importance.high,
      ),
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen((_) => onBannerTap?.call());
    _messaging.onTokenRefresh.listen((token) async {
      _token = token;
      final uid = _uid;
      final repo = _repo;
      if (uid != null && repo != null) {
        await repo.saveFcmToken(uid, token);
      }
    });

    _ready = true;
  }

  Future<void> register(String uid, AccountRepository repo) async {
    if (kIsWeb) return;
    await init();
    _uid = uid;
    _repo = repo;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    if (Platform.isIOS) {
      await _messaging.getAPNSToken();
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    _token = token;
    await repo.saveFcmToken(uid, token);
  }

  Future<void> unregister() async {
    final uid = _uid;
    final repo = _repo;
    final token = _token;
    _uid = null;
    _repo = null;
    _token = null;
    if (uid == null || repo == null || token == null) return;
    try {
      await repo.removeFcmToken(uid, token);
    } catch (_) {}
  }

  Future<void> showInboxBanner(AppNotification n) async {
    if (!_ready) return;
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '팔로우, 살까말까',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      n.id.hashCode,
      _titleFor(n.type),
      n.message,
      const NotificationDetails(android: android, iOS: ios),
    );
  }

  String _titleFor(AppNotificationType type) {
    return switch (type) {
      AppNotificationType.follow => '새 팔로우',
      AppNotificationType.basket => '살까말까',
      AppNotificationType.review => '친구 리뷰',
      AppNotificationType.list => '리스트 공개',
      AppNotificationType.comment => '살까말까 댓글',
    };
  }
}
