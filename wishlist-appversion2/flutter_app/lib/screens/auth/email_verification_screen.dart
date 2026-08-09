import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool busy = false;
  String? message;
  String? error;

  Future<void> _resend() async {
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await context.read<AppStore>().resendVerificationEmail();
      if (!mounted) return;
      setState(() => message = '인증 메일을 다시 보냈어요. 메일함을 확인해 주세요.');
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _check() async {
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      final ok = await context.read<AppStore>().confirmEmailVerified();
      if (!mounted) return;
      if (!ok) {
        setState(() => error = '아직 인증이 완료되지 않았어요. 메일 속 링크를 눌러 주세요.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => busy = true);
    try {
      await context.read<AppStore>().cancelEmailVerification();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final email = store.pendingVerificationEmail ?? '이메일';

    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DiaryGridPaper(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('wishkit', style: DiaryTheme.display(36)),
                    const SizedBox(height: 8),
                    Text(
                      '이메일 인증',
                      style: DiaryTheme.body(18, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$email 으로 인증 메일을 보냈어요.\n메일 속 링크를 누른 뒤, 아래 버튼을 눌러 주세요.',
                      style: DiaryTheme.body(13, color: DiaryColors.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '메일이 보이지 않으면 스팸함을 확인해 주세요.',
                      style: DiaryTheme.body(12, color: DiaryColors.inkSoft),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(message!, style: DiaryTheme.body(12)),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: DiaryTheme.body(12, color: DiaryColors.pin),
                      ),
                    ],
                    const SizedBox(height: 24),
                    DiaryButton(
                      label: busy ? '확인 중...' : '인증 완료했어요',
                      filled: true,
                      color: DiaryColors.folderBlue,
                      onPressed: busy ? null : _check,
                    ),
                    const SizedBox(height: 10),
                    DiaryButton(
                      label: '인증 메일 다시 보내기',
                      filled: false,
                      color: DiaryColors.folderBlue,
                      onPressed: busy ? null : _resend,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy ? null : _cancel,
                      child: Text(
                        '다른 이메일로 돌아가기',
                        style: DiaryTheme.body(12, color: DiaryColors.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
