import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

String friendlyError(
  Object error, {
  String fallback = 'Kuch galat ho gaya. Phir koshish karo.',
}) {
  debugPrint('User-facing error: $error');

  if (error is FirebaseException) {
    switch (error.code) {
      case 'network-request-failed':
      case 'unavailable':
      case 'deadline-exceeded':
      case 'cancelled':
        return _networkMessage;
      case 'permission-denied':
      case 'unauthenticated':
        return 'Is data ka access nahi hai. Dobara login karke dekho.';
      case 'too-many-requests':
        return 'Bahut zyada koshish ho gayi. Thodi der baad phir try karo.';
      case 'user-disabled':
        return 'Ye account band hai. Doosre account se login karo.';
      case 'account-exists-with-different-credential':
        return 'Is email se pehle se account hai. Usi tarike se login karo.';
    }
  }

  final text = error.toString().toLowerCase();
  if (text.contains('network') ||
      text.contains('offline') ||
      text.contains('unavailable') ||
      text.contains('timeout') ||
      text.contains('socket') ||
      text.contains('connection')) {
    return _networkMessage;
  }
  if (text.contains('permission') || text.contains('unauthorized')) {
    return 'Is data ka access nahi hai. Dobara login karke dekho.';
  }
  if (text.contains('notification') && text.contains('permission')) {
    return 'Notification aur alarm permission chahiye. Phone settings me on karo.';
  }
  if (text.contains('pdf')) {
    return 'PDF banane me dikkat aayi. Phir koshish karo.';
  }
  return fallback;
}

const String _networkMessage =
    'Internet nahi chal raha. Phone ka data check karo, phir koshish karo.';
