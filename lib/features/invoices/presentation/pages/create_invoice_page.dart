import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../products/domain/entities/product_service.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_draft.dart';
import '../../domain/entities/invoice_item.dart';
import '../cubit/invoice_cubit.dart';
import 'invoices_page.dart';

class CreateInvoicePage extends StatelessWidget {
  const CreateInvoicePage({super.key});

  static const routePath = '/invoices/new';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvoiceCubit>()..load(),
      child: const _CreateInvoiceView(),
    );
  }
}

class _CreateInvoiceView extends StatefulWidget {
  const _CreateInvoiceView();

  @override
  State<_CreateInvoiceView> createState() => _CreateInvoiceViewState();
}

class _CreateInvoiceViewState extends State<_CreateInvoiceView> {
  final _formKey = GlobalKey<FormState>();
  final _customerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  final _state = TextEditingController();
  final _billingAddress = TextEditingController();
  final _shippingAddress = TextEditingController();
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  final Map<String, TextEditingController> _customerCustomFields = {};
  late TaxMode _taxMode;
  late InvoiceStatus _status;
  late DateTime _invoiceDate;
  late DateTime _dueDate;
  late List<_ItemControllers> _items;
  Customer? _selectedCustomer;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _seedFromDraft(InvoiceDraft.initial());
    for (final controller in [
      _customerName,
      _phone,
      _email,
      _gstin,
      _state,
      _billingAddress,
      _shippingAddress,
      _notes,
      _terms,
      ..._customerCustomFields.values,
    ]) {
      controller.addListener(_refresh);
    }
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
      _shippingAddress,
      _notes,
      _terms,
      ..._customerCustomFields.values,
    ]) {
      controller
        ..removeListener(_refresh)
        ..dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvoiceCubit, InvoiceState>(
      listener: (context, state) {
        if (state.status == InvoiceStatusView.saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message ?? 'Invoice saved.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(InvoicesPage.routePath);
        }
        if (state.status == InvoiceStatusView.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message ?? 'Unable to save invoice.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (!_seeded && state.draft != null) {
          for (final item in _items) {
            item.dispose();
          }
          _seedFromDraft(state.draft!);
          _seeded = true;
        }

        final totals = _calculateTotals();
        final invoiceNumber = _invoiceNumberPreview(state);

        return ColoredBox(
          color: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                _CommandBar(
                  invoiceNumber: invoiceNumber,
                  isSaving: state.status == InvoiceStatusView.saving,
                  onBack: () => context.go(InvoicesPage.routePath),
                  onSave: () => _save(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: state.status == InvoiceStatusView.loading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final stackSummary = constraints.maxWidth < 1100;
                            final editorSettings =
                                state.settings ?? AppSettings.initial();
                            for (final item in _items) {
                              item.ensureCustomFields(
                              editorSettings.customLineItemFields,
                              );
                            }
                            _ensureCustomerCustomFields(
                              editorSettings.customCustomerFields,
                            );
                            final formContent = _EditorForm(
                              customers: state.customers,
                              products: state.products,
                              customCustomerFields:
                                  editorSettings.customCustomerFields,
                              customerCustomFieldControllers:
                                  _customerCustomFields,
                              showLineItemHsn: editorSettings.showLineItemHsn,
                              customLineItemFields:
                                  editorSettings.customLineItemFields,
                              selectedCustomer: _selectedCustomer,
                              customerName: _customerName,
                              phone: _phone,
                              email: _email,
                              gstin: _gstin,
                              state: _state,
                              billingAddress: _billingAddress,
                              shippingAddress: _shippingAddress,
                              invoiceDate: _invoiceDate,
                              dueDate: _dueDate,
                              taxMode: _taxMode,
                              status: _status,
                              items: _items,
                              notes: _notes,
                              terms: _terms,
                              onPickCustomer: _applyCustomer,
                              onInvoiceDateChanged: (date) =>
                                  setState(() => _invoiceDate = date),
                              onDueDateChanged: (date) =>
                                  setState(() => _dueDate = date),
                              onTaxModeChanged: (value) =>
                                  setState(() => _taxMode = value),
                              onStatusChanged: (value) =>
                                  setState(() => _status = value),
                              onAddItem: _addItem,
                              onRemoveItem: _removeItem,
                              onChanged: _refresh,
                            );
                            final summary = _SummaryPanel(
                              invoiceNumber: invoiceNumber,
                              customerName: _customerName.text.trim(),
                              status: _status,
                              taxMode: _taxMode,
                              totals: totals,
                              isSaving:
                                  state.status == InvoiceStatusView.saving,
                              onSave: () => _save(context),
                              expanded: stackSummary,
                            );

                            return Form(
                              key: _formKey,
                              child: stackSummary
                                  ? SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          formContent,
                                          const SizedBox(
                                            height: AppSpacing.lg,
                                          ),
                                          summary,
                                        ],
                                      ),
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: formContent,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.lg),
                                        summary,
                                      ],
                                    ),
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

  void _seedFromDraft(InvoiceDraft draft) {
    _taxMode = draft.taxMode;
    _status = draft.status;
    _invoiceDate = draft.invoiceDate;
    _dueDate = draft.dueDate;
    _items = draft.items.map(_ItemControllers.fromItem).toList();
    for (final item in _items) {
      item.addListener(_refresh);
    }
  }

  void _applyCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerName.text = customer.name;
      _phone.text = customer.phone;
      _email.text = customer.email;
      _gstin.text = customer.gstin;
      _state.text = customer.state;
      _billingAddress.text = customer.billingAddress;
      _shippingAddress.text = customer.shippingAddress;
      for (final entry in customer.customFields.entries) {
        _customerCustomField(entry.key).text = entry.value;
      }
    });
  }

  void _addItem() {
    setState(() {
      final item = _ItemControllers.empty();
      item.addListener(_refresh);
      _items.add(item);
    });
  }

  void _removeItem(_ItemControllers item) {
    if (_items.length == 1) return;
    setState(() {
      item.dispose();
      _items.remove(item);
    });
  }

  void _save(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final draft = InvoiceDraft(
      existingCustomer: _selectedCustomer,
      customerName: _customerName.text.trim(),
      customerPhone: _phone.text.trim(),
      customerEmail: _email.text.trim(),
      customerGstin: _gstin.text.trim(),
      customerState: _state.text.trim(),
      billingAddress: _billingAddress.text.trim(),
      shippingAddress: _shippingAddress.text.trim(),
      customerCustomFields: _customerCustomFields.map((key, controller) {
        return MapEntry(key, controller.text.trim());
      }),
      invoiceDate: _invoiceDate,
      dueDate: _dueDate,
      taxMode: _taxMode,
      status: _status,
      items: _items.map((item) => item.toItem()).toList(),
      notes: _notes.text.trim(),
      terms: _terms.text.trim(),
    );
    context.read<InvoiceCubit>().saveDraft(draft);
  }

  TextEditingController _customerCustomField(String field) {
    return _customerCustomFields.putIfAbsent(field, () {
      final controller = TextEditingController();
      controller.addListener(_refresh);
      return controller;
    });
  }

  void _ensureCustomerCustomFields(List<String> fields) {
    for (final field in fields) {
      _customerCustomField(field);
    }
    final allowed = fields.map((field) => field.toLowerCase()).toSet();
    final staleKeys = _customerCustomFields.keys
        .where((field) => !allowed.contains(field.toLowerCase()))
        .toList();
    for (final key in staleKeys) {
      _customerCustomFields.remove(key)
        ?..removeListener(_refresh)
        ..dispose();
    }
  }

  _InvoiceTotals _calculateTotals() {
    var subtotal = 0.0;
    var cgst = 0.0;
    var sgst = 0.0;
    var igst = 0.0;

    for (final item in _items) {
      final taxable = _round(item.quantityValue * item.rateValue);
      final tax = _taxMode == TaxMode.none
          ? 0.0
          : _round(taxable * item.gstRateValue / 100);
      subtotal += taxable;
      if (_taxMode == TaxMode.cgstSgst) {
        cgst += _round(tax / 2);
        sgst += _round(tax / 2);
      }
      if (_taxMode == TaxMode.igst) {
        igst += tax;
      }
    }

    subtotal = _round(subtotal);
    cgst = _round(cgst);
    sgst = _round(sgst);
    igst = _round(igst);
    return _InvoiceTotals(
      subtotal: subtotal,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      grandTotal: _round(subtotal + cgst + sgst + igst),
    );
  }

  String _invoiceNumberPreview(InvoiceState state) {
    final settings = state.settings;
    if (settings == null) return 'Draft invoice';
    final sequence = settings.invoiceNextNumber.toString().padLeft(
      settings.invoiceNumberPadding,
      '0',
    );
    final year = _invoiceDate.year.toString();
    final month = _invoiceDate.month.toString().padLeft(2, '0');
    final date = settings.invoiceDateFormat
        .replaceAll('yyyy', year)
        .replaceAll('yy', year.substring(2))
        .replaceAll('MM', month)
        .replaceAll('dd', _invoiceDate.day.toString().padLeft(2, '0'));
    final separator = settings.invoiceSeparator.trim().isEmpty
        ? '-'
        : settings.invoiceSeparator.trim();
    return [settings.invoicePrefix, date, sequence]
        .where((segment) => segment.trim().isNotEmpty)
        .join(separator);
  }

  double _round(double value) => double.parse(value.toStringAsFixed(2));

  void _refresh() {
    if (mounted) setState(() {});
  }
}

class _EditorForm extends StatelessWidget {
  const _EditorForm({
    required this.customers,
    required this.products,
    required this.customCustomerFields,
    required this.customerCustomFieldControllers,
    required this.showLineItemHsn,
    required this.customLineItemFields,
    required this.selectedCustomer,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.state,
    required this.billingAddress,
    required this.shippingAddress,
    required this.invoiceDate,
    required this.dueDate,
    required this.taxMode,
    required this.status,
    required this.items,
    required this.notes,
    required this.terms,
    required this.onPickCustomer,
    required this.onInvoiceDateChanged,
    required this.onDueDateChanged,
    required this.onTaxModeChanged,
    required this.onStatusChanged,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onChanged,
  });

  final List<Customer> customers;
  final List<ProductService> products;
  final List<String> customCustomerFields;
  final Map<String, TextEditingController> customerCustomFieldControllers;
  final bool showLineItemHsn;
  final List<String> customLineItemFields;
  final Customer? selectedCustomer;
  final TextEditingController customerName;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController gstin;
  final TextEditingController state;
  final TextEditingController billingAddress;
  final TextEditingController shippingAddress;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final TaxMode taxMode;
  final InvoiceStatus status;
  final List<_ItemControllers> items;
  final TextEditingController notes;
  final TextEditingController terms;
  final ValueChanged<Customer> onPickCustomer;
  final ValueChanged<DateTime> onInvoiceDateChanged;
  final ValueChanged<DateTime> onDueDateChanged;
  final ValueChanged<TaxMode> onTaxModeChanged;
  final ValueChanged<InvoiceStatus> onStatusChanged;
  final VoidCallback onAddItem;
  final ValueChanged<_ItemControllers> onRemoveItem;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CustomerPanel(
          customers: customers,
          selectedCustomer: selectedCustomer,
          customerName: customerName,
          phone: phone,
          email: email,
          gstin: gstin,
          state: state,
          billingAddress: billingAddress,
          shippingAddress: shippingAddress,
          customFields: customCustomerFields,
          customFieldControllers: customerCustomFieldControllers,
          onPickCustomer: onPickCustomer,
        ),
        const SizedBox(height: AppSpacing.lg),
        _InvoiceMetaPanel(
          invoiceDate: invoiceDate,
          dueDate: dueDate,
          taxMode: taxMode,
          status: status,
          onInvoiceDateChanged: onInvoiceDateChanged,
          onDueDateChanged: onDueDateChanged,
          onTaxModeChanged: onTaxModeChanged,
          onStatusChanged: onStatusChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ItemsPanel(
          items: items,
          products: products,
          showHsnSac: showLineItemHsn,
          customFields: customLineItemFields,
          onAdd: onAddItem,
          onRemove: onRemoveItem,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        _NotesPanel(notes: notes, terms: terms),
      ],
    );
  }
}

class _CommandBar extends StatelessWidget {
  const _CommandBar({
    required this.invoiceNumber,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
  });

  final String invoiceNumber;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to invoices',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Invoice',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  invoiceNumber,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onAccent,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isSaving ? 'Saving...' : 'Save Invoice'),
          ),
        ],
      ),
    );
  }
}

class _CustomerPanel extends StatelessWidget {
  const _CustomerPanel({
    required this.customers,
    required this.selectedCustomer,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.state,
    required this.billingAddress,
    required this.shippingAddress,
    required this.customFields,
    required this.customFieldControllers,
    required this.onPickCustomer,
  });

  final List<Customer> customers;
  final Customer? selectedCustomer;
  final TextEditingController customerName;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController gstin;
  final TextEditingController state;
  final TextEditingController billingAddress;
  final TextEditingController shippingAddress;
  final List<String> customFields;
  final Map<String, TextEditingController> customFieldControllers;
  final ValueChanged<Customer> onPickCustomer;

  @override
  Widget build(BuildContext context) {
    final query = customerName.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? customers.take(3).toList()
        : customers
            .where(
              (customer) =>
                  customer.name.toLowerCase().contains(query) ||
                  customer.phone.toLowerCase().contains(query) ||
                  customer.email.toLowerCase().contains(query),
            )
            .take(4)
            .toList();

    return _Panel(
      icon: Icons.person_outline,
      title: 'Invoice Detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldCaption('Billed to'),
          TextFormField(
            controller: customerName,
            decoration: const InputDecoration(
              hintText: 'Search or create customer',
              prefixIcon: Icon(Icons.search),
            ),
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? 'Customer name is required'
                : null,
          ),
          if (matches.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: matches
                  .map(
                    (customer) => _CustomerSuggestion(
                      customer: customer,
                      selected: selectedCustomer?.id == customer.id,
                      onTap: () => onPickCustomer(customer),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: _Field(phone, 'Phone')),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _Field(email, 'Email')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _Field(gstin, 'GSTIN')),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _Field(state, 'State')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _Field(billingAddress, 'Billing Address')),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _Field(shippingAddress, 'Shipping Address')),
            ],
          ),
          if (customFields.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final field in customFields)
                  _Field(
                    customFieldControllers[field]!,
                    field,
                    width: 260,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerSuggestion extends StatelessWidget {
  const _CustomerSuggestion({
    required this.customer,
    required this.selected,
    required this.onTap,
  });

  final Customer customer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        selected ? Icons.check_circle : Icons.person_outline,
        size: 18,
        color: selected ? AppColors.success : AppColors.primaryPurple,
      ),
      label: Text(customer.phone.isEmpty
          ? customer.name
          : '${customer.name}  ${customer.phone}'),
      onPressed: onTap,
      side: BorderSide(color: selected ? AppColors.success : AppColors.border),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  const _FieldCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _InvoiceMetaPanel extends StatelessWidget {
  const _InvoiceMetaPanel({
    required this.invoiceDate,
    required this.dueDate,
    required this.taxMode,
    required this.status,
    required this.onInvoiceDateChanged,
    required this.onDueDateChanged,
    required this.onTaxModeChanged,
    required this.onStatusChanged,
  });

  final DateTime invoiceDate;
  final DateTime dueDate;
  final TaxMode taxMode;
  final InvoiceStatus status;
  final ValueChanged<DateTime> onInvoiceDateChanged;
  final ValueChanged<DateTime> onDueDateChanged;
  final ValueChanged<TaxMode> onTaxModeChanged;
  final ValueChanged<InvoiceStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.tune_outlined,
      title: 'Invoice Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Invoice Date',
                  date: invoiceDate,
                  onChanged: onInvoiceDateChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _DateField(
                  label: 'Due Date',
                  date: dueDate,
                  onChanged: onDueDateChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<TaxMode>(
                  initialValue: taxMode,
                  decoration: const InputDecoration(labelText: 'Tax Mode'),
                  items: TaxMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onTaxModeChanged(value);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<InvoiceStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    InvoiceStatus.draft,
                    InvoiceStatus.unpaid,
                    InvoiceStatus.paid,
                  ]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onStatusChanged(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemsPanel extends StatelessWidget {
  const _ItemsPanel({
    required this.items,
    required this.products,
    required this.showHsnSac,
    required this.customFields,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<_ItemControllers> items;
  final List<ProductService> products;
  final bool showHsnSac;
  final List<String> customFields;
  final VoidCallback onAdd;
  final ValueChanged<_ItemControllers> onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.list_alt_outlined,
      title: 'Items',
      trailing: OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      child: Column(
        children: [
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ItemCard(
                item: item,
                products: products,
                showHsnSac: showHsnSac,
                customFields: customFields,
                canRemove: items.length > 1,
                onRemove: () => onRemove(item),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.products,
    required this.showHsnSac,
    required this.customFields,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _ItemControllers item;
  final List<ProductService> products;
  final bool showHsnSac;
  final List<String> customFields;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: DropdownButtonFormField<ProductService?>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Saved item'),
                  items: [
                    const DropdownMenuItem<ProductService?>(
                      value: null,
                      child: Text('Manual item'),
                    ),
                    ...products.map(
                      (product) => DropdownMenuItem<ProductService?>(
                        value: product,
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (product) {
                    item.applyProduct(product);
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: item.name,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                height: 64,
                width: 56,
                child: IconButton(
                  tooltip: 'Remove item',
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SmallField(item.quantity, 'Quantity', width: 116),
              _SmallField(item.unit, 'Unit', width: 140, numeric: false),
              _SmallField(item.rate, 'Rate', width: 150),
              _SmallField(item.gstRate, 'GST %', width: 120),
              if (showHsnSac) _SmallField(
                item.hsnSac,
                'HSN/SAC',
                width: 150,
                numeric: false,
              ),
              for (final field in customFields)
                _SmallField(
                  item.customField(field),
                  field,
                  width: 150,
                  numeric: false,
                ),
              _LineAmount(value: item.lineTotal),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineAmount extends StatelessWidget {
  const _LineAmount({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Amount',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.notes, required this.terms});

  final TextEditingController notes;
  final TextEditingController terms;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.notes_outlined,
      title: 'Notes & Terms',
      child: Row(
        children: [
          Expanded(child: _Field(notes, 'Notes', maxLines: 3)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _Field(terms, 'Terms', maxLines: 3)),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.invoiceNumber,
    required this.customerName,
    required this.status,
    required this.taxMode,
    required this.totals,
    required this.isSaving,
    required this.onSave,
    this.expanded = false,
  });

  final String invoiceNumber;
  final String customerName;
  final InvoiceStatus status;
  final TaxMode taxMode;
  final _InvoiceTotals totals;
  final bool isSaving;
  final VoidCallback onSave;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expanded ? double.infinity : 320,
      child: Container(
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
              'Invoice Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SummaryHero(
              invoiceNumber: invoiceNumber,
              customerName: customerName.isEmpty
                  ? 'No customer yet'
                  : customerName,
              total: totals.grandTotal,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SummaryLine('Status', status.label),
            _SummaryLine('Tax Mode', taxMode.label),
            const Divider(height: AppSpacing.xl),
            _MoneyLine('Subtotal', totals.subtotal),
            _MoneyLine('CGST', totals.cgst),
            _MoneyLine('SGST', totals.sgst),
            _MoneyLine('IGST', totals.igst),
            const Divider(height: AppSpacing.xl),
            _MoneyLine('Grand Total', totals.grandTotal, strong: true),
            if (expanded)
              const SizedBox(height: AppSpacing.lg)
            else
              const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Invoice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({
    required this.invoiceNumber,
    required this.customerName,
    required this.total,
  });

  final String invoiceNumber;
  final String customerName;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invoiceNumber,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            total.toStringAsFixed(2),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine(this.label, this.value, {this.strong = false});

  final String label;
  final double value;
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: strong ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(2),
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

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryPurple),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('$label-${date.toIso8601String()}'),
      readOnly: true,
      initialValue: _formatDate(date),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _Field extends StatelessWidget {
  const _Field(
    this.controller,
    this.label, {
    this.width,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final double? width;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
    if (width == null) return field;
    return SizedBox(width: width, child: field);
  }
}

class _SmallField extends StatelessWidget {
  const _SmallField(
    this.controller,
    this.label, {
    required this.width,
    this.numeric = true,
  });

  final TextEditingController controller;
  final String label;
  final double width;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (!numeric) return null;
          final text = value?.trim() ?? '';
          if (text.isNotEmpty && double.tryParse(text) == null) {
            return 'Invalid';
          }
          return null;
        },
      ),
    );
  }
}

class _ItemControllers {
  _ItemControllers({
    required this.productId,
    required this.name,
    required this.description,
    required this.hsnSac,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.gstRate,
    required Map<String, String> customFields,
  }) : customFields = {
         for (final entry in customFields.entries)
           entry.key: TextEditingController(text: entry.value),
       };

  factory _ItemControllers.empty() {
    return _ItemControllers.fromItem(InvoiceItem.empty());
  }

  factory _ItemControllers.fromItem(InvoiceItem item) {
    return _ItemControllers(
      productId: item.productId,
      name: TextEditingController(text: item.name),
      description: TextEditingController(text: item.description),
      hsnSac: TextEditingController(text: item.hsnSac),
      quantity: TextEditingController(text: item.quantity.toString()),
      unit: TextEditingController(text: item.unit),
      rate: TextEditingController(text: item.rate.toString()),
      gstRate: TextEditingController(text: item.gstRate.toString()),
      customFields: item.customFields,
    );
  }

  String productId;
  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController hsnSac;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController rate;
  final TextEditingController gstRate;
  final Map<String, TextEditingController> customFields;

  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;
  double get rateValue => double.tryParse(rate.text.trim()) ?? 0;
  double get gstRateValue => double.tryParse(gstRate.text.trim()) ?? 0;
  double get lineTotal => quantityValue * rateValue;

  TextEditingController customField(String field) {
    return customFields.putIfAbsent(
      field,
      () => TextEditingController(),
    );
  }

  void ensureCustomFields(List<String> fields) {
    for (final field in fields) {
      customField(field);
    }
    final allowed = fields.map((field) => field.toLowerCase()).toSet();
    final staleKeys = customFields.keys
        .where((field) => !allowed.contains(field.toLowerCase()))
        .toList();
    for (final key in staleKeys) {
      customFields.remove(key)?.dispose();
    }
  }

  void applyProduct(ProductService? product) {
    if (product == null) {
      productId = '';
      return;
    }
    productId = product.id;
    name.text = product.name;
    description.text = product.description;
    hsnSac.text = product.hsnSac;
    unit.text = product.unit;
    rate.text = product.defaultRate.toString();
    gstRate.text = product.gstRate.toString();
  }

  void addListener(VoidCallback listener) {
    for (final controller in [
      name,
      description,
      hsnSac,
      quantity,
      unit,
      rate,
      gstRate,
      ...customFields.values,
    ]) {
      controller.addListener(listener);
    }
  }

  InvoiceItem toItem() {
    return InvoiceItem.empty().copyWith(
      productId: productId,
      name: name.text.trim(),
      description: description.text.trim(),
      hsnSac: hsnSac.text.trim(),
      quantity: quantityValue,
      unit: unit.text.trim(),
      rate: rateValue,
      gstRate: gstRateValue,
      customFields: customFields.map((key, controller) {
        return MapEntry(key, controller.text.trim());
      }),
    );
  }

  void dispose() {
    name.dispose();
    description.dispose();
    hsnSac.dispose();
    quantity.dispose();
    unit.dispose();
    rate.dispose();
    gstRate.dispose();
    for (final controller in customFields.values) {
      controller.dispose();
    }
  }
}

class _InvoiceTotals {
  const _InvoiceTotals({
    required this.subtotal,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.grandTotal,
  });

  final double subtotal;
  final double cgst;
  final double sgst;
  final double igst;
  final double grandTotal;
}
