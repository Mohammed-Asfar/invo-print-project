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
import '../../domain/services/invoice_pdf_service.dart';
import '../cubit/invoice_cubit.dart';
import 'create_invoice_page.dart';

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key});

  static const routePath = '/invoices';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvoiceCubit>()..load(),
      child: const _InvoicesView(),
    );
  }
}

class _InvoicesView extends StatelessWidget {
  const _InvoicesView();

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
        return ColoredBox(
          color: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(state: state),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  onChanged: context.read<InvoiceCubit>().search,
                  decoration: const InputDecoration(
                    labelText: 'Search invoices',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: state.status == InvoiceStatusView.loading
                      ? const Center(child: CircularProgressIndicator())
                      : _InvoiceList(
                          invoices: state.filteredInvoices,
                          settings: state.settings,
                          companyProfile: state.companyProfile,
                        ),
                ),
              ],
            ),
          ),
        );
      },
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

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({
    required this.invoices,
    required this.settings,
    required this.companyProfile,
  });

  final List<Invoice> invoices;
  final AppSettings? settings;
  final CompanyProfile? companyProfile;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(
        child: Text(
          'No invoices yet.',
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
          final customerName =
              invoice.customerSnapshot['name']?.toString() ?? '';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(
                Icons.receipt_outlined,
                color: AppColors.primaryPurple,
              ),
            ),
            title: Text(invoice.invoiceNumber),
            subtitle: Text(
              [
                if (customerName.isNotEmpty) customerName,
                invoice.status.label,
                invoice.taxMode.label,
                if (invoice.balanceDue > 0)
                  'Due ${invoice.balanceDue.toStringAsFixed(2)}',
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
                    switch (action) {
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
                        await _exportPdf(context, invoice);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _InvoiceAction.duplicate,
                      child: Row(
                        children: [
                          Icon(Icons.copy_all_outlined),
                          SizedBox(width: AppSpacing.sm),
                          Text('Duplicate'),
                        ],
                      ),
                    ),
                    if (invoice.status != InvoiceStatus.cancelled)
                      if (invoice.balanceDue > 0)
                        const PopupMenuItem(
                          value: _InvoiceAction.recordPayment,
                          child: Row(
                            children: [
                              Icon(Icons.payments_outlined),
                              SizedBox(width: AppSpacing.sm),
                              Text('Record Payment'),
                            ],
                          ),
                        ),
                    if (invoice.status != InvoiceStatus.cancelled)
                      const PopupMenuItem(
                        value: _InvoiceAction.cancel,
                        child: Row(
                          children: [
                            Icon(Icons.block_outlined),
                            SizedBox(width: AppSpacing.sm),
                            Text('Cancel invoice'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: _InvoiceAction.exportPdf,
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_outlined),
                          SizedBox(width: AppSpacing.sm),
                          Text('Export PDF'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _InvoiceAction.delete,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.error),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(Icons.more_horiz, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, Invoice invoice) async {
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
      confirmLabel: 'Cancel Invoice',
      confirmColor: AppColors.warning,
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<InvoiceCubit>().cancelInvoice(invoice);
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
      title: 'Delete invoice?',
      message:
          'This will permanently remove ${invoice.invoiceNumber} from the invoice list.',
      confirmLabel: 'Delete',
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
    final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
    return sanitized.isEmpty ? 'invoice' : sanitized;
  }
}

enum _InvoiceAction { duplicate, recordPayment, cancel, exportPdf, delete }

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
