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

enum _InvoiceAction { duplicate, cancel, exportPdf, delete }
