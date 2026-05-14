import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed accessors for the .env config. Mirrors the web app's env contract.
class Env {
  Env._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Mirrors `NEXT_PUBLIC_AUTH_ENABLED` on the web app. When false, the app
  /// boots into an anonymous-guest mode without requiring Supabase auth.
  static bool get authEnabled =>
      (dotenv.env['AUTH_ENABLED'] ?? 'true').toLowerCase() == 'true';

  static bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('example.supabase.co');
}
