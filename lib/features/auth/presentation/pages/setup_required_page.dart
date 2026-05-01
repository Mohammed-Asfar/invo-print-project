import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../bloc/auth_bloc.dart';

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key});

  static const routePath = '/setup-required';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final message = state is AuthSetupRequired
        ? state.message
        : 'Your account exists, but setup is not completed.';

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.settings_suggest_outlined,
                  color: AppColors.warning,
                  size: 44,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Setup Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<AuthBloc>().add(const AuthSignOutRequested());
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
