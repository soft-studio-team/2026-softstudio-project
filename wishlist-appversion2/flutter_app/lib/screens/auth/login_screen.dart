import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../services/app_error.dart';
import '../../theme/diary_theme.dart';
import '../../widgets/app_status_view.dart';
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
    } catch (e) {
      setState(() => error = userFacingMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
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
                      Text('wishkit', style: DiaryTheme.display(42)),
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
                            ? '이메일 인증 후 계정이 만들어져요'
                            : '계정으로 로그인하고 위시리스트를 이어가요',
                        style: DiaryTheme.body(13, color: DiaryColors.inkMuted),
                      ),
                      if (!store.firebaseReady) ...[
                        const SizedBox(height: 14),
                        AppErrorBanner(
                          message: store.firebaseError ??
                              'Firebase 앱 등록이 필요해요. 프로젝트 루트의 FIREBASE_SETUP.md 를 확인하세요.',
                        ),
                      ] else if (store.sessionError != null) ...[
                        const SizedBox(height: 14),
                        AppErrorBanner(
                          message: store.sessionError!,
                          onRetry: () => runAppAction(context, store.retrySession),
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
                          decoration: _input('아이디 (@없이 입력 가능)'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _input('이메일'),
                      ),
                      const SizedBox(height: 12),
                      PasswordTextField(
                        controller: passwordCtrl,
                        decoration: _input('비밀번호'),
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
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
                      if (!isRegister) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: loading
                                ? null
                                : () => context.push('/account-recovery'),
                            child: Text(
                              '이메일 / 비밀번호 찾기',
                              style: DiaryTheme.body(
                                12,
                                color: DiaryColors.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
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
