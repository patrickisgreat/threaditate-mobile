import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:threaditate/app/env.dart';
import 'package:threaditate/features/projects/domain/project.dart';
import 'package:threaditate/services/supabase_client_provider.dart';

/// CRUD for [Project] rows. Mirrors `src/services/project.service.ts` in the
/// web app. Authorization is enforced server-side via Supabase RLS — don't
/// duplicate ACL checks here.
// ignore: one_member_abstracts
abstract class ProjectRepository {
  Future<List<Project>> listProjects();
}

class SupabaseProjectRepository implements ProjectRepository {
  SupabaseProjectRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Project>> listProjects() async {
    final rows = await _client
        .from('projects')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Project.fromJson)
        .toList(growable: false);
  }
}

/// Stand-in used when AUTH_ENABLED=false / no Supabase credentials. Returns
/// an empty list so the projects screen renders its empty state cleanly.
class GuestProjectRepository implements ProjectRepository {
  @override
  Future<List<Project>> listProjects() async => const [];
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  if (!Env.authEnabled || !Env.hasSupabaseCredentials) {
    return GuestProjectRepository();
  }
  return SupabaseProjectRepository(ref.watch(supabaseClientProvider));
});

final projectListProvider = FutureProvider<List<Project>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.listProjects();
});
