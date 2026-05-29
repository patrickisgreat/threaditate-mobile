import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:threaditate/app/env.dart';
import 'package:threaditate/services/supabase_client_provider.dart';

/// Thin façade over the Supabase auth API. Keeps Supabase types out of the
/// presentation layer so providers and widgets depend on a single interface.
abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? currentUser();

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signUpWithPassword({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset({required String email});

  Future<void> signOut();
}

/// Plain DTO surfaced to the UI. Decouples widgets from the Supabase [User]
/// type — easier to fake in tests and easier to swap if the backend changes.
class AuthUser {
  const AuthUser({required this.id, required this.email, this.isGuest = false});

  static const guest = AuthUser(id: 'guest', email: null, isGuest: true);

  final String id;
  final String? email;
  final bool isGuest;
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      return user == null ? null : _toAuthUser(user);
    });
  }

  @override
  AuthUser? currentUser() {
    final user = _client.auth.currentUser;
    return user == null ? null : _toAuthUser(user);
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AuthUser _toAuthUser(User user) => AuthUser(id: user.id, email: user.email);
}

/// Auth-disabled mode (mirrors `AUTH_ENABLED=false` on the web app). All
/// calls are no-ops; the "user" is always [AuthUser.guest].
class GuestAuthRepository implements AuthRepository {
  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield AuthUser.guest;
  }

  @override
  AuthUser? currentUser() => AuthUser.guest;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUpWithPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<void> signOut() async {}
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!Env.authEnabled) {
    return GuestAuthRepository();
  }
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});
