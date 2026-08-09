import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'data/app_store.dart';
import 'firebase_options.dart';
import 'screens/auth/account_recovery_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/friends/friends_screen.dart';
import 'screens/mypage/mypage_screen.dart';
import 'screens/product/product_detail_screen.dart';
import 'screens/salkamalka/salkamalka_screen.dart';
import 'screens/share/share_intake_screen.dart';
import 'screens/shared/shared_wishlist_screen.dart';
import 'screens/wishlist/wishlist_screen.dart';
import 'theme/diary_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isFirebaseConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final store = AppStore();
  await store.init();
  runApp(WishlistApp(store: store));
}

class WishlistApp extends StatefulWidget {
  const WishlistApp({super.key, required this.store});

  final AppStore store;

  @override
  State<WishlistApp> createState() => _WishlistAppState();
}

class _WishlistAppState extends State<WishlistApp> {
  late final GoRouter router;
  StreamSubscription? _shareSub;

  @override
  void initState() {
    super.initState();
    router = _buildRouter(widget.store);
    _listenShares();
  }

  void _listenShares() {
    // App already running
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      final text = files
          .map((f) => f.path)
          .where((p) => p.startsWith('http'))
          .cast<String?>()
          .firstOrNull;
      // Also check shared text via value if available
      if (text != null) {
        widget.store.setPendingShareUrl(text);
        router.go('/share');
      }
    }, onError: (_) {});

    // App launched by share
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      final urls = files.map((f) => f.path).where((p) => p.startsWith('http'));
      if (urls.isNotEmpty) {
        widget.store.setPendingShareUrl(urls.first);
        router.go('/share');
      }
    });
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.store,
      child: MaterialApp.router(
        title: 'wishkit',
        debugShowCheckedModeBanner: false,
        theme: DiaryTheme.light,
        routerConfig: router,
      ),
    );
  }
}

GoRouter _buildRouter(AppStore store) {
  return GoRouter(
    initialLocation: store.isLoggedIn
        ? '/'
        : (store.awaitingEmailVerification ? '/verify-email' : '/login'),
    refreshListenable: store,
    redirect: (context, state) {
      final loggedIn = store.isLoggedIn;
      final awaiting = store.awaitingEmailVerification;
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      final onVerify = loc == '/verify-email';
      final onRecovery = loc == '/account-recovery';

      if (awaiting) {
        if (!onVerify) return '/verify-email';
        return null;
      }
      if (!loggedIn && !onLogin && !onRecovery) return '/login';
      if (loggedIn && (onLogin || onVerify || onRecovery)) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, __) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/account-recovery',
        builder: (_, __) => const AccountRecoveryScreen(),
      ),
      GoRoute(
        path: '/share',
        builder: (context, state) => ShareIntakeScreen(
          sharedUrl: state.uri.queryParameters['url'],
        ),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => ProductDetailScreen(
          productId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/catalog-product/:id',
        builder: (context, state) => ProductDetailScreen(
          productId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/friend-wishlist/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final store = context.read<AppStore>();
          final list = store.friendWishlistById(id);
          if (list == null) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              body: const Center(child: Text('위시리스트를 찾을 수 없어요')),
            );
          }
          return SharedWishlistScreen(
            title: list.listName,
            subtitle: '${list.friendName} 님의 공개 위시리스트',
            products: list.items,
            accentColor: DiaryColors.folderPink,
          );
        },
      ),
      GoRoute(
        path: '/shared/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final store = context.read<AppStore>();
          final shared = store.sharedBasketById(id);
          if (shared == null) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              body: const Center(child: Text('공유 링크를 찾을 수 없어요')),
            );
          }
          return SharedWishlistScreen(
            title: shared.title,
            subtitle: '${shared.ownerName} 님이 공유한 살까말까 바구니',
            products: shared.items,
            accentColor: DiaryColors.folderPeach,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const WishlistScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/friends', builder: (_, __) => const FriendsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/basket',
                builder: (_, __) => const SalkamalkaScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile', builder: (_, __) => const MyPageScreen()),
          ]),
        ],
      ),
    ],
  );
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: DiaryColors.white,
          border: Border(
            top: BorderSide(color: DiaryColors.ink.withValues(alpha: 0.08)),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  index: 0,
                  label: 'wishkit',
                  icon: Icons.star_border,
                  activeIcon: Icons.star,
                  shell: navigationShell,
                ),
                _NavItem(
                  index: 1,
                  label: '내 친구',
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  shell: navigationShell,
                ),
                _NavItem(
                  index: 2,
                  label: '살까말까',
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  shell: navigationShell,
                ),
                _NavItem(
                  index: 3,
                  label: '마이페이지',
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  shell: navigationShell,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: navigationShell.currentIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: DiaryColors.folderYellow,
              foregroundColor: DiaryColors.ink,
              onPressed: () => context.push('/share'),
              label: const Text('공유 담기'),
              icon: const Icon(Icons.add_link),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.shell,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final active = shell.currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => shell.goBranch(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              color: active
                  ? DiaryColors.ink
                  : DiaryColors.ink.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: DiaryTheme.body(
                11,
                weight: active ? FontWeight.w700 : FontWeight.w400,
                color: active
                    ? DiaryColors.ink
                    : DiaryColors.ink.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
