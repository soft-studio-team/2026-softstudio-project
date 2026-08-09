import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

enum _RecoveryMode { password, email }

class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({super.key});

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  final emailCtrl = TextEditingController();
  final handleCtrl = TextEditingController();
  _RecoveryMode mode = _RecoveryMode.password;
  bool loading = false;
  String? message;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    handleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
      message = null;
    });
    final store = context.read<AppStore>();
    try {
      if (mode == _RecoveryMode.password) {
        await store.sendPasswordResetEmail(emailCtrl.text);
        if (!mounted) return;
        setState(() {
          message = '비밀번호 재설정 메일을 보냈어요. 메일함을 확인해 주세요.';
        });
      } else {
        final masked = await store.findMaskedEmailByHandle(handleCtrl.text);
        if (!mounted) return;
        if (masked == null) {
          setState(() => error = '해당 핸들로 가입된 계정을 찾지 못했어요.');
        } else {
          setState(() => message = '가입 이메일: $masked');
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = _mapAuthError(e));
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않아요.';
      case 'user-not-found':
        // Firebase often hides this; keep a gentle message.
        return '해당 이메일로 가입된 계정을 찾지 못했어요.';
      case 'too-many-requests':
        return '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해 주세요.';
      default:
        return e.message ?? '요청에 실패했어요 (${e.code})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('wishkit', style: DiaryTheme.display(36)),
                      const SizedBox(height: 8),
                      Text(
                        '계정 찾기',
                        style: DiaryTheme.body(18, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<_RecoveryMode>(
                        segments: const [
                          ButtonSegment(
                            value: _RecoveryMode.password,
                            label: Text('비밀번호'),
                          ),
                          ButtonSegment(
                            value: _RecoveryMode.email,
                            label: Text('이메일'),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: loading
                            ? null
                            : (value) => setState(() {
                                  mode = value.first;
                                  error = null;
                                  message = null;
                                }),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        mode == _RecoveryMode.password
                            ? '가입한 이메일을 입력하면 재설정 메일을 보내드려요.'
                            : '가입할 때 만든 핸들을 입력하면 이메일을 알려드려요.',
                        style: DiaryTheme.body(13, color: DiaryColors.inkMuted),
                      ),
                      const SizedBox(height: 16),
                      if (mode == _RecoveryMode.password)
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _input('이메일'),
                          onSubmitted: (_) => _submit(),
                        )
                      else
                        TextField(
                          controller: handleCtrl,
                          decoration: _input('핸들 (@없이 입력 가능)'),
                          onSubmitted: (_) => _submit(),
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
                      const SizedBox(height: 20),
                      DiaryButton(
                        label: loading
                            ? '처리 중...'
                            : (mode == _RecoveryMode.password
                                ? '재설정 메일 보내기'
                                : '이메일 찾기'),
                        filled: true,
                        color: DiaryColors.folderBlue,
                        onPressed: loading || !store.firebaseReady
                            ? null
                            : _submit,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: loading ? null : () => context.go('/login'),
                        child: Text(
                          '돌아가기',
                          style: DiaryTheme.body(
                            12,
                            color: DiaryColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: DiaryColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: DiaryColors.ink.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: DiaryColors.ink.withValues(alpha: 0.15)),
      ),
    );
  }
}
