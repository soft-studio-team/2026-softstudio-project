import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Maps raw exceptions to a short Korean sentence the user can act on.
/// Never returns stack traces, SDK codes, or `Exception: ...` prefixes.
String userFacingMessage(Object error) {
  if (error is FirebaseAuthException) {
    return _authMessage(error);
  }
  if (error is FirebaseException) {
    return _firebaseMessage(error);
  }

  final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  if (_looksLikeNetwork(raw)) {
    return '네트워크 연결을 확인해 주세요.';
  }
  if (_looksLikeUserMessage(raw)) {
    return raw;
  }
  return '요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.';
}

String _authMessage(FirebaseAuthException e) {
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
    case 'too-many-requests':
      return '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.';
    case 'requires-recent-login':
      return '보안을 위해 다시 로그인한 뒤 시도해 주세요.';
    default:
      return '인증에 실패했어요. 잠시 후 다시 시도해 주세요.';
  }
}

String _firebaseMessage(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return '권한이 없어 이 작업을 할 수 없어요.';
    case 'unavailable':
    case 'network-request-failed':
      return '네트워크 연결을 확인해 주세요.';
    case 'not-found':
      return '요청한 정보를 찾을 수 없어요.';
    case 'already-exists':
      return '이미 있는 정보예요.';
    default:
      return '요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.';
  }
}

bool _looksLikeNetwork(String text) {
  final lower = text.toLowerCase();
  return lower.contains('socket') ||
      lower.contains('failed host lookup') ||
      lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('timeout') ||
      lower.contains('httpexception');
}

bool _looksLikeUserMessage(String text) {
  return !text.contains('Exception') &&
      !text.contains('Firebase') &&
      !text.contains('Null check') &&
      !text.contains('\n') &&
      text.length <= 80;
}

void showAppError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(userFacingMessage(error))),
  );
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<void> runAppAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) {
      showAppMessage(context, success);
    }
  } catch (e) {
    if (context.mounted) showAppError(context, e);
  }
}
