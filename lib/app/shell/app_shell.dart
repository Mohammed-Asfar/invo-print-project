import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/company/presentation/pages/company_settings_page.dart';
import '../../features/customers/presentation/pages/customers_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/invoices/presentation/pages/invoices_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_cubit.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeCubit>();
    final authState = context.watch<AuthBloc>().state;
    final businessName = authState is AuthAuthenticated
        ? authState.session.user.displayName
        : 'InvoPrint';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _SideNavigation(),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: businessName.isEmpty ? 'InvoPrint' : businessName,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              context.read<AuthBloc>().add(const AuthSignOutRequested());
            },
            icon: const Icon(Icons.logout),
            label: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: AppColors.shellDark,
        border: Border(right: BorderSide(color: AppColors.shellBorder)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Brand(),
              const SizedBox(height: AppSpacing.xxl),
              const _NavGroupLabel('Menu'),
              _NavItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                routePath: DashboardPage.routePath,
                selected: location == DashboardPage.routePath,
              ),
              const _NavGroupLabel('Create'),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                routePath: InvoicesPage.routePath,
                selected: location.startsWith(InvoicesPage.routePath),
              ),
              _NavItem(
                icon: Icons.request_quote_outlined,
                label: 'Quotations',
                selected: false,
              ),
              _NavItem(
                icon: Icons.groups_outlined,
                label: 'Customers',
                routePath: CustomersPage.routePath,
                selected: location == CustomersPage.routePath,
              ),
              _NavItem(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                routePath: ProductsPage.routePath,
                selected: location == ProductsPage.routePath,
              ),
              const _NavGroupLabel('Manage'),
              _NavItem(
                icon: Icons.stars_outlined,
                label: 'Loyalty',
                selected: false,
              ),
              _NavItem(
                icon: Icons.description_outlined,
                label: 'Templates',
                selected: false,
              ),
              const Spacer(),
              const _NavGroupLabel('Other'),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Company Settings',
                routePath: CompanySettingsPage.routePath,
                selected: location == CompanySettingsPage.routePath,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryPurple, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt_long, color: AppColors.onAccent),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'InvoPrint',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.shellText,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _NavGroupLabel extends StatelessWidget {
  const _NavGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.shellTextMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.routePath,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final String? routePath;

  @override
  Widget build(BuildContext context) {
    final enabled = routePath != null;
    final color = selected
        ? AppColors.shellText
        : enabled
        ? AppColors.shellText
        : AppColors.shellTextMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? AppColors.primaryPurple : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? () => context.go(routePath!) : null,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
