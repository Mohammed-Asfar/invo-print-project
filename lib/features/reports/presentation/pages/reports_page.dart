import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../invoices/data/repositories/invoice_repository.dart';
import '../../domain/services/sales_report.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  static const routePath = '/reports';

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _repository = sl<InvoiceRepository>();
  var _range = _ReportDateRange.thisMonth;
  var _isLoading = true;
  var _isExporting = false;
  String? _message;
  SalesReport _report = buildSalesReport(invoices: const []);

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
      final invoices = await _repository.fetchInvoices();
      final bounds = _range.bounds(DateTime.now());
      if (!mounted) return;
      setState(() {
        _report = buildSalesReport(
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
      await File(path).writeAsString(buildSalesReportCsv(_report), flush: true);
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _message = 'Sales report exported.';
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
              onExport: _report.rows.isEmpty ? null : _exportCsv,
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
                  : _ReportContent(report: _report),
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
  const _ReportContent({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricsGrid(report: report),
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: _ReportTable(report: report)),
      ],
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
                    color: AppColors.textPrimary,
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
