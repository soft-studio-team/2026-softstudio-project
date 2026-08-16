import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kNetworkMessage = '네트워크 연결을 확인해 주세요.';
const kGenericMessage = '잠시 문제가 생겼어요. 다시 시도해 주세요.';
const kTooManyRequestsMessage = '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.';
const kSessionExpiredMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';
const kSaveFailedMessage = '저장하지 못했어요. 잠시 후 다시 시도해 주세요.';
const kListLoadFailedMessage = '목록을 불러오지 못했어요.';
const kPhotoPermissionMessage = '사진 접근을 허용해야 리뷰에 넣을 수 있어요.';

/// Maps raw exceptions to a short Korean sentence the user can act on.
/// Never returns stack traces, SDK codes, or `Exception: ...` prefixes.
String userFacingMessage(Object error, {String? fallback}) {
  if (error is FirebaseAuthException) {
    return _authMessage(error);
  }
  if (error is FirebaseException) {
    if (_looksLikeNetwork(error.message ?? error.code)) {
      return kNetworkMessage;
    }
    return fallback ?? _firebaseMessage(error);
  }
  if (error is PlatformException && _looksLikePhotoPermission(error.code, error.message)) {
    return fallback ?? kPhotoPermissionMessage;
  }

  final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  if (_looksLikeNetwork(raw)) {
    return kNetworkMessage;
  }
  if (_looksLikeSession(raw)) {
    return kSessionExpiredMessage;
  }
  if (_looksLikePhotoPermission('', raw)) {
    return fallback ?? kPhotoPermissionMessage;
  }
  if (_looksLikeUserMessage(raw)) {
    return raw;
  }
  return fallback ?? kGenericMessage;
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
      return kNetworkMessage;
    case 'too-many-requests':
      return kTooManyRequestsMessage;
    case 'requires-recent-login':
      return kSessionExpiredMessage;
    default:
      return kGenericMessage;
  }
}

String _firebaseMessage(FirebaseException e) {
  switch (e.code) {
    case 'unavailable':
    case 'network-request-failed':
      return kNetworkMessage;
    case 'not-found':
      return '찾을 수 없어요.';
    case 'already-exists':
      return '이미 있는 정보예요.';
    default:
      return kGenericMessage;
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

bool _looksLikeSession(String text) {
  return text.contains('로그인 세션') || text.contains('로그인된 계정');
}

bool _looksLikePhotoPermission(String code, String? message) {
  final blob = '${code.toLowerCase()} ${message?.toLowerCase() ?? ''}';
  return blob.contains('photo_access_denied') ||
      blob.contains('camera_access_denied') ||
      blob.contains('photos permission') ||
      blob.contains('camera permission') ||
      ((blob.contains('permission') || blob.contains('denied')) &&
          (blob.contains('photo') || blob.contains('camera') || blob.contains('gallery')));
}

bool _looksLikeUserMessage(String text) {
  return !text.contains('Exception') &&
      !text.contains('Firebase') &&
      !text.contains('Null check') &&
      !text.contains('\n') &&
      text.length <= 80;
}

void showAppError(BuildContext context, Object error, {String? fallback}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(userFacingMessage(error, fallback: fallback))),
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
  String? fallback,
}) async {
  try {
    await action();
    if (success != null && context.mounted) {
      showAppMessage(context, success);
    }
  } catch (e) {
    if (context.mounted) showAppError(context, e, fallback: fallback);
  }
}
