import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:threaditate/features/auth/data/auth_repository.dart';

/// Stream of the current auth user. Null = signed out (auth enabled), or
/// [AuthUser.guest] when AUTH_ENABLED=false.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

/// Drives the sign-in / sign-up / reset / sign-out form actions. UI listens
/// to [state] for loading + error rendering; methods rethrow on failure so
/// callers can branch (e.g. show a success banner only on the happy path).
class AuthActionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signIn({required String email, required String password}) =>
      _run(() => _repo.signInWithPassword(email: email, password: password));

  Future<void> signUp({required String email, required String password}) =>
      _run(() => _repo.signUpWithPassword(email: email, password: password));

  Future<void> sendPasswordReset({required String email}) =>
      _run(() => _repo.sendPasswordReset(email: email));

  Future<void> signOut() => _run(_repo.signOut);

  Future<void> _run(Future<void> Function() op) async {
    state = const AsyncValue<void>.loading();
    try {
      await op();
      state = const AsyncValue<void>.data(null);
    } catch (e, st) {
      state = AsyncValue<void>.error(e, st);
      rethrow;
    }
  }
}

final authActionControllerProvider =
    AsyncNotifierProvider<AuthActionController, void>(
      AuthActionController.new,
    );
