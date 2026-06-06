import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/entities/invoice_item.dart';
import '../../../invoices/domain/services/invoice_calculator.dart';
import '../../../invoices/presentation/pages/create_invoice_page.dart';
import '../../domain/entities/quotation.dart';
import '../../domain/services/quotation_pdf_service.dart';
import '../cubit/quotation_cubit.dart';

class QuotationsPage extends StatelessWidget {
  const QuotationsPage({super.key});

  static const routePath = '/quotations';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<QuotationCubit>()..load(),
      child: const _QuotationsView(),
    );
  }
}

class _QuotationsView extends StatelessWidget {
  const _QuotationsView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<QuotationCubit, QuotationState>(
      listener: (context, state) {
        if (state.status == QuotationViewStatus.failure ||
            state.status == QuotationViewStatus.saved) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message ?? 'Done'),
                backgroundColor: state.status == QuotationViewStatus.failure
                    ? AppColors.error
                    : AppColors.success,
              ),
            );
        }
      },
      builder: (context, state) {
        final quotations = state.filteredQuotations;
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
                  onChanged: context.read<QuotationCubit>().search,
                  decoration: const InputDecoration(
                    labelText: 'Search quotations',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: state.status == QuotationViewStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : _QuotationList(quotations: quotations),
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

  final QuotationState state;

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
              Icons.request_quote_outlined,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quotations',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Prepare estimates, export quote PDFs, and convert accepted quotes into invoices.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: state.isBusy
                ? null
                : () => _showQuotationDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New Quotation'),
          ),
        ],
      ),
    );
  }

  void _showQuotationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<QuotationCubit>(),
        child: const _QuotationDialog(),
      ),
    );
  }
}

class _QuotationList extends StatelessWidget {
  const _QuotationList({required this.quotations});

  final List<Quotation> quotations;

  @override
  Widget build(BuildContext context) {
    if (quotations.isEmpty) {
      return Center(
        child: Text(
          'No quotations yet.',
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
        itemCount: quotations.length,
        separatorBuilder: (_, _) => Divider(color: AppColors.border, height: 1),
        itemBuilder: (context, index) {
          final quotation = quotations[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(
                Icons.request_quote_outlined,
                color: AppColors.primaryPurple,
              ),
            ),
            title: Text(
              quotation.quotationNumber.trim().isEmpty
                  ? 'Draft quotation'
                  : quotation.quotationNumber,
            ),
            subtitle: Text(
              [
                quotation.customerName.isEmpty
                    ? 'No customer'
                    : quotation.customerName,
                quotation.status.label,
                'Valid ${_formatDate(quotation.validUntil)}',
              ].join('  |  '),
            ),
            trailing: SizedBox(
              width: 420,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    quotation.grandTotal.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  PopupMenuButton<_QuotationAction>(
                    tooltip: 'Actions',
                    onSelected: (action) =>
                        _runAction(context, quotation, action),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _QuotationAction.edit,
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: _QuotationAction.exportPdf,
                        child: Text('Export PDF'),
                      ),
                      const PopupMenuItem(
                        value: _QuotationAction.convert,
                        child: Text('Convert to invoice'),
                      ),
                      if (quotation.status != QuotationStatus.accepted)
                        const PopupMenuItem(
                          value: _QuotationAction.accept,
                          child: Text('Mark accepted'),
                        ),
                      if (quotation.status != QuotationStatus.rejected)
                        const PopupMenuItem(
                          value: _QuotationAction.reject,
                          child: Text('Mark rejected'),
                        ),
                      const PopupMenuItem(
                        value: _QuotationAction.archive,
                        child: Text('Archive'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Quotation quotation,
    _QuotationAction action,
  ) async {
    switch (action) {
      case _QuotationAction.edit:
        showDialog<void>(
          context: context,
          builder: (_) => BlocProvider.value(
            value: context.read<QuotationCubit>(),
            child: _QuotationDialog(quotation: quotation),
          ),
        );
        break;
      case _QuotationAction.exportPdf:
        await _exportPdf(context, quotation);
        break;
      case _QuotationAction.convert:
        final invoice = context.read<QuotationCubit>().toInvoiceSource(
          quotation,
        );
        context.go(
          CreateInvoicePage.routePath,
          extra: CreateInvoicePageArgs.duplicate(invoice),
        );
        break;
      case _QuotationAction.accept:
        await context.read<QuotationCubit>().updateStatus(
          quotation,
          QuotationStatus.accepted,
        );
        break;
      case _QuotationAction.reject:
        await context.read<QuotationCubit>().updateStatus(
          quotation,
          QuotationStatus.rejected,
        );
        break;
      case _QuotationAction.archive:
        await context.read<QuotationCubit>().archive(quotation);
        break;
    }
  }

  Future<void> _exportPdf(BuildContext context, Quotation quotation) async {
    final state = context.read<QuotationCubit>().state;
    final fileName =
        '${_sanitizeFileName(quotation.quotationNumber.trim().isEmpty ? 'quotation' : quotation.quotationNumber)}.pdf';
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save quotation PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (path == null || path.trim().isEmpty) return;
    final bytes = await sl<QuotationPdfService>().buildQuotationPdf(
      quotation: quotation,
      currencySymbol: state.settings?.currencySymbol ?? 'Rs',
      currentCompanyProfile: state.companyProfile,
      settings: state.settings,
    );
    await File(path).writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Quotation PDF exported.'),
          backgroundColor: AppColors.success,
        ),
      );
  }
}

class _QuotationDialog extends StatefulWidget {
  const _QuotationDialog({this.quotation});

  final Quotation? quotation;

  @override
  State<_QuotationDialog> createState() => _QuotationDialogState();
}

class _QuotationDialogState extends State<_QuotationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  final _state = TextEditingController();
  final _billingAddress = TextEditingController();
  final _discountValue = TextEditingController();
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  final _items = <_QuotationItemControllers>[];
  Customer? _selectedCustomer;
  late DateTime _quotationDate;
  late DateTime _validUntil;
  TaxMode _taxMode = TaxMode.cgstSgst;
  QuotationStatus _status = QuotationStatus.sent;
  bool _roundOffEnabled = false;
  String _discountType = 'none';

  @override
  void initState() {
    super.initState();
    final quotation = widget.quotation;
    _quotationDate = quotation?.quotationDate ?? DateTime.now();
    _validUntil =
        quotation?.validUntil ?? DateTime.now().add(const Duration(days: 15));
    if (quotation == null) {
      _items.add(_QuotationItemControllers());
      return;
    }
    final snapshot = quotation.customerSnapshot;
    _customerName.text = snapshot['name']?.toString() ?? '';
    _phone.text = snapshot['phone']?.toString() ?? '';
    _email.text = snapshot['email']?.toString() ?? '';
    _gstin.text = snapshot['gstin']?.toString() ?? '';
    _state.text = snapshot['state']?.toString() ?? '';
    _billingAddress.text = snapshot['billingAddress']?.toString() ?? '';
    _taxMode = quotation.taxMode;
    _status = quotation.status;
    _roundOffEnabled = quotation.roundOffEnabled;
    _discountType = quotation.discountType;
    _discountValue.text = quotation.discountValue == 0
        ? ''
        : quotation.discountValue.toString();
    _notes.text = quotation.notes;
    _terms.text = quotation.terms;
    _items.addAll(quotation.items.map(_QuotationItemControllers.fromItem));
    if (_items.isEmpty) _items.add(_QuotationItemControllers());
  }

  @override
  void dispose() {
    for (final controller in [
      _customerName,
      _phone,
      _email,
      _gstin,
      _state,
      _billingAddress,
      _discountValue,
      _notes,
      _terms,
    ]) {
      controller.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = context.select(
      (QuotationCubit cubit) => cubit.state.customers,
    );
    final totals = InvoiceCalculator().calculate(
      items: _items.map((item) => item.toItem()).toList(),
      taxMode: _taxMode,
      roundOffEnabled: _roundOffEnabled,
      discountType: _discountType,
      discountValue: _double(_discountValue),
    );
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        widget.quotation == null ? 'New Quotation' : 'Edit Quotation',
      ),
      content: SizedBox(
        width: 900,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedCustomer?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Existing Customer',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Manual customer entry'),
                    ),
                    for (final customer in customers)
                      DropdownMenuItem<String>(
                        value: customer.id,
                        child: Text(customer.name),
                      ),
                  ],
                  onChanged: (value) {
                    final customer = customers
                        .where((entry) => entry.id == value)
                        .firstOrNull;
                    setState(() {
                      _selectedCustomer = customer;
                      if (customer != null) {
                        _customerName.text = customer.name;
                        _phone.text = customer.phone;
                        _email.text = customer.email;
                        _gstin.text = customer.gstin;
                        _state.text = customer.state;
                        _billingAddress.text = customer.billingAddress;
                      }
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    _Field(_customerName, 'Customer Name *'),
                    _Field(_phone, 'Phone'),
                    _Field(_email, 'Email'),
                    _Field(_gstin, 'GSTIN'),
                    _Field(_state, 'State'),
                    _Field(_billingAddress, 'Billing Address', wide: true),
                    _DateField(
                      label: 'Quotation Date',
                      value: _quotationDate,
                      onChanged: (value) =>
                          setState(() => _quotationDate = value),
                    ),
                    _DateField(
                      label: 'Valid Until',
                      value: _validUntil,
                      onChanged: (value) => setState(() => _validUntil = value),
                    ),
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<TaxMode>(
                        initialValue: _taxMode,
                        decoration: const InputDecoration(
                          labelText: 'Tax Mode',
                          prefixIcon: Icon(Icons.tune_outlined),
                        ),
                        items: [
                          for (final mode in TaxMode.values)
                            DropdownMenuItem(
                              value: mode,
                              child: Text(mode.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _taxMode = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<QuotationStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: [
                          for (final status in QuotationStatus.values)
                            DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _status = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                        initialValue: _discountType,
                        decoration: const InputDecoration(
                          labelText: 'Discount Type',
                          prefixIcon: Icon(Icons.percent_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'none',
                            child: Text('No discount'),
                          ),
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Percentage'),
                          ),
                          DropdownMenuItem(
                            value: 'amount',
                            child: Text('Amount'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _discountType = value);
                          }
                        },
                      ),
                    ),
                    _Field(_discountValue, 'Discount Value', numeric: true),
                    SizedBox(
                      width: 260,
                      child: SwitchListTile(
                        value: _roundOffEnabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Round off'),
                        onChanged: (value) =>
                            setState(() => _roundOffEnabled = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => setState(
                        () => _items.add(_QuotationItemControllers()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var index = 0; index < _items.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ItemRow(
                      item: _items[index],
                      onChanged: () => setState(() {}),
                      onDelete: _items.length == 1
                          ? null
                          : () => setState(() {
                              final removed = _items.removeAt(index);
                              removed.dispose();
                            }),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    _Field(_notes, 'Notes', wide: true, maxLines: 3),
                    _Field(_terms, 'Terms', wide: true, maxLines: 3),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total ${totals.grandTotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
    if (!_formKey.currentState!.validate()) return;
    context.read<QuotationCubit>().saveQuotation(
      existing: widget.quotation,
      customerName: _customerName.text.trim(),
      customerPhone: _phone.text.trim(),
      customerEmail: _email.text.trim(),
      customerGstin: _gstin.text.trim(),
      customerState: _state.text.trim(),
      billingAddress: _billingAddress.text.trim(),
      quotationDate: _quotationDate,
      validUntil: _validUntil,
      taxMode: _taxMode,
      status: _status,
      roundOffEnabled: _roundOffEnabled,
      discountType: _discountType,
      discountValue: _double(_discountValue),
      extraCharges: const [],
      items: _items.map((item) => item.toItem()).toList(),
      notes: _notes.text.trim(),
      terms: _terms.text.trim(),
      selectedCustomer: _selectedCustomer,
    );
    Navigator.of(context).pop();
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  final _QuotationItemControllers item;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    for (final controller in item.controllers) {
      controller.removeListener(onChanged);
      controller.addListener(onChanged);
    }
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Field(item.name, 'Item Name *', width: 280),
        _Field(item.hsn, 'HSN/SAC', width: 120),
        _Field(item.quantity, 'Qty', width: 100, numeric: true),
        _Field(item.unit, 'Unit', width: 120),
        _Field(item.rate, 'Rate', width: 140, numeric: true),
        _Field(item.gstRate, 'GST %', width: 120, numeric: true),
        IconButton(
          onPressed: onDelete,
          tooltip: 'Remove item',
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(
    this.controller,
    this.label, {
    this.numeric = false,
    this.wide = false,
    this.maxLines = 1,
    this.width,
  });

  final TextEditingController controller;
  final String label;
  final bool numeric;
  final bool wide;
  final int maxLines;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? (wide ? 820 : 260),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (label.contains('*') && text.isEmpty) {
            return '${label.replaceAll('*', '').trim()} is required';
          }
          if (numeric && text.isNotEmpty && double.tryParse(text) == null) {
            return 'Enter a valid number';
          }
          return null;
        },
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.event_outlined),
          ),
          child: Text(_formatDate(value)),
        ),
      ),
    );
  }
}

class _QuotationItemControllers {
  _QuotationItemControllers()
    : name = TextEditingController(),
      hsn = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      unit = TextEditingController(text: 'service'),
      rate = TextEditingController(),
      gstRate = TextEditingController(text: '18');

  _QuotationItemControllers.fromItem(InvoiceItem item)
    : name = TextEditingController(text: item.name),
      hsn = TextEditingController(text: item.hsnSac),
      quantity = TextEditingController(text: _num(item.quantity)),
      unit = TextEditingController(text: item.unit),
      rate = TextEditingController(text: _num(item.rate)),
      gstRate = TextEditingController(text: _num(item.gstRate));

  final TextEditingController name;
  final TextEditingController hsn;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController rate;
  final TextEditingController gstRate;

  List<TextEditingController> get controllers => [
    name,
    hsn,
    quantity,
    unit,
    rate,
    gstRate,
  ];

  InvoiceItem toItem() {
    return InvoiceItem.empty().copyWith(
      name: name.text.trim(),
      hsnSac: hsn.text.trim(),
      quantity: double.tryParse(quantity.text.trim()) ?? 0,
      unit: unit.text.trim(),
      rate: double.tryParse(rate.text.trim()) ?? 0,
      gstRate: double.tryParse(gstRate.text.trim()) ?? 0,
    );
  }

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  static String _num(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

enum _QuotationAction { edit, exportPdf, convert, accept, reject, archive }

double _double(TextEditingController controller) {
  return double.tryParse(controller.text.trim()) ?? 0;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _sanitizeFileName(String value) {
  final sanitized = value.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-').trim();
  return sanitized.isEmpty ? 'quotation' : sanitized;
}
