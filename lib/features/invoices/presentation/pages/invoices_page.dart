import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../company/domain/entities/company_profile.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/services/invoice_filters.dart';
import '../../domain/services/invoice_pdf_service.dart';
import '../cubit/invoice_cubit.dart';
import 'create_invoice_page.dart';
import 'invoice_export_file_names.dart';

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key, this.cubitFactory});

  static const routePath = '/invoices';
  final InvoiceCubit Function()? cubitFactory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (cubitFactory?.call() ?? sl<InvoiceCubit>())..load(),
      child: const _InvoicesView(),
    );
  }
}

class _InvoicesView extends StatefulWidget {
  const _InvoicesView();

  @override
  State<_InvoicesView> createState() => _InvoicesViewState();
}

class _InvoicesViewState extends State<_InvoicesView> {
  _InvoiceStatusFilter _statusFilter = _InvoiceStatusFilter.all;
  _InvoiceDateFilter _dateFilter = _InvoiceDateFilter.all;
  String? _selectedInvoiceId;
  final Set<String> _bulkSelectedIds = {};

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvoiceCubit, InvoiceState>(
      listener: (context, state) {
        if (state.status == InvoiceStatusView.failure ||
            state.status == InvoiceStatusView.saved) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message ?? 'Done'),
                backgroundColor: state.status == InvoiceStatusView.failure
                    ? AppColors.error
                    : AppColors.success,
              ),
            );
        }
      },
      builder: (context, state) {
        final filteredInvoices = _applyFilters(state.filteredInvoices);
        final selectedInvoice = _selectedInvoice(filteredInvoices);
        final selectedBulkInvoices = filteredInvoices
            .where((invoice) => _bulkSelectedIds.contains(invoice.id))
            .toList();
        return ColoredBox(
          color: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(state: state),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('invoice-search-field'),
                        onChanged: (value) {
                          setState(_bulkSelectedIds.clear);
                          context.read<InvoiceCubit>().search(value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Search invoices',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _FilterDropdown<_InvoiceStatusFilter>(
                      key: const ValueKey('invoice-status-filter'),
                      width: 190,
                      label: 'Status',
                      value: _statusFilter,
                      values: _InvoiceStatusFilter.values,
                      labelBuilder: (value) => value.label,
                      onChanged: (value) => setState(() {
                        _statusFilter = value;
                        _bulkSelectedIds.clear();
                      }),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _FilterDropdown<_InvoiceDateFilter>(
                      key: const ValueKey('invoice-date-filter'),
                      width: 190,
                      label: 'Date',
                      value: _dateFilter,
                      values: _InvoiceDateFilter.values,
                      labelBuilder: (value) => value.label,
                      onChanged: (value) => setState(() {
                        _dateFilter = value;
                        _bulkSelectedIds.clear();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _FilterSummary(
                  totalCount: state.invoices.length,
                  visibleCount: filteredInvoices.length,
                  overdueCount: filteredInvoices.where(_isOverdue).length,
                ),
                if (selectedBulkInvoices.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _BulkActionBar(
                    selectedCount: selectedBulkInvoices.length,
                    allVisibleSelected:
                        filteredInvoices.isNotEmpty &&
                        selectedBulkInvoices.length == filteredInvoices.length,
                    onSelectAll: () => setState(() {
                      _bulkSelectedIds
                        ..clear()
                        ..addAll(filteredInvoices.map((invoice) => invoice.id));
                    }),
                    onClear: () => setState(_bulkSelectedIds.clear),
                    onExport: () => _exportSelectedPdfs(
                      context,
                      selectedBulkInvoices,
                      state.settings,
                      state.companyProfile,
                    ),
                    onCancel: () => _bulkCancel(context, selectedBulkInvoices),
                    onDelete: () => _bulkDelete(context, selectedBulkInvoices),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: state.status == InvoiceStatusView.loading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final showPreview = constraints.maxWidth >= 980;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _InvoiceList(
                                    invoices: filteredInvoices,
                                    hasAnyInvoices: state.invoices.isNotEmpty,
                                    settings: state.settings,
                                    companyProfile: state.companyProfile,
                                    selectedInvoiceId: selectedInvoice?.id,
                                    bulkSelectedIds: _bulkSelectedIds,
                                    onSelect: (invoice) => setState(
                                      () => _selectedInvoiceId = invoice.id,
                                    ),
                                    onToggleBulkSelection: (invoice, selected) {
                                      setState(() {
                                        if (selected) {
                                          _bulkSelectedIds.add(invoice.id);
                                        } else {
                                          _bulkSelectedIds.remove(invoice.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                if (showPreview) ...[
                                  const SizedBox(width: AppSpacing.lg),
                                  SizedBox(
                                    width: 360,
                                    child: _InvoicePreviewPanel(
                                      invoice: selectedInvoice,
                                      settings: state.settings,
                                      companyProfile: state.companyProfile,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Invoice> _applyFilters(List<Invoice> invoices) {
    return invoices.where((invoice) {
      if (!_statusFilter.matches(invoice)) return false;
      if (!_dateFilter.matches(invoice)) return false;
      return true;
    }).toList();
  }

  Invoice? _selectedInvoice(List<Invoice> invoices) {
    if (invoices.isEmpty) return null;
    final selectedId = _selectedInvoiceId;
    if (selectedId == null) return invoices.first;
    return invoices.firstWhere(
      (invoice) => invoice.id == selectedId,
      orElse: () => invoices.first,
    );
  }

  Future<void> _exportSelectedPdfs(
    BuildContext context,
    List<Invoice> invoices,
    AppSettings? settings,
    CompanyProfile? companyProfile,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose folder for invoice PDFs',
    );
    if (directory == null || directory.trim().isEmpty) return;
    try {
      final fileNames = buildBulkInvoicePdfFileNames(invoices);
      for (var index = 0; index < invoices.length; index++) {
        final invoice = invoices[index];
        final bytes = await sl<InvoicePdfService>().buildInvoicePdf(
          invoice: invoice,
          currencySymbol: settings?.currencySymbol ?? 'Rs',
          currentCompanyProfile: companyProfile,
          settings: settings,
        );
        final file = File(
          '$directory${Platform.pathSeparator}${fileNames[index]}',
        );
        await file.writeAsBytes(bytes, flush: true);
      }
      if (!context.mounted) return;
      setState(_bulkSelectedIds.clear);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${invoices.length} invoice PDFs exported.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Unable to export selected invoices: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _bulkCancel(BuildContext context, List<Invoice> invoices) async {
    final cancellable = invoices.where(_canCancelInvoice).toList();
    if (cancellable.isEmpty) return;
    final confirmed = await _confirmBulkAction(
      context,
      title: 'Cancel selected invoices?',
      message: 'This will mark ${cancellable.length} invoices as cancelled.',
      confirmLabel: 'Cancel Invoices',
      confirmColor: AppColors.warning,
    );
    if (confirmed != true || !context.mounted) return;
    final cubit = context.read<InvoiceCubit>();
    for (final invoice in cancellable) {
      await cubit.cancelInvoice(invoice);
    }
    if (mounted) setState(_bulkSelectedIds.clear);
  }

  Future<void> _bulkDelete(BuildContext context, List<Invoice> invoices) async {
    final confirmed = await _confirmBulkAction(
      context,
      title: 'Archive selected invoices?',
      message:
          'This will remove ${invoices.length} invoices from the active list while keeping them in your records.',
      confirmLabel: 'Archive',
      confirmColor: AppColors.error,
    );
    if (confirmed != true || !context.mounted) return;
    final cubit = context.read<InvoiceCubit>();
    for (final invoice in invoices) {
      await cubit.deleteInvoice(invoice);
    }
    if (mounted) setState(_bulkSelectedIds.clear);
  }

  Future<bool?> _confirmBulkAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final InvoiceState state;

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
              Icons.receipt_long_outlined,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoices',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Create GST or non-GST invoices with manual items and customer auto-create.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: state.isBusy || state.draft == null
                ? null
                : () => context.go(CreateInvoicePage.routePath),
            icon: const Icon(Icons.add),
            label: const Text('New Invoice'),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    super.key,
    required this.width,
    required this.label,
    required this.value,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
  });

  final double width;
  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.filter_list_outlined),
        ),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(labelBuilder(item))),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({
    required this.totalCount,
    required this.visibleCount,
    required this.overdueCount,
  });

  final int totalCount;
  final int visibleCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _StatusPill(label: '$visibleCount shown'),
        _StatusPill(label: '$totalCount total'),
        if (overdueCount > 0)
          _StatusPill(label: '$overdueCount overdue', color: AppColors.warning),
      ],
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectedCount,
    required this.allVisibleSelected,
    required this.onSelectAll,
    required this.onClear,
    required this.onExport,
    required this.onCancel,
    required this.onDelete,
  });

  final int selectedCount;
  final bool allVisibleSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onExport;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryPurple),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusPill(label: '$selectedCount selected'),
          OutlinedButton.icon(
            onPressed: allVisibleSelected ? null : onSelectAll,
            icon: const Icon(Icons.select_all_outlined),
            label: const Text('Select visible'),
          ),
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export PDFs'),
          ),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.block_outlined),
            label: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: Icon(Icons.archive_outlined, color: AppColors.error),
            label: Text('Archive', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(onPressed: onClear, child: const Text('Clear')),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primaryPurple;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({
    required this.invoices,
    required this.hasAnyInvoices,
    required this.settings,
    required this.companyProfile,
    required this.selectedInvoiceId,
    required this.bulkSelectedIds,
    required this.onSelect,
    required this.onToggleBulkSelection,
  });

  final List<Invoice> invoices;
  final bool hasAnyInvoices;
  final AppSettings? settings;
  final CompanyProfile? companyProfile;
  final String? selectedInvoiceId;
  final Set<String> bulkSelectedIds;
  final ValueChanged<Invoice> onSelect;
  final void Function(Invoice invoice, bool selected) onToggleBulkSelection;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(
        child: Text(
          hasAnyInvoices
              ? 'No invoices match the current search or filters.'
              : 'No invoices yet.',
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
      child: ListView.separated(
        itemCount: invoices.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, thickness: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final invoice = invoices[index];
          final isSelected = invoice.id == selectedInvoiceId;
          final isBulkSelected = bulkSelectedIds.contains(invoice.id);
          final isOverdue = _isOverdue(invoice);
          final customerName =
              invoice.customerSnapshot['name']?.toString() ?? '';
          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.primaryLight.withValues(alpha: 0.28),
            onTap: () => onSelect(invoice),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  key: ValueKey('invoice-bulk-selection-${invoice.id}'),
                  value: isBulkSelected,
                  onChanged: (value) =>
                      onToggleBulkSelection(invoice, value ?? false),
                ),
                CircleAvatar(
                  backgroundColor: isOverdue
                      ? AppColors.warning.withValues(alpha: 0.18)
                      : AppColors.primaryLight,
                  child: Icon(
                    isOverdue
                        ? Icons.schedule_outlined
                        : Icons.receipt_outlined,
                    color: isOverdue
                        ? AppColors.warning
                        : AppColors.primaryPurple,
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(child: Text(invoice.invoiceNumber)),
                if (isOverdue) const _StatusPill(label: 'Overdue'),
              ],
            ),
            subtitle: Text(
              [
                if (customerName.isNotEmpty) customerName,
                invoice.status.label,
                'Due ${_formatDateShort(invoice.dueDate)}',
                if (invoice.balanceDue > 0)
                  'Balance ${invoice.balanceDue.toStringAsFixed(2)}',
              ].join('  |  '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  invoice.grandTotal.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PopupMenuButton<_InvoiceAction>(
                  tooltip: 'Invoice actions',
                  color: AppColors.surface,
                  onSelected: (action) async {
                    await _runInvoiceAction(
                      context,
                      invoice,
                      action,
                      settings: settings,
                      companyProfile: companyProfile,
                    );
                  },
                  itemBuilder: (context) => [
                    for (final action in _invoicePrimaryActions)
                      if (action.isAvailableFor(invoice))
                        _InvoiceActionMenuItem(
                          action: action,
                          invoice: invoice,
                        ),
                    const PopupMenuDivider(),
                    _InvoiceActionMenuItem(
                      action: _InvoiceAction.exportPdf,
                      invoice: invoice,
                    ),
                    if (_InvoiceAction.cancel.isAvailableFor(invoice))
                      _InvoiceActionMenuItem(
                        action: _InvoiceAction.cancel,
                        invoice: invoice,
                      ),
                    _InvoiceActionMenuItem(
                      action: _InvoiceAction.delete,
                      invoice: invoice,
                    ),
                  ],
                  child: Icon(
                    Icons.more_horiz,
                    color: AppColors.textSecondary,
                    semanticLabel: 'Invoice actions',
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

class _InvoiceActionMenuItem extends PopupMenuItem<_InvoiceAction> {
  _InvoiceActionMenuItem({
    required _InvoiceAction action,
    required Invoice invoice,
  }) : super(
         value: action,
         child: Row(
           children: [
             Icon(action.icon, color: action.color),
             const SizedBox(width: AppSpacing.sm),
             Text(
               action.labelFor(invoice),
               style: TextStyle(color: action.color),
             ),
           ],
         ),
       );
}

class _InvoicePreviewPanel extends StatelessWidget {
  const _InvoicePreviewPanel({
    required this.invoice,
    required this.settings,
    required this.companyProfile,
  });

  final Invoice? invoice;
  final AppSettings? settings;
  final CompanyProfile? companyProfile;

  @override
  Widget build(BuildContext context) {
    final invoice = this.invoice;
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: invoice == null
          ? Center(
              child: Text(
                'Select an invoice',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          invoice.invoiceNumber,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      if (_isOverdue(invoice))
                        _StatusPill(label: 'Overdue', color: AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    invoice.customerSnapshot['name']?.toString() ??
                        'No customer',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PreviewMetric(
                    label: 'Grand Total',
                    value: invoice.grandTotal.toStringAsFixed(2),
                    strong: true,
                  ),
                  _PreviewMetric(
                    label: 'Balance Due',
                    value: invoice.balanceDue.toStringAsFixed(2),
                    strong: invoice.balanceDue > 0,
                  ),
                  _PreviewMetric(label: 'Status', value: invoice.status.label),
                  _PreviewMetric(
                    label: 'Invoice Date',
                    value: _formatDateShort(invoice.invoiceDate),
                  ),
                  _PreviewMetric(
                    label: 'Due Date',
                    value: _formatDateShort(invoice.dueDate),
                  ),
                  _PreviewMetric(
                    label: 'Tax Mode',
                    value: invoice.taxMode.label,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PreviewActionGrid(
                    invoice: invoice,
                    settings: settings,
                    companyProfile: companyProfile,
                  ),
                  if (invoice.status == InvoiceStatus.cancelled) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Cancelled invoices can still be duplicated, exported, or archived.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (invoice.paymentHistory.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Payment History',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final payment in invoice.paymentHistory)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _PreviewMetric(
                          label:
                              '${_formatDateShort(payment.paidAt)}${payment.method.trim().isNotEmpty ? ' • ${payment.method.trim()}' : ''}',
                          value: payment.amount.toStringAsFixed(2),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PreviewActionGrid extends StatelessWidget {
  const _PreviewActionGrid({
    required this.invoice,
    required this.settings,
    required this.companyProfile,
  });

  final Invoice invoice;
  final AppSettings? settings;
  final CompanyProfile? companyProfile;

  @override
  Widget build(BuildContext context) {
    final actions = _invoicePreviewActions
        .where((action) => action.isAvailableFor(invoice))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < actions.length; index += 2) ...[
          Row(
            children: [
              Expanded(
                child: _PreviewActionButton(
                  action: actions[index],
                  invoice: invoice,
                  settings: settings,
                  companyProfile: companyProfile,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: index + 1 < actions.length
                    ? _PreviewActionButton(
                        action: actions[index + 1],
                        invoice: invoice,
                        settings: settings,
                        companyProfile: companyProfile,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          if (index + 2 < actions.length) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _PreviewActionButton extends StatelessWidget {
  const _PreviewActionButton({
    required this.action,
    required this.invoice,
    required this.settings,
    required this.companyProfile,
  });

  final _InvoiceAction action;
  final Invoice invoice;
  final AppSettings? settings;
  final CompanyProfile? companyProfile;

  @override
  Widget build(BuildContext context) {
    final color = action.color;
    return OutlinedButton.icon(
      onPressed: () => _runInvoiceAction(
        context,
        invoice,
        action,
        settings: settings,
        companyProfile: companyProfile,
      ),
      icon: Icon(action.icon, color: color),
      label: Text(action.labelFor(invoice), overflow: TextOverflow.ellipsis),
      style: color == null
          ? null
          : OutlinedButton.styleFrom(foregroundColor: color),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _InvoiceAction {
  edit,
  duplicate,
  recordPayment,
  cancel,
  exportPdf,
  delete,
}

const _invoicePrimaryActions = [
  _InvoiceAction.edit,
  _InvoiceAction.duplicate,
  _InvoiceAction.recordPayment,
];

const _invoicePreviewActions = [
  _InvoiceAction.edit,
  _InvoiceAction.duplicate,
  _InvoiceAction.recordPayment,
  _InvoiceAction.exportPdf,
  _InvoiceAction.cancel,
  _InvoiceAction.delete,
];

extension _InvoiceActionDetails on _InvoiceAction {
  IconData get icon {
    return switch (this) {
      _InvoiceAction.edit => Icons.edit_outlined,
      _InvoiceAction.duplicate => Icons.copy_all_outlined,
      _InvoiceAction.recordPayment => Icons.payments_outlined,
      _InvoiceAction.cancel => Icons.block_outlined,
      _InvoiceAction.exportPdf => Icons.picture_as_pdf_outlined,
      _InvoiceAction.delete => Icons.archive_outlined,
    };
  }

  Color? get color {
    return switch (this) {
      _InvoiceAction.cancel => AppColors.warning,
      _InvoiceAction.delete => AppColors.error,
      _ => null,
    };
  }

  bool isAvailableFor(Invoice invoice) {
    return switch (this) {
      _InvoiceAction.edit => invoice.status != InvoiceStatus.cancelled,
      _InvoiceAction.duplicate => true,
      _InvoiceAction.recordPayment =>
        invoice.status != InvoiceStatus.cancelled && invoice.balanceDue > 0,
      _InvoiceAction.cancel => _canCancelInvoice(invoice),
      _InvoiceAction.exportPdf => true,
      _InvoiceAction.delete => true,
    };
  }

  String labelFor(Invoice invoice) {
    return switch (this) {
      _InvoiceAction.edit => 'Edit',
      _InvoiceAction.duplicate => 'Duplicate',
      _InvoiceAction.recordPayment =>
        invoice.amountPaid <= 0 ? 'Mark paid' : 'Record payment',
      _InvoiceAction.cancel => 'Cancel',
      _InvoiceAction.exportPdf => 'Export PDF',
      _InvoiceAction.delete => 'Archive',
    };
  }
}

Future<void> _runInvoiceAction(
  BuildContext context,
  Invoice invoice,
  _InvoiceAction action, {
  required AppSettings? settings,
  required CompanyProfile? companyProfile,
}) async {
  switch (action) {
    case _InvoiceAction.edit:
      context.go(
        CreateInvoicePage.routePath,
        extra: CreateInvoicePageArgs.edit(invoice),
      );
      break;
    case _InvoiceAction.duplicate:
      context.go(
        CreateInvoicePage.routePath,
        extra: CreateInvoicePageArgs.duplicate(invoice),
      );
      break;
    case _InvoiceAction.recordPayment:
      await _showRecordPaymentDialog(context, invoice);
      break;
    case _InvoiceAction.cancel:
      await _confirmAndCancel(context, invoice);
      break;
    case _InvoiceAction.delete:
      await _confirmAndDelete(context, invoice);
      break;
    case _InvoiceAction.exportPdf:
      await _exportPdf(
        context,
        invoice,
        settings: settings,
        companyProfile: companyProfile,
      );
      break;
  }
}

Future<void> _exportPdf(
  BuildContext context,
  Invoice invoice, {
  required AppSettings? settings,
  required CompanyProfile? companyProfile,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  try {
    final defaultName = '${_sanitizeFileName(invoice.invoiceNumber)}.pdf';
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save invoice PDF',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (path == null || path.trim().isEmpty) {
      return;
    }

    final pdfBytes = await sl<InvoicePdfService>().buildInvoicePdf(
      invoice: invoice,
      currencySymbol: settings?.currencySymbol ?? 'Rs',
      currentCompanyProfile: companyProfile,
      settings: settings,
    );
    await File(path).writeAsBytes(pdfBytes, flush: true);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Invoice PDF saved to $path'),
        backgroundColor: AppColors.success,
      ),
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Unable to export PDF: $error'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

Future<void> _confirmAndCancel(BuildContext context, Invoice invoice) async {
  final confirmed = await _confirmAction(
    context,
    title: 'Cancel invoice?',
    message:
        'This will keep ${invoice.invoiceNumber} in your records and mark it as cancelled.',
    confirmLabel: 'Cancel invoice',
    confirmColor: AppColors.warning,
  );
  if (confirmed != true || !context.mounted) return;
  await context.read<InvoiceCubit>().cancelInvoice(invoice);
}

bool _canCancelInvoice(Invoice invoice) {
  return invoice.status != InvoiceStatus.cancelled &&
      invoice.amountPaid <= 0 &&
      invoice.paymentHistory.isEmpty;
}

Future<void> _showRecordPaymentDialog(
  BuildContext context,
  Invoice invoice,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<InvoiceCubit>(),
      child: _RecordPaymentDialog(invoice: invoice),
    ),
  );
}

Future<void> _confirmAndDelete(BuildContext context, Invoice invoice) async {
  final confirmed = await _confirmAction(
    context,
    title: 'Archive invoice?',
    message:
        'This will remove ${invoice.invoiceNumber} from the active invoice list while keeping it in your records.',
    confirmLabel: 'Archive',
    confirmColor: AppColors.error,
  );
  if (confirmed != true || !context.mounted) return;
  await context.read<InvoiceCubit>().deleteInvoice(invoice);
}

Future<bool?> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Color confirmColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep it'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

String _sanitizeFileName(String value) {
  return sanitizeInvoicePdfBaseName(value);
}

enum _InvoiceStatusFilter {
  all('All'),
  draft('Draft'),
  unpaid('Unpaid'),
  partialPaid('Partial'),
  paid('Paid'),
  cancelled('Cancelled'),
  overdue('Overdue');

  const _InvoiceStatusFilter(this.label);

  final String label;

  bool matches(Invoice invoice) {
    return switch (this) {
      _InvoiceStatusFilter.all => true,
      _InvoiceStatusFilter.draft => invoice.status == InvoiceStatus.draft,
      _InvoiceStatusFilter.unpaid => invoice.status == InvoiceStatus.unpaid,
      _InvoiceStatusFilter.partialPaid =>
        invoice.status == InvoiceStatus.partialPaid,
      _InvoiceStatusFilter.paid => invoice.status == InvoiceStatus.paid,
      _InvoiceStatusFilter.cancelled =>
        invoice.status == InvoiceStatus.cancelled,
      _InvoiceStatusFilter.overdue => _isOverdue(invoice),
    };
  }
}

enum _InvoiceDateFilter {
  all('All dates'),
  thisMonth('This month'),
  lastMonth('Last month'),
  dueThisWeek('Due this week');

  const _InvoiceDateFilter(this.label);

  final String label;

  bool matches(Invoice invoice) {
    final today = _dateOnly(DateTime.now());
    return switch (this) {
      _InvoiceDateFilter.all => true,
      _InvoiceDateFilter.thisMonth =>
        invoice.invoiceDate.year == today.year &&
            invoice.invoiceDate.month == today.month,
      _InvoiceDateFilter.lastMonth => _isLastMonth(invoice.invoiceDate, today),
      _InvoiceDateFilter.dueThisWeek => isInvoiceDueThisWeek(
        invoice,
        today: today,
      ),
    };
  }
}

bool _isLastMonth(DateTime value, DateTime today) {
  return isInvoiceFromLastMonth(value, today: today);
}

bool _isOverdue(Invoice invoice) {
  return isInvoiceOverdue(invoice);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _formatDateShort(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({required this.invoice});

  final Invoice invoice;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _method = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _paidAt;

  @override
  void initState() {
    super.initState();
    _paidAt = DateTime.now();
    _amount.text = widget.invoice.balanceDue.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    _method.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Record Payment - ${invoice.invoiceNumber}'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogLine(
                label: 'Outstanding',
                value: invoice.balanceDue.toStringAsFixed(2),
              ),
              if (invoice.paymentHistory.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Existing Payments',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final payment in invoice.paymentHistory)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _DialogLine(
                      label:
                          '${payment.paidAt.day.toString().padLeft(2, '0')}/${payment.paidAt.month.toString().padLeft(2, '0')}/${payment.paidAt.year}'
                          '${payment.method.trim().isNotEmpty ? ' • ${payment.method.trim()}' : ''}',
                      value: payment.amount.toStringAsFixed(2),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount *',
                  prefixIcon: Icon(Icons.currency_rupee_outlined),
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                readOnly: true,
                key: ValueKey(_paidAt.toIso8601String()),
                initialValue:
                    '${_paidAt.day.toString().padLeft(2, '0')}/${_paidAt.month.toString().padLeft(2, '0')}/${_paidAt.year}',
                decoration: const InputDecoration(
                  labelText: 'Payment Date',
                  prefixIcon: Icon(Icons.event_outlined),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _paidAt,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _paidAt = picked);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _method,
                decoration: const InputDecoration(
                  labelText: 'Method',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Reference',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            await context.read<InvoiceCubit>().recordPayment(
              invoice,
              amount: double.tryParse(_amount.text.trim()) ?? 0,
              paidAt: _paidAt,
              method: _method.text.trim(),
              reference: _reference.text.trim(),
              notes: _notes.text.trim(),
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Save Payment'),
        ),
      ],
    );
  }
}

class _DialogLine extends StatelessWidget {
  const _DialogLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
