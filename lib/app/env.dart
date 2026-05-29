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

  /// Real Supabase anon keys are JWTs (~200+ chars); anything shorter is
  /// almost certainly a `.env.example` placeholder, so we treat the app as
  /// unconfigured and skip Supabase init.
  static bool get hasSupabaseCredentials =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.length > 100;
}
