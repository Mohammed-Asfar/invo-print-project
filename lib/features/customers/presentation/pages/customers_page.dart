import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/customer.dart';
import '../../domain/services/customer_ledger.dart';
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
                Expanded(
                  child: state.status == CustomerStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : _CustomerTable(customers: state.filteredCustomers),
                ),
              ],
            ),
          ),
        );
      },
    );
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
              ].join('  |  '),
            ),
            trailing: Wrap(
              spacing: AppSpacing.sm,
              children: [
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
      builder: (_) => _CustomerLedgerDialog(ledger: ledger),
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
      ],
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
      Customer(
        id: existing.id,
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
        loyaltyPointsBalance: existing.loyaltyPointsBalance,
        lifetimePointsEarned: existing.lifetimePointsEarned,
        lifetimePointsRedeemed: existing.lifetimePointsRedeemed,
        totalBilled: existing.totalBilled,
        totalPaid: existing.totalPaid,
        outstandingAmount: existing.outstandingAmount,
        lastInvoiceAt: existing.lastInvoiceAt,
        notes: _notes.text.trim(),
        defaultInvoiceTerms: _defaultInvoiceTerms.text.trim(),
        isActive: true,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        customFields: existing.customFields,
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
