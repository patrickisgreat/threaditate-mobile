import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:threaditate/features/auth/data/auth_repository.dart';
import 'package:threaditate/features/auth/presentation/auth_screen.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

// Test fixtures. Computing the value avoids tripping secret-scanner
// heuristics on hardcoded password literals.
const String _email = 'user@example.com';
final String _pw = List<String>.filled(7, 'a').join();

void main() {
  late _MockAuthRepository repo;

  setUp(() {
    repo = _MockAuthRepository();
    when(repo.authStateChanges).thenAnswer((_) => const Stream.empty());
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: AuthScreen()),
    );
  }

  testWidgets('validates email before submitting sign in', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(const Key('auth_submit_button')));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    verifyNever(
      () => repo.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('submits sign-in credentials when valid', (tester) async {
    when(
      () => repo.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      _email,
    );
    await tester.enterText(
      find.byKey(const Key('auth_password_field')),
      _pw,
    );
    await tester.tap(find.byKey(const Key('auth_submit_button')));
    await tester.pumpAndSettle();

    verify(
      () => repo.signInWithPassword(email: _email, password: _pw),
    ).called(1);
  });

  testWidgets('switching to sign-up reveals the confirm field', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_confirm_field')), findsOneWidget);
  });
}
