import 'dart:async';

import 'auth_service.dart';

class MemoryAuthService implements AuthService {
  MemoryAuthService({AuthUser? initialUser}) : _currentUser = initialUser;

  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  Object? signInError;
  Object? signOutError;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<void> signInWithGoogle() async {
    if (signInError != null) throw signInError!;
    _currentUser = const AuthUser(
      id: 'test-user',
      displayName: 'Test User',
      email: 'test@example.com',
    );
    _controller.add(_currentUser);
  }

  @override
  Future<void> signOut() async {
    if (signOutError != null) throw signOutError!;
    _currentUser = null;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
