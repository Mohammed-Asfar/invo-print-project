import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../invoices/data/repositories/invoice_repository.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/services/customer_follow_up.dart';
import '../../../products/domain/entities/purchase_entry.dart';
import '../../../products/domain/entities/product_service.dart';
import '../../../products/domain/entities/supplier.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../products/data/repositories/purchase_entry_repository.dart';
import '../../../products/data/repositories/supplier_repository.dart';
import '../../domain/services/customer_aging_report.dart';
import '../../domain/services/gst_summary_report.dart';
import '../../domain/services/inventory_valuation_report.dart';
import '../../domain/services/profit_margin_report.dart';
import '../../../products/domain/services/supplier_follow_up.dart';
import '../../domain/services/sales_report.dart';
import '../../domain/services/supplier_payables_report.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  static const routePath = '/reports';

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _repository = sl<InvoiceRepository>();
  final _customerRepository = sl<CustomerRepository>();
  final _productRepository = sl<ProductRepository>();
  final _purchaseEntryRepository = sl<PurchaseEntryRepository>();
  final _supplierRepository = sl<SupplierRepository>();
  var _range = _ReportDateRange.thisMonth;
  var _isLoading = true;
  var _isExporting = false;
  String? _message;
  SalesReport _report = buildSalesReport(invoices: const []);
  SupplierPayablesReport _supplierPayablesReport = buildSupplierPayablesReport(
    purchaseEntries: const [],
    suppliers: const [],
  );
  SupplierFollowUpQueue _supplierFollowUpQueue = buildSupplierFollowUpQueue(
    suppliers: const [],
    purchaseEntries: const [],
  );
  CustomerFollowUpQueue _customerFollowUpQueue = buildCustomerFollowUpQueue(
    customers: const [],
    invoices: const [],
  );
  CustomerAgingReport _customerAgingReport = buildCustomerAgingReport(
    customers: const [],
    invoices: const [],
  );
  InventoryValuationReport _inventoryValuationReport =
      buildInventoryValuationReport(products: const []);
  ProfitMarginReport _profitMarginReport = buildProfitMarginReport(
    invoices: const [],
    products: const [],
  );
  GstSummaryReport _gstSummaryReport = buildGstSummaryReport(
    invoices: const [],
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
        _repository.fetchInvoices(),
        _customerRepository.fetchCustomers(),
        _productRepository.fetchProducts(),
        _purchaseEntryRepository.fetchPurchaseEntries(),
        _supplierRepository.fetchSuppliers(),
      ]);
      final invoices = results[0] as List<Invoice>;
      final customers = results[1] as List<Customer>;
      final products = results[2] as List<ProductService>;
      final purchaseEntries = results[3] as List<PurchaseEntry>;
      final suppliers = results[4] as List<Supplier>;
      final bounds = _range.bounds(DateTime.now());
      if (!mounted) return;
      setState(() {
        _report = buildSalesReport(
          invoices: invoices,
          from: bounds.$1,
          to: bounds.$2,
        );
        _supplierPayablesReport = buildSupplierPayablesReport(
          purchaseEntries: purchaseEntries,
          suppliers: suppliers,
        );
        _supplierFollowUpQueue = buildSupplierFollowUpQueue(
          suppliers: suppliers,
          purchaseEntries: purchaseEntries,
        );
        _customerFollowUpQueue = buildCustomerFollowUpQueue(
          customers: customers,
          invoices: invoices,
        );
        _customerAgingReport = buildCustomerAgingReport(
          customers: customers,
          invoices: invoices,
        );
        _inventoryValuationReport = buildInventoryValuationReport(
          products: products,
        );
        _profitMarginReport = buildProfitMarginReport(
          invoices: invoices,
          products: products,
          from: bounds.$1,
          to: bounds.$2,
        );
        _gstSummaryReport = buildGstSummaryReport(
          invoices: invoices,
          from: bounds.$1,
          to: bounds.$2,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Could not load reports. Please try again.';
      });
    }
  }

  Future<void> _exportCsv() async {
    setState(() {
      _isExporting = true;
      _message = null;
    });
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save sales report CSV',
        fileName: 'sales-report-${_range.fileSuffix}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null) {
        if (mounted) setState(() => _isExporting = false);
        return;
      }
      final buffer = StringBuffer()
        ..writeln(buildSalesReportCsv(_report))
        ..writeln()
        ..writeln('Supplier Payables')
        ..writeln(buildSupplierPayablesCsv(_supplierPayablesReport))
        ..writeln()
        ..writeln('Supplier Follow-ups')
        ..writeln(buildSupplierFollowUpCsv(_supplierFollowUpQueue))
        ..writeln()
        ..writeln('Customer Follow-ups')
        ..writeln(buildCustomerFollowUpCsv(_customerFollowUpQueue))
        ..writeln()
        ..writeln('Customer Aging')
        ..writeln(buildCustomerAgingCsv(_customerAgingReport))
        ..writeln()
        ..writeln('Inventory Valuation')
        ..writeln(buildInventoryValuationCsv(_inventoryValuationReport))
        ..writeln()
        ..writeln('Profit and Margin')
        ..writeln(buildProfitMarginCsv(_profitMarginReport))
        ..writeln()
        ..writeln('GST Summary')
        ..writeln(buildGstSummaryCsv(_gstSummaryReport));
      await File(path).writeAsString(buffer.toString(), flush: true);
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _message = 'Reports exported.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _message = 'Could not export the report.';
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
            _ReportsHeader(
              isBusy: _isLoading || _isExporting,
              onRefresh: _load,
              onExport:
                  _report.rows.isEmpty &&
                      _supplierPayablesReport.rows.isEmpty &&
                      _supplierFollowUpQueue.rows.isEmpty &&
                      _customerFollowUpQueue.rows.isEmpty &&
                      _customerAgingReport.rows.isEmpty &&
                      _inventoryValuationReport.rows.isEmpty &&
                      _profitMarginReport.rows.isEmpty &&
                      _gstSummaryReport.rows.isEmpty
                  ? null
                  : _exportCsv,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<_ReportDateRange>(
                    initialValue: _range,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Report Range',
                      prefixIcon: Icon(Icons.date_range_outlined),
                    ),
                    items: [
                      for (final range in _ReportDateRange.values)
                        DropdownMenuItem(
                          value: range,
                          child: Text(range.label),
                        ),
                    ],
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _range = value);
                            _load();
                          },
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: _InlineMessage(message: _message!)),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _ReportContent(
                      report: _report,
                      supplierPayablesReport: _supplierPayablesReport,
                      supplierFollowUpQueue: _supplierFollowUpQueue,
                      customerFollowUpQueue: _customerFollowUpQueue,
                      customerAgingReport: _customerAgingReport,
                      inventoryValuationReport: _inventoryValuationReport,
                      profitMarginReport: _profitMarginReport,
                      gstSummaryReport: _gstSummaryReport,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.isBusy,
    required this.onRefresh,
    required this.onExport,
  });

  final bool isBusy;
  final VoidCallback onRefresh;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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
              Icons.analytics_outlined,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Review sales, tax, payments, credits, and outstanding balance.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: isBusy ? null : onExport,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export CSV'),
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    required this.report,
    required this.supplierPayablesReport,
    required this.supplierFollowUpQueue,
    required this.customerFollowUpQueue,
    required this.customerAgingReport,
    required this.inventoryValuationReport,
    required this.profitMarginReport,
    required this.gstSummaryReport,
  });

  final SalesReport report;
  final SupplierPayablesReport supplierPayablesReport;
  final SupplierFollowUpQueue supplierFollowUpQueue;
  final CustomerFollowUpQueue customerFollowUpQueue;
  final CustomerAgingReport customerAgingReport;
  final InventoryValuationReport inventoryValuationReport;
  final ProfitMarginReport profitMarginReport;
  final GstSummaryReport gstSummaryReport;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _MetricsGrid(report: report),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 320, child: _ReportTable(report: report)),
          const SizedBox(height: AppSpacing.xl),
          _SupplierPayablesMetrics(report: supplierPayablesReport),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 320,
            child: _SupplierPayablesTable(report: supplierPayablesReport),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SupplierFollowUpMetrics(queue: supplierFollowUpQueue),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 280,
            child: _SupplierFollowUpTable(queue: supplierFollowUpQueue),
          ),
          const SizedBox(height: AppSpacing.xl),
          _CustomerFollowUpMetrics(queue: customerFollowUpQueue),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 280,
            child: _CustomerFollowUpTable(queue: customerFollowUpQueue),
          ),
          const SizedBox(height: AppSpacing.xl),
          _CustomerAgingMetrics(report: customerAgingReport),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 320,
            child: _CustomerAgingTable(report: customerAgingReport),
          ),
          const SizedBox(height: AppSpacing.xl),
          _InventoryValuationMetrics(report: inventoryValuationReport),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 320,
            child: _InventoryValuationTable(report: inventoryValuationReport),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ProfitMarginMetrics(report: profitMarginReport),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 320,
            child: _ProfitMarginTable(report: profitMarginReport),
          ),
          const SizedBox(height: AppSpacing.xl),
          _GstSummaryMetrics(report: gstSummaryReport),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 300,
            child: _GstSummaryTable(report: gstSummaryReport),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 104,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _MetricCard(
          icon: Icons.receipt_long_outlined,
          label: 'Invoices',
          value: report.invoiceCount.toString(),
        ),
        _MetricCard(
          icon: Icons.payments_outlined,
          label: 'Total Invoiced',
          value: _money(report.totalInvoiced),
        ),
        _MetricCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Paid',
          value: _money(report.totalPaid),
        ),
        _MetricCard(
          icon: Icons.pending_actions_outlined,
          label: 'Outstanding',
          value: _money(report.outstandingBalance),
        ),
        _MetricCard(
          icon: Icons.assignment_return_outlined,
          label: 'Credits',
          value: _money(report.totalCredited),
        ),
        _MetricCard(
          icon: Icons.calculate_outlined,
          label: 'GST',
          value: _money(report.cgstTotal + report.sgstTotal + report.igstTotal),
        ),
      ],
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple),
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
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                    fontWeight: FontWeight.w800,
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

class _SupplierPayablesMetrics extends StatelessWidget {
  const _SupplierPayablesMetrics({required this.report});

  final SupplierPayablesReport report;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 104,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _MetricCard(
          icon: Icons.storefront_outlined,
          label: 'Suppliers',
          value: report.supplierCount.toString(),
        ),
        _MetricCard(
          icon: Icons.receipt_long_outlined,
          label: 'Supplier Bills',
          value: report.billCount.toString(),
        ),
        _MetricCard(
          icon: Icons.pending_actions_outlined,
          label: 'Open Bills',
          value: report.openBillCount.toString(),
          valueColor: report.openBillCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.error_outline,
          label: 'Overdue Bills',
          value: report.overdueBillCount.toString(),
          valueColor: report.overdueBillCount > 0
              ? AppColors.error
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.money_off_csred_outlined,
          label: 'Outstanding',
          value: _money(report.totalOutstanding),
          valueColor: report.totalOutstanding > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.notification_important_outlined,
          label: 'Overdue Amount',
          value: _money(report.totalOverdue),
          valueColor: report.totalOverdue > 0
              ? AppColors.error
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.payments_outlined,
          label: 'Paid to Suppliers',
          value: _money(report.totalPaid),
        ),
        _MetricCard(
          icon: Icons.shopping_bag_outlined,
          label: 'Purchased',
          value: _money(report.totalPurchased),
        ),
        _MetricCard(
          icon: Icons.schedule_outlined,
          label: '0-30 Days',
          value: _money(report.currentBucketTotal),
        ),
        _MetricCard(
          icon: Icons.timelapse_outlined,
          label: '31-60 Days',
          value: _money(report.days31To60BucketTotal),
        ),
        _MetricCard(
          icon: Icons.history_toggle_off_outlined,
          label: '61-90 Days',
          value: _money(report.days61To90BucketTotal),
        ),
        _MetricCard(
          icon: Icons.warning_amber_outlined,
          label: '90+ Days',
          value: _money(report.days90PlusBucketTotal),
          valueColor: report.days90PlusBucketTotal > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _SupplierPayablesTable extends StatelessWidget {
  const _SupplierPayablesTable({required this.report});

  final SupplierPayablesReport report;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            'No supplier payable activity yet.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(AppColors.surfaceSoft),
              columns: const [
                DataColumn(label: Text('Supplier')),
                DataColumn(label: Text('Last Purchase')),
                DataColumn(numeric: true, label: Text('Bills')),
                DataColumn(numeric: true, label: Text('Open Bills')),
                DataColumn(numeric: true, label: Text('Overdue Bills')),
                DataColumn(numeric: true, label: Text('Purchased')),
                DataColumn(numeric: true, label: Text('Paid')),
                DataColumn(numeric: true, label: Text('Outstanding')),
                DataColumn(numeric: true, label: Text('Overdue Amount')),
                DataColumn(numeric: true, label: Text('0-30')),
                DataColumn(numeric: true, label: Text('31-60')),
                DataColumn(numeric: true, label: Text('61-90')),
                DataColumn(numeric: true, label: Text('90+')),
              ],
              rows: [
                for (final row in report.rows)
                  DataRow(
                    cells: [
                      DataCell(Text(row.supplierName)),
                      DataCell(
                        Text(
                          row.lastPurchaseDate == null
                              ? '-'
                              : _date(row.lastPurchaseDate!),
                        ),
                      ),
                      DataCell(Text(row.billCount.toString())),
                      DataCell(Text(row.openBillCount.toString())),
                      DataCell(
                        Text(
                          row.overdueBillCount.toString(),
                          style: TextStyle(
                            color: row.overdueBillCount > 0
                                ? AppColors.error
                                : AppColors.textPrimary,
                            fontWeight: row.overdueBillCount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(Text(_money(row.totalPurchased))),
                      DataCell(Text(_money(row.totalPaid))),
                      DataCell(
                        Text(
                          _money(row.outstandingBalance),
                          style: TextStyle(
                            color: row.outstandingBalance > 0
                                ? AppColors.warning
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _money(row.overdueAmount),
                          style: TextStyle(
                            color: row.overdueAmount > 0
                                ? AppColors.error
                                : AppColors.textPrimary,
                            fontWeight: row.overdueAmount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(Text(_money(row.currentBucketAmount))),
                      DataCell(Text(_money(row.days31To60BucketAmount))),
                      DataCell(Text(_money(row.days61To90BucketAmount))),
                      DataCell(
                        Text(
                          _money(row.days90PlusBucketAmount),
                          style: TextStyle(
                            color: row.days90PlusBucketAmount > 0
                                ? AppColors.warning
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplierFollowUpMetrics extends StatelessWidget {
  const _SupplierFollowUpMetrics({required this.queue});

  final SupplierFollowUpQueue queue;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 104,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _MetricCard(
          icon: Icons.task_alt_outlined,
          label: 'Action Queue',
          value: queue.actionCount.toString(),
          valueColor: queue.actionCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.error_outline,
          label: 'Overdue Suppliers',
          value: queue.overdueSupplierCount.toString(),
          valueColor: queue.overdueSupplierCount > 0
              ? AppColors.error
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.notifications_active_outlined,
          label: 'Reminders Due',
          value: queue.reminderDueCount.toString(),
          valueColor: queue.reminderDueCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.money_off_csred_outlined,
          label: 'Overdue Amount',
          value: _money(queue.totalOverdueAmount),
          valueColor: queue.totalOverdueAmount > 0
              ? AppColors.error
              : AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _SupplierFollowUpTable extends StatelessWidget {
  const _SupplierFollowUpTable({required this.queue});

  final SupplierFollowUpQueue queue;

  @override
  Widget build(BuildContext context) {
    if (queue.rows.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            'No supplier follow-up actions right now.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(AppColors.surfaceSoft),
              columns: const [
                DataColumn(label: Text('Supplier')),
                DataColumn(label: Text('Status')),
                DataColumn(numeric: true, label: Text('Outstanding')),
                DataColumn(numeric: true, label: Text('Overdue')),
                DataColumn(numeric: true, label: Text('Overdue Bills')),
                DataColumn(label: Text('Last Purchase')),
                DataColumn(label: Text('Last Contacted')),
                DataColumn(label: Text('Next Follow-up')),
                DataColumn(label: Text('Reminder Due')),
              ],
              rows: [
                for (final row in queue.rows)
                  DataRow(
                    cells: [
                      DataCell(Text(row.supplier.name)),
                      DataCell(Text(row.supplier.followUpStatus.label)),
                      DataCell(Text(_money(row.outstandingBalance))),
                      DataCell(
                        Text(
                          _money(row.overdueAmount),
                          style: TextStyle(
                            color: row.overdueAmount > 0
                                ? AppColors.error
                                : AppColors.textPrimary,
                            fontWeight: row.overdueAmount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(Text(row.overdueBillCount.toString())),
                      DataCell(
                        Text(
                          row.lastPurchaseDate == null
                              ? '-'
                              : _date(row.lastPurchaseDate!),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.supplier.lastContactedAt == null
                              ? '-'
                              : _date(row.supplier.lastContactedAt!),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.supplier.nextFollowUpDate == null
                              ? '-'
                              : _date(row.supplier.nextFollowUpDate!),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.reminderDue ? 'Yes' : 'No',
                          style: TextStyle(
                            color: row.reminderDue
                                ? AppColors.warning
                                : AppColors.textPrimary,
                            fontWeight: row.reminderDue
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerFollowUpMetrics extends StatelessWidget {
  const _CustomerFollowUpMetrics({required this.queue});

  final CustomerFollowUpQueue queue;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 104,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _MetricCard(
          icon: Icons.task_alt_outlined,
          label: 'Customer Actions',
          value: queue.actionCount.toString(),
          valueColor: queue.actionCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.error_outline,
          label: 'Overdue Customers',
          value: queue.overdueCustomerCount.toString(),
          valueColor: queue.overdueCustomerCount > 0
              ? AppColors.error
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.notifications_active_outlined,
          label: 'Reminders Due',
          value: queue.reminderDueCount.toString(),
          valueColor: queue.reminderDueCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.money_off_csred_outlined,
          label: 'Overdue Amount',
          value: _money(queue.totalOverdueAmount),
          valueColor: queue.totalOverdueAmount > 0
              ? AppColors.error
              : AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _CustomerFollowUpTable extends StatelessWidget {
  const _CustomerFollowUpTable({required this.queue});

  final CustomerFollowUpQueue queue;

  @override
  Widget build(BuildContext context) {
    if (queue.rows.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            'No customer follow-up actions right now.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(AppColors.surfaceSoft),
              columns: const [
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Status')),
                DataColumn(numeric: true, label: Text('Outstanding')),
                DataColumn(numeric: true, label: Text('Overdue')),
                DataColumn(numeric: true, label: Text('Overdue Invoices')),
                DataColumn(label: Text('Last Invoice')),
                DataColumn(label: Text('Last Contacted')),
                DataColumn(label: Text('Next Follow-up')),
                DataColumn(label: Text('Reminder Due')),
              ],
              rows: [
                for (final row in queue.rows)
                  DataRow(
                    cells: [
                      DataCell(Text(row.customer.name)),
                      DataCell(Text(row.customer.followUpStatus.label)),
                      DataCell(Text(_money(row.outstandingBalance))),
                      DataCell(
                        Text(
                          _money(row.overdueAmount),
                          style: TextStyle(
                            color: row.overdueAmount > 0
                                ? AppColors.error
                                : AppColors.textPrimary,
                            fontWeight: row.overdueAmount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(Text(row.overdueInvoiceCount.toString())),
                      DataCell(
                        Text(
                          row.lastInvoiceDate == null
                              ? '-'
                              : _date(row.lastInvoiceDate!),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.customer.lastContactedAt == null
                              ? '-'
                              : _date(row.customer.lastContactedAt!),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.customer.nextFollowUpDate == null
                              ? '-'
                              : _date(row.customer.nextFollowUpDate!),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.reminderDue ? 'Yes' : 'No',
                          style: TextStyle(
                            color: row.reminderDue
                                ? AppColors.warning
                                : AppColors.textPrimary,
                            fontWeight: row.reminderDue
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerAgingMetrics extends StatelessWidget {
  const _CustomerAgingMetrics({required this.report});

  final CustomerAgingReport report;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 104,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _MetricCard(
          icon: Icons.groups_outlined,
          label: 'Aging Customers',
          value: report.customerCount.toString(),
        ),
        _MetricCard(
          icon: Icons.receipt_long_outlined,
          label: 'Open Invoices',
          value: report.openInvoiceCount.toString(),
        ),
        _MetricCard(
          icon: Icons.pending_actions_outlined,
          label: 'Outstanding',
          value: _money(report.totalOutstanding),
          valueColor: report.totalOutstanding > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.warning_amber_outlined,
          label: '90+ Aging',
          value: _money(report.days90PlusTotal),
          valueColor: report.days90PlusTotal > 0
              ? AppColors.error
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.today_outlined,
          label: 'Current',
          value: _money(report.currentTotal),
        ),
        _MetricCard(
          icon: Icons.schedule_outlined,
          label: '0-30',
          value: _money(report.days0To30Total),
        ),
        _MetricCard(
          icon: Icons.timelapse_outlined,
          label: '31-60',
          value: _money(report.days31To60Total),
        ),
        _MetricCard(
          icon: Icons.history_toggle_off_outlined,
          label: '61-90',
          value: _money(report.days61To90Total),
        ),
      ],
    );
  }
}

class _CustomerAgingTable extends StatelessWidget {
  const _CustomerAgingTable({required this.report});

  final CustomerAgingReport report;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return _EmptyReportBox(message: 'No open customer balances to age.');
    }
    return _ReportTableShell(
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(AppColors.surfaceSoft),
        columns: const [
          DataColumn(label: Text('Customer')),
          DataColumn(numeric: true, label: Text('Open Invoices')),
          DataColumn(numeric: true, label: Text('Outstanding')),
          DataColumn(numeric: true, label: Text('Current')),
          DataColumn(numeric: true, label: Text('0-30')),
          DataColumn(numeric: true, label: Text('31-60')),
          DataColumn(numeric: true, label: Text('61-90')),
          DataColumn(numeric: true, label: Text('90+')),
          DataColumn(numeric: true, label: Text('Oldest Days')),
          DataColumn(label: Text('Last Invoice')),
        ],
        rows: [
          for (final row in report.rows)
            DataRow(
              cells: [
                DataCell(Text(row.customerName)),
                DataCell(Text(row.openInvoiceCount.toString())),
                DataCell(Text(_money(row.totalOutstanding))),
                DataCell(Text(_money(row.currentAmount))),
                DataCell(Text(_money(row.days0To30Amount))),
                DataCell(Text(_money(row.days31To60Amount))),
                DataCell(Text(_money(row.days61To90Amount))),
                DataCell(
                  Text(
                    _money(row.days90PlusAmount),
                    style: TextStyle(
                      color: row.days90PlusAmount > 0
                          ? AppColors.error
                          : AppColors.textPrimary,
                      fontWeight: row.days90PlusAmount > 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                DataCell(Text(row.oldestOverdueDays.toString())),
                DataCell(
                  Text(
                    row.lastInvoiceDate == null
                        ? '-'
                        : _date(row.lastInvoiceDate!),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InventoryValuationMetrics extends StatelessWidget {
  const _InventoryValuationMetrics({required this.report});

  final InventoryValuationReport report;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 104,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _MetricCard(
          icon: Icons.inventory_2_outlined,
          label: 'Tracked Products',
          value: report.productCount.toString(),
        ),
        _MetricCard(
          icon: Icons.warning_amber_outlined,
          label: 'Low Stock',
          value: report.lowStockCount.toString(),
          valueColor: report.lowStockCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _MetricCard(
          icon: Icons.numbers_outlined,
          label: 'Stock Quantity',
          value: _number(report.totalQuantity),
        ),
        _MetricCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Stock Value',
          value: _money(report.totalValue),
        ),
        _MetricCard(
          icon: Icons.add_shopping_cart_outlined,
          label: 'Restock Value',
          value: _money(report.restockValue),
        ),
      ],
    );
  }
}

class _InventoryValuationTable extends StatelessWidget {
  const _InventoryValuationTable({required this.report});

  final InventoryValuationReport report;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return _EmptyReportBox(message: 'No tracked inventory products yet.');
    }
    return _ReportTableShell(
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(AppColors.surfaceSoft),
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('SKU')),
          DataColumn(label: Text('Unit')),
          DataColumn(numeric: true, label: Text('Qty')),
          DataColumn(numeric: true, label: Text('Cost')),
          DataColumn(numeric: true, label: Text('Value')),
          DataColumn(numeric: true, label: Text('Reorder')),
          DataColumn(label: Text('Low Stock')),
          DataColumn(numeric: true, label: Text('Restock Qty')),
          DataColumn(numeric: true, label: Text('Restock Value')),
        ],
        rows: [
          for (final row in report.rows)
            DataRow(
              cells: [
                DataCell(Text(row.name)),
                DataCell(Text(row.sku.isEmpty ? '-' : row.sku)),
                DataCell(Text(row.unit)),
                DataCell(Text(_number(row.quantity))),
                DataCell(Text(_money(row.costPrice))),
                DataCell(Text(_money(row.stockValue))),
                DataCell(Text(_number(row.reorderLevel))),
                DataCell(
                  Text(
                    row.lowStock ? 'Yes' : 'No',
                    style: TextStyle(
                      color: row.lowStock
                          ? AppColors.warning
                          : AppColors.textPrimary,
                      fontWeight: row.lowStock
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                DataCell(Text(_number(row.restockQuantity))),
                DataCell(Text(_money(row.restockValue))),
              ],
            ),
        ],
      ),
    );
  }
}

class _ProfitMarginMetrics extends StatelessWidget {
  const _ProfitMarginMetrics({required this.report});

  final ProfitMarginReport report;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 104,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _MetricCard(
          icon: Icons.receipt_long_outlined,
          label: 'Invoices',
          value: report.invoiceCount.toString(),
        ),
        _MetricCard(
          icon: Icons.sell_outlined,
          label: 'Revenue',
          value: _money(report.totalRevenue),
        ),
        _MetricCard(
          icon: Icons.shopping_bag_outlined,
          label: 'Cost',
          value: _money(report.totalCost),
        ),
        _MetricCard(
          icon: Icons.trending_up_outlined,
          label: 'Gross Profit',
          value: _money(report.grossProfit),
          valueColor: report.grossProfit >= 0
              ? AppColors.success
              : AppColors.error,
        ),
        _MetricCard(
          icon: Icons.percent_outlined,
          label: 'Margin %',
          value: '${_money(report.marginPercent)}%',
        ),
        _MetricCard(
          icon: Icons.help_outline,
          label: 'Unknown Cost Lines',
          value: report.unknownCostLineCount.toString(),
          valueColor: report.unknownCostLineCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _ProfitMarginTable extends StatelessWidget {
  const _ProfitMarginTable({required this.report});

  final ProfitMarginReport report;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return _EmptyReportBox(message: 'No invoice lines for margin reporting.');
    }
    return _ReportTableShell(
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(AppColors.surfaceSoft),
        columns: const [
          DataColumn(label: Text('Invoice')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Customer')),
          DataColumn(label: Text('Item')),
          DataColumn(numeric: true, label: Text('Qty')),
          DataColumn(numeric: true, label: Text('Revenue')),
          DataColumn(numeric: true, label: Text('Cost')),
          DataColumn(numeric: true, label: Text('Profit')),
          DataColumn(numeric: true, label: Text('Margin %')),
          DataColumn(label: Text('Cost Known')),
        ],
        rows: [
          for (final row in report.rows)
            DataRow(
              cells: [
                DataCell(Text(row.invoiceNumber)),
                DataCell(Text(_date(row.invoiceDate))),
                DataCell(Text(row.customerName)),
                DataCell(Text(row.itemName)),
                DataCell(Text(_number(row.quantity))),
                DataCell(Text(_money(row.revenue))),
                DataCell(Text(row.costKnown ? _money(row.cost) : '-')),
                DataCell(
                  Text(
                    _money(row.grossProfit),
                    style: TextStyle(
                      color: row.grossProfit >= 0
                          ? AppColors.success
                          : AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DataCell(Text('${_money(row.marginPercent)}%')),
                DataCell(Text(row.costKnown ? 'Yes' : 'No')),
              ],
            ),
        ],
      ),
    );
  }
}

class _GstSummaryMetrics extends StatelessWidget {
  const _GstSummaryMetrics({required this.report});

  final GstSummaryReport report;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 104,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _MetricCard(
          icon: Icons.receipt_long_outlined,
          label: 'GST Invoices',
          value: report.invoiceCount.toString(),
        ),
        _MetricCard(
          icon: Icons.calculate_outlined,
          label: 'Taxable',
          value: _money(report.taxableTotal),
        ),
        _MetricCard(
          icon: Icons.account_balance_outlined,
          label: 'CGST',
          value: _money(report.cgstTotal),
        ),
        _MetricCard(
          icon: Icons.account_balance_outlined,
          label: 'SGST',
          value: _money(report.sgstTotal),
        ),
        _MetricCard(
          icon: Icons.public_outlined,
          label: 'IGST',
          value: _money(report.igstTotal),
        ),
        _MetricCard(
          icon: Icons.summarize_outlined,
          label: 'GST Total',
          value: _money(report.gstTotal),
        ),
      ],
    );
  }
}

class _GstSummaryTable extends StatelessWidget {
  const _GstSummaryTable({required this.report});

  final GstSummaryReport report;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty && report.rateRows.isEmpty) {
      return _EmptyReportBox(message: 'No GST activity for this range.');
    }
    return _ReportTableShell(
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(AppColors.surfaceSoft),
        columns: const [
          DataColumn(label: Text('Group')),
          DataColumn(numeric: true, label: Text('Invoices')),
          DataColumn(numeric: true, label: Text('Taxable')),
          DataColumn(numeric: true, label: Text('CGST')),
          DataColumn(numeric: true, label: Text('SGST')),
          DataColumn(numeric: true, label: Text('IGST')),
          DataColumn(numeric: true, label: Text('GST Total')),
        ],
        rows: [
          for (final row in report.rows)
            DataRow(
              cells: [
                DataCell(Text(row.taxMode.label)),
                DataCell(Text(row.invoiceCount.toString())),
                DataCell(Text(_money(row.taxableAmount))),
                DataCell(Text(_money(row.cgstAmount))),
                DataCell(Text(_money(row.sgstAmount))),
                DataCell(Text(_money(row.igstAmount))),
                DataCell(Text(_money(row.gstAmount))),
              ],
            ),
          for (final row in report.rateRows)
            DataRow(
              cells: [
                DataCell(Text('${_number(row.gstRate)}% GST')),
                const DataCell(Text('-')),
                DataCell(Text(_money(row.taxableAmount))),
                DataCell(Text(_money(row.cgstAmount))),
                DataCell(Text(_money(row.sgstAmount))),
                DataCell(Text(_money(row.igstAmount))),
                DataCell(Text(_money(row.gstAmount))),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return Center(
        child: Text(
          'No invoice activity for this range.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(AppColors.surfaceSoft),
              columns: const [
                DataColumn(label: Text('Invoice')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Status')),
                DataColumn(numeric: true, label: Text('Total')),
                DataColumn(numeric: true, label: Text('Paid')),
                DataColumn(numeric: true, label: Text('Credits')),
                DataColumn(numeric: true, label: Text('Balance')),
                DataColumn(numeric: true, label: Text('GST')),
              ],
              rows: [
                for (final row in report.rows)
                  DataRow(
                    cells: [
                      DataCell(Text(row.invoiceNumber)),
                      DataCell(Text(_date(row.invoiceDate))),
                      DataCell(Text(row.customerName)),
                      DataCell(Text(row.status.label)),
                      DataCell(Text(_money(row.grandTotal))),
                      DataCell(Text(_money(row.amountPaid))),
                      DataCell(Text(_money(row.creditTotal))),
                      DataCell(Text(_money(row.balanceDue))),
                      DataCell(
                        Text(
                          _money(
                            row.cgstAmount + row.sgstAmount + row.igstAmount,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportTableShell extends StatelessWidget {
  const _ReportTableShell({required this.child});

  final DataTable child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _EmptyReportBox extends StatelessWidget {
  const _EmptyReportBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

enum _ReportDateRange {
  all('All time', 'all'),
  thisMonth('This month', 'this-month'),
  lastMonth('Last month', 'last-month'),
  thisYear('This financial year', 'this-financial-year');

  const _ReportDateRange(this.label, this.fileSuffix);

  final String label;
  final String fileSuffix;

  (DateTime?, DateTime?) bounds(DateTime today) {
    return switch (this) {
      _ReportDateRange.all => (null, null),
      _ReportDateRange.thisMonth => (
        DateTime(today.year, today.month),
        DateTime(today.year, today.month + 1, 0),
      ),
      _ReportDateRange.lastMonth => (
        DateTime(today.year, today.month - 1),
        DateTime(today.year, today.month, 0),
      ),
      _ReportDateRange.thisYear => _financialYearBounds(today),
    };
  }
}

(DateTime, DateTime) _financialYearBounds(DateTime today) {
  final startYear = today.month >= 4 ? today.year : today.year - 1;
  return (DateTime(startYear, 4), DateTime(startYear + 1, 3, 31));
}

String _date(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _money(double value) => value.toStringAsFixed(2);

String _number(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
