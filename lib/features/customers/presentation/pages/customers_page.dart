import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/customer.dart';
import '../../domain/services/customer_csv_export.dart';
import '../../domain/services/customer_follow_up.dart';
import '../../domain/services/customer_ledger.dart';
import '../../domain/services/customer_statement_pdf_service.dart';
import '../cubit/customer_cubit.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  static const routePath = '/customers';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerCubit>()..load(),
      child: const _CustomersView(),
    );
  }
}

class _CustomersView extends StatelessWidget {
  const _CustomersView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerCubit, CustomerState>(
      listener: (context, state) {
        if (state.status == CustomerStatus.failure ||
            state.status == CustomerStatus.saved) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message ?? 'Done'),
                backgroundColor: state.status == CustomerStatus.failure
                    ? AppColors.error
                    : AppColors.success,
              ),
            );
        }
      },
      builder: (context, state) {
        final filteredCustomers = state.filteredCustomers;
        final followUpQueue = buildCustomerFollowUpQueue(
          customers: state.customers,
          invoices: state.invoices,
        );
        return ColoredBox(
          color: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customers',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Manage customer profiles for invoices, quotations, and loyalty history.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: state.isBusy
                          ? null
                          : () => _showCustomerSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('New Customer'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: state.isBusy || followUpQueue.rows.isEmpty
                          ? null
                          : () => _exportFollowUpsCsv(context, followUpQueue),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Export Follow-ups'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: state.isBusy || filteredCustomers.isEmpty
                          ? null
                          : () =>
                                _exportCustomersCsv(context, filteredCustomers),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  onChanged: context.read<CustomerCubit>().search,
                  decoration: const InputDecoration(
                    labelText: 'Search customers',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (followUpQueue.rows.isNotEmpty) ...[
                  _CustomerFollowUpPanel(
                    queue: followUpQueue,
                    onUpdateCustomer: (customer) =>
                        _showFollowUpDialog(context, customer),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                Expanded(
                  child: state.status == CustomerStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : _CustomerTable(customers: filteredCustomers),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportCustomersCsv(
    BuildContext context,
    List<Customer> customers,
  ) async {
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save customers CSV',
        fileName: 'customers.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null) return;
      await File(path).writeAsString(buildCustomersCsv(customers), flush: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Customers exported.'),
            backgroundColor: AppColors.success,
          ),
        );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Could not export customers.'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _exportFollowUpsCsv(
    BuildContext context,
    CustomerFollowUpQueue queue,
  ) async {
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save customer follow-up CSV',
        fileName: 'customer-follow-ups.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null) return;
      await File(
        path,
      ).writeAsString(buildCustomerFollowUpCsv(queue), flush: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Customer follow-up queue exported.'),
            backgroundColor: AppColors.success,
          ),
        );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Could not export customer follow-ups.'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  void _showCustomerSheet(BuildContext context, {Customer? customer}) {
    final globalLoyaltyEnabled = context
        .read<CustomerCubit>()
        .state
        .globalLoyaltyEnabled;
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerCubit>(),
        child: _CustomerDialog(
          customer: customer,
          globalLoyaltyEnabled: globalLoyaltyEnabled,
        ),
      ),
    );
  }

  void _showFollowUpDialog(BuildContext context, Customer customer) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerCubit>(),
        child: _CustomerFollowUpDialog(customer: customer),
      ),
    );
  }
}

class _CustomerTable extends StatelessWidget {
  const _CustomerTable({required this.customers});

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return Center(
        child: Text(
          'No customers yet.',
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
        itemCount: customers.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, thickness: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final customer = customers[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(customer.name),
            subtitle: Text(
              [
                if (customer.phone.isNotEmpty) customer.phone,
                if (customer.email.isNotEmpty) customer.email,
                if (customer.gstin.isNotEmpty) 'GSTIN ${customer.gstin}',
                if (customer.followUpStatus != CustomerFollowUpStatus.none)
                  customer.followUpStatus.label,
              ].join('  |  '),
            ),
            trailing: Wrap(
              spacing: AppSpacing.sm,
              children: [
                IconButton(
                  tooltip: 'Follow-up',
                  onPressed: () => _showFollowUpDialog(context, customer),
                  icon: const Icon(Icons.campaign_outlined),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _showCustomerSheet(context, customer),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Ledger',
                  onPressed: () => _showLedgerDialog(context, customer),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                IconButton(
                  tooltip: 'Archive',
                  onPressed: () =>
                      context.read<CustomerCubit>().archive(customer),
                  icon: const Icon(Icons.archive_outlined),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCustomerSheet(BuildContext context, Customer customer) {
    final globalLoyaltyEnabled = context
        .read<CustomerCubit>()
        .state
        .globalLoyaltyEnabled;
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerCubit>(),
        child: _CustomerDialog(
          customer: customer,
          globalLoyaltyEnabled: globalLoyaltyEnabled,
        ),
      ),
    );
  }

  void _showLedgerDialog(BuildContext context, Customer customer) {
    final ledger = context.read<CustomerCubit>().ledgerFor(customer);
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerCubit>(),
        child: _CustomerLedgerDialog(ledger: ledger),
      ),
    );
  }

  void _showFollowUpDialog(BuildContext context, Customer customer) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerCubit>(),
        child: _CustomerFollowUpDialog(customer: customer),
      ),
    );
  }
}

class _CustomerFollowUpPanel extends StatelessWidget {
  const _CustomerFollowUpPanel({
    required this.queue,
    required this.onUpdateCustomer,
  });

  final CustomerFollowUpQueue queue;
  final ValueChanged<Customer> onUpdateCustomer;

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
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _LedgerMetric(
                label: 'Action Queue',
                value: queue.actionCount.toString(),
                highlight: queue.actionCount > 0,
              ),
              _LedgerMetric(
                label: 'Overdue Customers',
                value: queue.overdueCustomerCount.toString(),
                highlight: queue.overdueCustomerCount > 0,
              ),
              _LedgerMetric(
                label: 'Reminders Due',
                value: queue.reminderDueCount.toString(),
                highlight: queue.reminderDueCount > 0,
              ),
              _LedgerMetric(
                label: 'Overdue Amount',
                value: _formatMoney(queue.totalOverdueAmount),
                highlight: queue.totalOverdueAmount > 0,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Customer Follow-up Queue',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in queue.rows.take(6))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: row.needsAction
                    ? AppColors.primaryLight
                    : AppColors.background,
                child: Icon(
                  row.reminderDue
                      ? Icons.notifications_active_outlined
                      : row.overdueAmount > 0
                      ? Icons.warning_amber_outlined
                      : Icons.schedule_outlined,
                  color: row.reminderDue || row.overdueAmount > 0
                      ? AppColors.primaryPurple
                      : AppColors.textSecondary,
                ),
              ),
              title: Text(row.customer.name),
              subtitle: Text(
                [
                  row.customer.followUpStatus.label,
                  if (row.customer.lastContactedAt != null)
                    'Last contacted ${_formatDate(row.customer.lastContactedAt!)}',
                  if (row.customer.nextFollowUpDate != null)
                    'Next follow-up ${_formatDate(row.customer.nextFollowUpDate!)}',
                  if (row.overdueInvoiceCount > 0)
                    '${row.overdueInvoiceCount} overdue invoice${row.overdueInvoiceCount == 1 ? '' : 's'}',
                ].join('  |  '),
              ),
              trailing: SizedBox(
                width: 220,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Due ${_formatMoney(row.outstandingBalance)}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (row.overdueAmount > 0)
                            Text(
                              'Overdue ${_formatMoney(row.overdueAmount)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.error),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => onUpdateCustomer(row.customer),
                      child: const Text('Update'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomerLedgerDialog extends StatelessWidget {
  const _CustomerLedgerDialog({required this.ledger});

  final CustomerLedger ledger;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('${ledger.customer.name} Ledger'),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _LedgerMetric(
                    label: 'Total Invoiced',
                    value: _formatMoney(ledger.totalInvoiced),
                  ),
                  _LedgerMetric(
                    label: 'Total Paid',
                    value: _formatMoney(ledger.totalPaid),
                  ),
                  _LedgerMetric(
                    label: 'Credits',
                    value: _formatMoney(ledger.totalCredited),
                  ),
                  _LedgerMetric(
                    label: 'Outstanding',
                    value: _formatMoney(ledger.outstandingBalance),
                    highlight: ledger.outstandingBalance > 0,
                  ),
                  _LedgerMetric(
                    label: 'Customer Credit',
                    value: _formatMoney(ledger.creditBalance),
                    highlight: ledger.creditBalance > 0,
                  ),
                  _LedgerMetric(
                    label: 'Loyalty Points',
                    value: ledger.loyaltyPoints.toString(),
                  ),
                ],
              ),
              if (ledger.customer.followUpStatus !=
                      CustomerFollowUpStatus.none ||
                  ledger.customer.lastContactedAt != null ||
                  ledger.customer.nextFollowUpDate != null ||
                  ledger.customer.followUpNotes.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Follow-up',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ledger.customer.followUpStatus.label),
                  subtitle: Text(
                    [
                      if (ledger.customer.lastContactedAt != null)
                        'Last contacted ${_formatDate(ledger.customer.lastContactedAt!)}',
                      if (ledger.customer.nextFollowUpDate != null)
                        'Next follow-up ${_formatDate(ledger.customer.nextFollowUpDate!)}',
                      if (ledger.customer.followUpNotes.trim().isNotEmpty)
                        ledger.customer.followUpNotes.trim(),
                    ].join('  |  '),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Invoice History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (ledger.invoices.isEmpty)
                Text(
                  'No invoice history yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                _LedgerTable(
                  headers: const [
                    'Invoice',
                    'Date',
                    'Status',
                    'Total',
                    'Paid',
                    'Credits',
                    'Balance',
                  ],
                  rows: [
                    for (final invoice in ledger.invoices)
                      [
                        invoice.invoiceNumber,
                        _formatDate(invoice.invoiceDate),
                        invoice.status.label,
                        _formatMoney(invoice.grandTotal),
                        _formatMoney(invoice.amountPaid),
                        _formatMoney(invoice.creditTotal),
                        _formatMoney(invoice.balanceDue),
                      ],
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Timeline',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (ledger.entries.isEmpty)
                Text(
                  'No ledger entries yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                _LedgerTable(
                  headers: const [
                    'Date',
                    'Type',
                    'Reference',
                    'Amount',
                    'Info',
                  ],
                  rows: [
                    for (final entry in ledger.entries)
                      [
                        _formatDate(entry.date),
                        entry.type.label,
                        entry.reference,
                        _formatMoney(entry.amount),
                        entry.description,
                      ],
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: () => _showFollowUpDialog(context),
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('Update Follow-up'),
        ),
        ElevatedButton.icon(
          onPressed: () => _exportStatement(context),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Export Statement'),
        ),
      ],
    );
  }

  Future<void> _exportStatement(BuildContext context) async {
    final selection = await showDialog<_CustomerStatementExportSelection>(
      context: context,
      builder: (_) => const _CustomerStatementExportDialog(),
    );
    if (selection == null || !context.mounted) return;
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save customer statement PDF',
      fileName:
          '${ledger.customer.name.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').toLowerCase()}-statement.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (path == null || !context.mounted) return;
    final bytes = await sl<CustomerStatementPdfService>().buildStatementPdf(
      customer: ledger.customer,
      ledger: ledger,
      asOfDate: selection.toDate ?? DateTime.now(),
      fromDate: selection.fromDate,
      toDate: selection.toDate,
    );
    await File(path).writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Customer statement exported.'),
          backgroundColor: AppColors.success,
        ),
      );
  }

  void _showFollowUpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<CustomerCubit>(),
        child: _CustomerFollowUpDialog(customer: ledger.customer),
      ),
    );
  }
}

class _LedgerMetric extends StatelessWidget {
  const _LedgerMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primaryPurple : AppColors.textPrimary;
    return Container(
      width: 178,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? AppColors.primaryPurple : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: {
          for (var index = 0; index < headers.length; index++)
            index: const FlexColumnWidth(),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: AppColors.border),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(color: AppColors.background),
            children: [
              for (final header in headers) _LedgerCell(header, strong: true),
            ],
          ),
          for (final row in rows)
            TableRow(children: [for (final value in row) _LedgerCell(value)]),
        ],
      ),
    );
  }
}

class _LedgerCell extends StatelessWidget {
  const _LedgerCell(this.value, {this.strong = false});

  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Text(
        value,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: strong ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _CustomerFollowUpDialog extends StatefulWidget {
  const _CustomerFollowUpDialog({required this.customer});

  final Customer customer;

  @override
  State<_CustomerFollowUpDialog> createState() =>
      _CustomerFollowUpDialogState();
}

class _CustomerFollowUpDialogState extends State<_CustomerFollowUpDialog> {
  final _formKey = GlobalKey<FormState>();
  late CustomerFollowUpStatus _status;
  late TextEditingController _notes;
  DateTime? _lastContactedAt;
  DateTime? _nextFollowUpDate;

  @override
  void initState() {
    super.initState();
    _status = widget.customer.followUpStatus;
    _notes = TextEditingController(text: widget.customer.followUpNotes);
    _lastContactedAt = widget.customer.lastContactedAt;
    _nextFollowUpDate = widget.customer.nextFollowUpDate;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Customer Follow-up: ${widget.customer.name}'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CustomerFollowUpStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Reminder Status',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: CustomerFollowUpStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _CustomerDatePickerField(
                  label: 'Last Contacted',
                  value: _lastContactedAt,
                  onChanged: (value) =>
                      setState(() => _lastContactedAt = value),
                ),
                const SizedBox(height: AppSpacing.md),
                _CustomerDatePickerField(
                  label: 'Next Follow-up',
                  value: _nextFollowUpDate,
                  onChanged: (value) =>
                      setState(() => _nextFollowUpDate = value),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notes,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Notes',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final customer = widget.customer.copyWith(
      followUpStatus: _status,
      lastContactedAt: _lastContactedAt,
      clearLastContactedAt: _lastContactedAt == null,
      nextFollowUpDate: _nextFollowUpDate,
      clearNextFollowUpDate: _nextFollowUpDate == null,
      followUpNotes: _notes.text.trim(),
      updatedAt: DateTime.now(),
    );
    context.read<CustomerCubit>().save(customer);
    Navigator.of(context).pop();
  }
}

class _CustomerStatementExportSelection {
  const _CustomerStatementExportSelection({this.fromDate, this.toDate});

  final DateTime? fromDate;
  final DateTime? toDate;
}

class _CustomerStatementExportDialog extends StatefulWidget {
  const _CustomerStatementExportDialog();

  @override
  State<_CustomerStatementExportDialog> createState() =>
      _CustomerStatementExportDialogState();
}

class _CustomerStatementExportDialogState
    extends State<_CustomerStatementExportDialog> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Customer Statement'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose an activity period for the statement timeline. Open invoice balances will still be shown as of the selected end date.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _CustomerDatePickerField(
              label: 'From Date',
              value: _fromDate,
              onChanged: (value) => setState(() => _fromDate = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _CustomerDatePickerField(
              label: 'To Date',
              value: _toDate,
              onChanged: (value) => setState(() => _toDate = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _fromDate = null;
              _toDate = null;
            });
          },
          child: const Text('Clear'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Continue'),
        ),
      ],
    );
  }

  void _save() {
    if (_fromDate != null && _toDate != null && _fromDate!.isAfter(_toDate!)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('From date cannot be after to date.'),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }
    Navigator.of(context).pop(
      _CustomerStatementExportSelection(fromDate: _fromDate, toDate: _toDate),
    );
  }
}

class _CustomerDatePickerField extends StatelessWidget {
  const _CustomerDatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              onChanged(picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: const Icon(Icons.event_outlined),
              ),
              child: Text(value == null ? 'Not set' : _formatDate(value!)),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: value == null ? null : () => onChanged(null),
          tooltip: 'Clear date',
          icon: const Icon(Icons.clear_outlined),
        ),
      ],
    );
  }
}

String _formatMoney(double value) {
  final prefix = value < 0 ? '-' : '';
  return '$prefix${value.abs().toStringAsFixed(2)}';
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog({required this.globalLoyaltyEnabled, this.customer});

  final Customer? customer;
  final bool globalLoyaltyEnabled;

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _billingAddress = TextEditingController();
  final _shippingAddress = TextEditingController();
  final _gstin = TextEditingController();
  final _state = TextEditingController();
  final _discountValue = TextEditingController();
  final _notes = TextEditingController();
  final _defaultInvoiceTerms = TextEditingController();
  bool _loyaltyEnabled = true;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer != null) {
      _name.text = customer.name;
      _phone.text = customer.phone;
      _email.text = customer.email;
      _billingAddress.text = customer.billingAddress;
      _shippingAddress.text = customer.shippingAddress;
      _gstin.text = customer.gstin;
      _state.text = customer.state;
      _discountValue.text = customer.defaultDiscountValue.toString();
      _notes.text = customer.notes;
      _defaultInvoiceTerms.text = customer.defaultInvoiceTerms;
      _loyaltyEnabled = customer.loyaltyEnabled;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _email,
      _billingAddress,
      _shippingAddress,
      _gstin,
      _state,
      _discountValue,
      _notes,
      _defaultInvoiceTerms,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'New Customer' : 'Edit Customer'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [
                _DialogField(_name, 'Customer Name', required: true),
                _DialogField(_phone, 'Phone'),
                _DialogField(_email, 'Email'),
                _DialogField(_gstin, 'GSTIN'),
                _DialogField(_state, 'State'),
                _DialogField(_discountValue, 'Default Discount', numeric: true),
                _DialogField(_billingAddress, 'Billing Address', maxLines: 3),
                _DialogField(_shippingAddress, 'Shipping Address', maxLines: 3),
                _DialogField(
                  _defaultInvoiceTerms,
                  'Default Invoice Terms',
                  maxLines: 3,
                ),
                _DialogField(_notes, 'Notes', maxLines: 3),
                if (widget.globalLoyaltyEnabled)
                  SizedBox(
                    width: 330,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Loyalty Enabled'),
                      value: _loyaltyEnabled,
                      onChanged: (value) =>
                          setState(() => _loyaltyEnabled = value),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.customer ?? Customer.empty();
    context.read<CustomerCubit>().save(
      existing.copyWith(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        billingAddress: _billingAddress.text.trim(),
        shippingAddress: _shippingAddress.text.trim(),
        gstin: _gstin.text.trim(),
        state: _state.text.trim(),
        defaultDiscountType: _doubleValue(_discountValue) > 0
            ? 'percentage'
            : 'none',
        defaultDiscountValue: _doubleValue(_discountValue),
        loyaltyEnabled: widget.globalLoyaltyEnabled && _loyaltyEnabled,
        notes: _notes.text.trim(),
        defaultInvoiceTerms: _defaultInvoiceTerms.text.trim(),
        isActive: true,
        updatedAt: DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
  }

  double _doubleValue(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField(
    this.controller,
    this.label, {
    this.required = false,
    this.numeric = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool numeric;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxLines > 1 ? 680 : 330,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return '$label is required';
          if (numeric && text.isNotEmpty && double.tryParse(text) == null) {
            return 'Enter a valid number';
          }
          return null;
        },
      ),
    );
  }
}
