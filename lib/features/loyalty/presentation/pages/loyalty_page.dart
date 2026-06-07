import 'package:flutter/material.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../company/data/repositories/company_settings_repository.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../invoices/data/repositories/invoice_repository.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../domain/services/loyalty_report.dart';

class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({super.key});

  static const routePath = '/loyalty';

  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends State<LoyaltyPage> {
  final _customerRepository = sl<CustomerRepository>();
  final _invoiceRepository = sl<InvoiceRepository>();
  final _settingsRepository = sl<CompanySettingsRepository>();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _message;
  AppSettings _settings = AppSettings.initial();
  LoyaltyReport _report = buildLoyaltyReport(
    customers: const [],
    invoices: const [],
    pointValue: AppSettings.initial().pointsRedemptionValue,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final results = await Future.wait<Object>([
        _customerRepository.fetchCustomers(),
        _invoiceRepository.fetchInvoices(),
        _settingsRepository.fetchAppSettings(),
      ]);
      final customers = results[0] as List<Customer>;
      final invoices = results[1] as List<Invoice>;
      final settings = results[2] as AppSettings;
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _report = buildLoyaltyReport(
          customers: customers,
          invoices: invoices,
          pointValue: settings.pointsRedemptionValue,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Could not load loyalty data. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(isBusy: _isLoading, onRefresh: _load),
            const SizedBox(height: AppSpacing.lg),
            if (_message != null) ...[
              _InlineMessage(message: _message!, isError: true),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (!_settings.loyaltyEnabled) ...[
              const _InlineMessage(
                message:
                    'Loyalty is disabled in Company Settings. Existing balances are shown for reference.',
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListenableBuilder(
                  listenable: _searchController,
                  builder: (context, _) {
                    final customers = filterLoyaltyCustomers(
                      _report.customers,
                      _searchController.text,
                    );
                    return _LoyaltyContent(
                      report: _report,
                      customers: customers,
                      settings: _settings,
                      searchController: _searchController,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isBusy, required this.onRefresh});

  final bool isBusy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.stars_outlined, color: AppColors.primaryPurple),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loyalty',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Track customer point balances, earned points, and redeemable value.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onRefresh,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyContent extends StatelessWidget {
  const _LoyaltyContent({
    required this.report,
    required this.customers,
    required this.settings,
    required this.searchController,
  });

  final LoyaltyReport report;
  final List<LoyaltyCustomerRow> customers;
  final AppSettings settings;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryGrid(report: report, settings: settings),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _CustomerPointsPanel(
                  customers: customers,
                  searchController: searchController,
                  currencySymbol: settings.currencySymbol,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: _RecentAwardsPanel(
                  awards: report.recentAwards,
                  currencySymbol: settings.currencySymbol,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report, required this.settings});

  final LoyaltyReport report;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 900 ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          shrinkWrap: true,
          childAspectRatio: constraints.maxWidth < 900 ? 2.8 : 3.4,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricCard(
              icon: Icons.groups_outlined,
              label: 'Active Members',
              value: '${report.activeMembers}/${report.totalCustomers}',
            ),
            _MetricCard(
              icon: Icons.stars_outlined,
              label: 'Points Outstanding',
              value: report.pointsOutstanding.toString(),
            ),
            _MetricCard(
              icon: Icons.currency_rupee_outlined,
              label: 'Redeemable Value',
              value:
                  '${settings.currencySymbol} ${report.outstandingValue.toStringAsFixed(2)}',
            ),
            _MetricCard(
              icon: Icons.history_outlined,
              label: 'Earned / Redeemed',
              value:
                  '${report.lifetimePointsEarned} / ${report.lifetimePointsRedeemed}',
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 26),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerPointsPanel extends StatelessWidget {
  const _CustomerPointsPanel({
    required this.customers,
    required this.searchController,
    required this.currencySymbol,
  });

  final List<LoyaltyCustomerRow> customers;
  final TextEditingController searchController;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Customer Balances',
      subtitle: 'Highest point balances first.',
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search customers',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: customers.isEmpty
                ? const _EmptyState(message: 'No loyalty customers found.')
                : ListView.separated(
                    itemCount: customers.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final row = customers[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: row.customer.loyaltyEnabled
                              ? AppColors.primaryLight
                              : AppColors.surfaceSoft,
                          child: Icon(
                            row.customer.loyaltyEnabled
                                ? Icons.stars_outlined
                                : Icons.block_outlined,
                            color: row.customer.loyaltyEnabled
                                ? AppColors.primaryPurple
                                : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          row.customer.name.isEmpty
                              ? 'Unnamed customer'
                              : row.customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          [
                            if (row.customer.phone.isNotEmpty)
                              row.customer.phone,
                            '$currencySymbol ${row.redeemableValue.toStringAsFixed(2)} redeemable',
                          ].join('  |  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              row.pointsBalance.toString(),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'pts',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecentAwardsPanel extends StatelessWidget {
  const _RecentAwardsPanel({
    required this.awards,
    required this.currencySymbol,
  });

  final List<LoyaltyAwardRow> awards;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent Point Awards',
      subtitle: 'Invoices that awarded loyalty points.',
      child: awards.isEmpty
          ? const _EmptyState(message: 'No awarded points yet.')
          : ListView.separated(
              itemCount: awards.length,
              separatorBuilder: (_, _) =>
                  Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, index) {
                final award = awards[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primaryPurple,
                  ),
                  title: Text(
                    award.invoice.invoiceNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${award.customerName}  |  ${_formatDate(award.invoice.invoiceDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${award.pointsEarned}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '$currencySymbol ${award.invoice.grandTotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.error.withValues(alpha: 0.14)
            : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isError ? AppColors.error : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: isError ? AppColors.error : AppColors.primaryPurple,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
