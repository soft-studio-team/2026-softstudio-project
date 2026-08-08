import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/diary_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final handleCtrl = TextEditingController();
  bool loading = false;
  bool isRegister = false;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    nameCtrl.dispose();
    handleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    final store = context.read<AppStore>();
    try {
      if (isRegister) {
        await store.register(
          email: emailCtrl.text,
          password: passwordCtrl.text,
          name: nameCtrl.text,
          handle: handleCtrl.text,
        );
      } else {
        await store.login(
          email: emailCtrl.text,
          password: passwordCtrl.text,
        );
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
      case 'email-already-in-use':
        return '이미 가입된 이메일이에요. 로그인으로 전환해 보세요.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않아요.';
      case 'weak-password':
        return '비밀번호가 너무 짧아요 (6자 이상).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 맞지 않아요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해 주세요.';
      default:
        return e.message ?? '인증에 실패했어요 (${e.code})';
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
                      Text('Wish List', style: DiaryTheme.display(42)),
                      const SizedBox(height: 4),
                      Container(
                        height: 6,
                        width: 90,
                        decoration: BoxDecoration(
                          color: DiaryColors.folderBlue,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isRegister
                            ? '계정을 만들고 나만의 위시리스트를 시작해요'
                            : '계정으로 로그인하고 위시리스트를 이어가요',
                        style: DiaryTheme.body(13, color: DiaryColors.inkMuted),
                      ),
                      if (!store.firebaseReady) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: DiaryColors.folderYellow.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            store.firebaseError ??
                                'Firebase 앱 등록이 필요해요. 프로젝트 루트의 FIREBASE_SETUP.md 를 확인하세요.',
                            style: DiaryTheme.body(12),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (isRegister) ...[
                        TextField(
                          controller: nameCtrl,
                          decoration: _input('이름'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: handleCtrl,
                          decoration: _input('핸들 (@없이 입력 가능)'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _input('이메일'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: _input('비밀번호'),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          error!,
                          style: DiaryTheme.body(12, color: DiaryColors.pin),
                        ),
                      ],
                      const SizedBox(height: 20),
                      DiaryButton(
                        label: loading
                            ? (isRegister ? '가입 중...' : '로그인 중...')
                            : (isRegister ? '회원가입' : '로그인'),
                        filled: true,
                        color: DiaryColors.folderBlue,
                        onPressed: loading || !store.firebaseReady
                            ? () {}
                            : _submit,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => setState(() {
                                  isRegister = !isRegister;
                                  error = null;
                                }),
                        child: Text(
                          isRegister
                              ? '이미 계정이 있나요? 로그인'
                              : '계정이 없나요? 회원가입',
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
