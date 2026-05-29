import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:threaditate/app/env.dart';

/// The Supabase client is initialized once during app startup. This provider
/// just hands back the singleton so feature code reads it via Riverpod
/// instead of touching `Supabase.instance.client` directly.
///
/// Throws if [initializeSupabase] hasn't been awaited in `main.dart` yet.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Initialize the Supabase SDK. Called from main.dart before runApp.
/// Returns true when real credentials are loaded; false when running in the
/// AUTH_ENABLED=false (or unconfigured) developer mode and we skipped init.
Future<bool> initializeSupabase() async {
  if (!Env.hasSupabaseCredentials) {
    return false;
  }
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  return true;
}
