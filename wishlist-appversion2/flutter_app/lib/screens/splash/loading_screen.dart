import 'package:flutter/material.dart';

import '../../theme/diary_theme.dart';

/// 앱 시작 시 로그인 상태 확인(AppStore.init — Firebase Auth reload +
/// Firestore 세션 하이드레이션)이 끝나기 전까지 잠깐 보여주는 화면.
///
/// main()이 더 이상 AppStore.init()을 기다리지 않고 바로 runApp 하기 때문에,
/// 그 사이 첫 화면 자리를 채우는 용도다. store.ready가 true가 되면
/// GoRouter의 redirect가 알아서 원래 목적지(로그인/홈)로 넘겨준다.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: DiaryColors.canvas,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
