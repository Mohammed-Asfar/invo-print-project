import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin_setup/presentation/pages/admin_setup_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/setup_required_page.dart';
import '../../features/company/presentation/pages/company_settings_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../shell/app_shell.dart';

GoRouter createAppRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: LoginPage.routePath,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == LoginPage.routePath;
      final isSetupRequired =
          state.matchedLocation == SetupRequiredPage.routePath;
      final isAdminSetup = state.matchedLocation == AdminSetupPage.routePath;
      final authState = authBloc.state;
      final isAuthenticated = authState is AuthAuthenticated;
      final isAdmin = authState is AuthAdminAuthenticated;
      final needsSetup = authState is AuthSetupRequired;

      if (needsSetup && !isSetupRequired) {
        return SetupRequiredPage.routePath;
      }

      if (isAdmin && !isAdminSetup) {
        return AdminSetupPage.routePath;
      }

      if (!isAuthenticated && !isAdmin && !needsSetup && !isLoggingIn) {
        return LoginPage.routePath;
      }

      if (isAuthenticated && isLoggingIn) {
        return DashboardPage.routePath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: LoginPage.routePath,
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: DashboardPage.routePath,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: CompanySettingsPage.routePath,
            builder: (context, state) => const CompanySettingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: SetupRequiredPage.routePath,
        builder: (context, state) => const SetupRequiredPage(),
      ),
      GoRoute(
        path: AdminSetupPage.routePath,
        builder: (context, state) => const AdminSetupPage(),
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
