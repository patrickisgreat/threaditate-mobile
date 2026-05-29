import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:threaditate/features/auth/data/auth_controller.dart';

enum AuthMode { signIn, signUp, reset }

/// Single-screen auth surface with a mode toggle (sign in / sign up / reset).
/// Mirrors `src/components/Auth/AuthForm.tsx` in the web repo.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _successMessage = null);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final controller = ref.read(authActionControllerProvider.notifier);

    try {
      switch (_mode) {
        case AuthMode.signIn:
          await controller.signIn(email: email, password: password);
        case AuthMode.signUp:
          await controller.signUp(email: email, password: password);
          if (mounted) {
            setState(
              () =>
                  _successMessage = 'Check your email for a confirmation link.',
            );
          }
        case AuthMode.reset:
          await controller.sendPasswordReset(email: email);
          if (mounted) {
            setState(
              () => _successMessage =
                  'Check your email for a password reset link.',
            );
          }
      }
    } on Object {
      // Errors surface via the controller's AsyncValue; the banner renders them.
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!v.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (_mode == AuthMode.reset) return null;
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Must be at least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (_mode != AuthMode.signUp) return null;
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authActionControllerProvider);
    final isBusy = state.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _titleForMode(_mode),
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('auth_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enabled: !isBusy,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    if (_mode != AuthMode.reset) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('auth_password_field'),
                        controller: _passwordController,
                        obscureText: true,
                        enabled: !isBusy,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validatePassword,
                      ),
                    ],
                    if (_mode == AuthMode.signUp) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('auth_confirm_field'),
                        controller: _confirmController,
                        obscureText: true,
                        enabled: !isBusy,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateConfirm,
                      ),
                    ],
                    if (state.hasError) ...[
                      const SizedBox(height: 16),
                      _Banner(
                        text: state.error?.toString() ?? 'Something went wrong',
                        color: Theme.of(context).colorScheme.errorContainer,
                        textColor: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer,
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 16),
                      _Banner(
                        text: _successMessage!,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        textColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('auth_submit_button'),
                      onPressed: isBusy ? null : _submit,
                      child: isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_ctaForMode(_mode)),
                    ),
                    const SizedBox(height: 16),
                    _ModeSwitcher(
                      current: _mode,
                      onChange: (next) => setState(() {
                        _mode = next;
                        _successMessage = null;
                        _formKey.currentState?.reset();
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _titleForMode(AuthMode mode) => switch (mode) {
  AuthMode.signIn => 'Welcome back',
  AuthMode.signUp => 'Create your account',
  AuthMode.reset => 'Reset your password',
};

String _ctaForMode(AuthMode mode) => switch (mode) {
  AuthMode.signIn => 'Sign in',
  AuthMode.signUp => 'Create account',
  AuthMode.reset => 'Send reset link',
};

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: textColor)),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.current, required this.onChange});

  final AuthMode current;
  final ValueChanged<AuthMode> onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        if (current != AuthMode.signIn)
          TextButton(
            onPressed: () => onChange(AuthMode.signIn),
            child: const Text('Sign in'),
          ),
        if (current != AuthMode.signUp)
          TextButton(
            onPressed: () => onChange(AuthMode.signUp),
            child: const Text('Create account'),
          ),
        if (current != AuthMode.reset)
          TextButton(
            onPressed: () => onChange(AuthMode.reset),
            child: const Text('Forgot password?'),
          ),
      ],
    );
  }
}
