import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:threaditate/features/auth/data/auth_controller.dart';
import 'package:threaditate/features/auth/data/auth_repository.dart';
import 'package:threaditate/features/auth/presentation/auth_screen.dart';
import 'package:threaditate/features/projects/presentation/projects_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const auth = '/auth';
  static const projects = '/projects';
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return AppRoutes.splash;

      final user = switch (auth) {
        AsyncData<AuthUser?>(value: final v) => v,
        _ => null,
      };
      final signedIn = user != null;
      final loc = state.matchedLocation;

      if (!signedIn && loc != AppRoutes.auth) return AppRoutes.auth;
      if (signedIn && (loc == AppRoutes.auth || loc == AppRoutes.splash)) {
        return AppRoutes.projects;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.projects,
        builder: (context, state) => const ProjectsScreen(),
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Bridges Riverpod's auth stream into `GoRouter.refreshListenable` so the
/// router re-evaluates redirects when the user signs in or out.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<AuthUser?>>(
      authStateProvider,
      (previous, next) => notifyListeners(),
    );
  }
}
