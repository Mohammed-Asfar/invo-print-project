import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../company/data/repositories/company_settings_repository.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../company/presentation/pages/company_settings_page.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/presentation/pages/customers_page.dart';
import '../../../invoices/data/repositories/invoice_repository.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/presentation/pages/create_invoice_page.dart';
import '../../../invoices/presentation/pages/invoices_page.dart';
import '../../../loyalty/presentation/pages/loyalty_page.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../products/data/repositories/purchase_entry_repository.dart';
import '../../../products/domain/entities/product_service.dart';
import '../../../products/domain/entities/purchase_entry.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../../../quotations/data/repositories/quotation_repository.dart';
import '../../../quotations/domain/entities/quotation.dart';
import '../../../quotations/presentation/pages/quotations_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../domain/services/dashboard_report.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  static const routePath = '/dashboard';

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _invoiceRepository = sl<InvoiceRepository>();
  final _quotationRepository = sl<QuotationRepository>();
  final _customerRepository = sl<CustomerRepository>();
  final _productRepository = sl<ProductRepository>();
  final _purchaseRepository = sl<PurchaseEntryRepository>();
  final _settingsRepository = sl<CompanySettingsRepository>();

  bool _isLoading = true;
  String? _message;
  AppSettings _settings = AppSettings.initial();
  DashboardReport _report = buildDashboardReport(
    invoices: const [],
    quotations: const [],
    customers: const [],
    products: const [],
    purchaseEntries: const [],
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final results = await Future.wait<Object>([
        _invoiceRepository.fetchInvoices(),
        _quotationRepository.fetchQuotations(),
        _customerRepository.fetchCustomers(),
        _productRepository.fetchProducts(),
        _purchaseRepository.fetchPurchaseEntries(),
        _settingsRepository.fetchAppSettings(),
      ]);
      if (!mounted) return;
      setState(() {
        _report = buildDashboardReport(
          invoices: results[0] as List<Invoice>,
          quotations: results[1] as List<Quotation>,
          customers: results[2] as List<Customer>,
          products: results[3] as List<ProductService>,
          purchaseEntries: results[4] as List<PurchaseEntry>,
        );
        _settings = results[5] as AppSettings;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Could not load dashboard. Please try again.';
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
              _InlineMessage(message: _message!),
              const SizedBox(height: AppSpacing.lg),
            ],
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _DashboardContent(report: _report, settings: _settings),
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
            child: Icon(
              Icons.dashboard_outlined,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Live sales, payments, quotations, stock, and customer signals.',
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
          const SizedBox(width: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: () => context.go(CreateInvoicePage.routePath),
            icon: const Icon(Icons.add),
            label: const Text('New Invoice'),
          ),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.report, required this.settings});

  final DashboardReport report;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _MetricGrid(report: report, settings: settings),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _AttentionPanel(items: report.attentionItems),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 2, child: _QuickActionsPanel(settings: settings)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RecentInvoicesPanel(
                  invoices: report.recentInvoices,
                  currencySymbol: settings.currencySymbol,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _BusinessSnapshot(report: report, settings: settings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.report, required this.settings});

  final DashboardReport report;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 1100 ? 3 : 6;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          shrinkWrap: true,
          childAspectRatio: constraints.maxWidth < 1100 ? 2.6 : 2.15,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricCard(
              icon: Icons.receipt_long_outlined,
              label: 'Invoiced',
              value: _money(report.totalInvoiced, settings.currencySymbol),
            ),
            _MetricCard(
              icon: Icons.payments_outlined,
              label: 'Paid',
              value: _money(report.totalPaid, settings.currencySymbol),
              valueColor: AppColors.success,
            ),
            _MetricCard(
              icon: Icons.pending_actions_outlined,
              label: 'Outstanding',
              value: _money(report.outstandingAmount, settings.currencySymbol),
              valueColor: report.outstandingAmount > 0
                  ? AppColors.warning
                  : null,
            ),
            _MetricCard(
              icon: Icons.warning_amber_outlined,
              label: 'Overdue',
              value: report.overdueInvoiceCount.toString(),
              valueColor: report.overdueInvoiceCount > 0
                  ? AppColors.error
                  : null,
            ),
            _MetricCard(
              icon: Icons.request_quote_outlined,
              label: 'Pending Quotes',
              value: report.pendingQuotationCount.toString(),
            ),
            _MetricCard(
              icon: Icons.inventory_2_outlined,
              label: 'Low Stock',
              value: report.lowStockCount.toString(),
              valueColor: report.lowStockCount > 0 ? AppColors.warning : null,
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
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 22),
          const SizedBox(height: AppSpacing.sm),
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
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.items});

  final List<DashboardAttentionItem> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Needs Attention',
      subtitle: 'Overdue, low stock, and pending work.',
      child: items.isEmpty
          ? const _EmptyState(message: 'Nothing urgent right now.')
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final color = switch (item.severity) {
                  DashboardAttentionSeverity.danger => AppColors.error,
                  DashboardAttentionSeverity.warning => AppColors.warning,
                  DashboardAttentionSeverity.info => AppColors.info,
                };
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined, color: color),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Quick Actions',
      subtitle: 'Jump into common workflows.',
      child: ListView(
        children: [
          _ActionTile(
            icon: Icons.receipt_long_outlined,
            title: 'Invoices',
            subtitle: 'View, edit, export, and record payments',
            routePath: InvoicesPage.routePath,
          ),
          _ActionTile(
            icon: Icons.request_quote_outlined,
            title: 'Quotations',
            subtitle: 'Prepare quotes and convert accepted ones',
            routePath: QuotationsPage.routePath,
          ),
          _ActionTile(
            icon: Icons.groups_outlined,
            title: 'Customers',
            subtitle: 'Profiles, ledger, follow-ups, and terms',
            routePath: CustomersPage.routePath,
          ),
          _ActionTile(
            icon: Icons.inventory_2_outlined,
            title: 'Products & Purchases',
            subtitle: 'Stock, suppliers, purchases, and returns',
            routePath: ProductsPage.routePath,
          ),
          if (settings.loyaltyEnabled)
            _ActionTile(
              icon: Icons.stars_outlined,
              title: 'Loyalty',
              subtitle: 'Customer point balances and awards',
              routePath: LoyaltyPage.routePath,
            ),
          _ActionTile(
            icon: Icons.analytics_outlined,
            title: 'Reports',
            subtitle: 'Sales, payables, and follow-up exports',
            routePath: ReportsPage.routePath,
          ),
          _ActionTile(
            icon: Icons.settings_outlined,
            title: 'Company Settings',
            subtitle: 'Numbering, GST, defaults, and PDF settings',
            routePath: CompanySettingsPage.routePath,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.routePath,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String routePath;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primaryPurple),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(routePath),
    );
  }
}

class _RecentInvoicesPanel extends StatelessWidget {
  const _RecentInvoicesPanel({
    required this.invoices,
    required this.currencySymbol,
  });

  final List<Invoice> invoices;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent Invoices',
      subtitle: 'Latest final invoices.',
      height: 360,
      child: invoices.isEmpty
          ? const _EmptyState(message: 'No invoices yet.')
          : ListView.separated(
              itemCount: invoices.length,
              separatorBuilder: (_, _) =>
                  Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primaryPurple,
                  ),
                  title: Text(
                    invoice.invoiceNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${invoice.customerSnapshot['name'] ?? 'Customer'}  |  ${invoice.status.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _money(invoice.grandTotal, currencySymbol),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                );
              },
            ),
    );
  }
}

class _BusinessSnapshot extends StatelessWidget {
  const _BusinessSnapshot({required this.report, required this.settings});

  final DashboardReport report;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Business Snapshot',
      subtitle: 'Current operating totals.',
      height: 360,
      child: Column(
        children: [
          _SnapshotRow(
            label: 'Customers',
            value: report.customerCount.toString(),
          ),
          _SnapshotRow(
            label: 'Invoices',
            value: report.invoiceCount.toString(),
          ),
          _SnapshotRow(
            label: 'Quotations',
            value: report.quotationCount.toString(),
          ),
          _SnapshotRow(
            label: 'Quote Pipeline',
            value: _money(
              report.pendingQuotationValue,
              settings.currencySymbol,
            ),
          ),
          _SnapshotRow(
            label: 'Supplier Payables',
            value: _money(
              report.purchasePayableAmount,
              settings.currencySymbol,
            ),
            highlight: report.purchasePayableAmount > 0,
          ),
          _SnapshotRow(
            label: 'Overdue Bills',
            value: report.overduePurchaseCount.toString(),
            highlight: report.overduePurchaseCount > 0,
          ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: highlight ? AppColors.warning : AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.height,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
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
    if (height == null) return SizedBox(height: 420, child: panel);
    return SizedBox(height: height, child: panel);
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error),
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

String _money(double value, String currencySymbol) {
  return '$currencySymbol ${value.toStringAsFixed(2)}';
}
