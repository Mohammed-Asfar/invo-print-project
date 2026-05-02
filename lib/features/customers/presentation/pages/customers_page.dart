import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/customer.dart';
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
