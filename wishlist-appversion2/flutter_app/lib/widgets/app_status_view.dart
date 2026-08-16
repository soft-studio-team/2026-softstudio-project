import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/diary_theme.dart';
import 'diary_widgets.dart';

/// In-page status for empty / not-found / load-failed.
/// This is not a new destination — it replaces the broken body.
class AppStatusView extends StatelessWidget {
  const AppStatusView({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DiaryGridPaper(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: DiaryTheme.ui(18, weight: FontWeight.w700),
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: DiaryTheme.body(13, color: DiaryColors.inkMuted),
                  ),
                ],
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 18),
                  DiaryButton(
                    label: actionLabel!,
                    filled: true,
                    color: DiaryColors.folderBlue,
                    onPressed: onAction!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppStatusScaffold extends StatelessWidget {
  const AppStatusScaffold({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.showHome = true,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DiaryColors.canvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: AppStatusView(
        title: title,
        message: message,
        actionLabel: actionLabel ?? (showHome ? '홈으로' : null),
        onAction: onAction ?? (showHome ? () => context.go('/') : null),
      ),
    );
  }
}

class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DiaryColors.folderYellow.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(message, style: DiaryTheme.body(12)),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  '다시 시도',
                  style: DiaryTheme.ui(12, weight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
