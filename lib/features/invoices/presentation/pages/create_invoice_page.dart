import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/data/services/gstin_lookup_service.dart';
import '../../../products/domain/entities/product_service.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_draft.dart';
import '../../domain/entities/invoice_item.dart';
import '../../domain/services/hsn_gst_lookup.dart';
import '../../domain/services/invoice_calculator.dart';
import '../../domain/services/invoice_output_builder.dart';
import '../cubit/invoice_cubit.dart';
import 'invoices_page.dart';

part 'create_invoice_page_support.dart';

class CreateInvoicePage extends StatelessWidget {
  const CreateInvoicePage({super.key, this.args});

  static const routePath = '/invoices/new';

  final CreateInvoicePageArgs? args;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvoiceCubit>()..load(),
      child: _CreateInvoiceView(args: args),
    );
  }
}

class CreateInvoicePageArgs {
  const CreateInvoicePageArgs({
    required this.sourceInvoice,
    this.title = 'New Invoice',
    this.mode = CreateInvoiceMode.create,
  });

  const CreateInvoicePageArgs.duplicate(Invoice invoice)
    : sourceInvoice = invoice,
      title = 'Duplicate Invoice',
      mode = CreateInvoiceMode.duplicate;

  const CreateInvoicePageArgs.edit(Invoice invoice)
    : sourceInvoice = invoice,
      title = 'Edit Invoice',
      mode = CreateInvoiceMode.edit;

  final Invoice? sourceInvoice;
  final String title;
  final CreateInvoiceMode mode;
}

enum CreateInvoiceMode { create, duplicate, edit }

class _CreateInvoiceView extends StatefulWidget {
  const _CreateInvoiceView({this.args});

  final CreateInvoicePageArgs? args;

  @override
  State<_CreateInvoiceView> createState() => _CreateInvoiceViewState();
}

class _CreateInvoiceViewState extends State<_CreateInvoiceView> {
  final _formKey = GlobalKey<FormState>();
  static const _builtInCustomerStateCodeKey = '_builtinStateCode';
  final _customerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  final _state = TextEditingController();
  final _stateCode = TextEditingController();
  final _billingAddress = TextEditingController();
  final _shippingAddress = TextEditingController();
  final _shipToName = TextEditingController();
  final _shipToPhone = TextEditingController();
  final _shipToEmail = TextEditingController();
  final _shipToState = TextEditingController();
  final _shipToStateCode = TextEditingController();
  final _shipToPincode = TextEditingController();
  final _discountValue = TextEditingController();
  final _advancePaid = TextEditingController();
  final _advancePaidMethod = TextEditingController();
  final _advancePaidReference = TextEditingController();
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  final Map<String, TextEditingController> _customerCustomFields = {};
  final Map<String, TextEditingController> _shippingCustomFields = {};
  final _calculator = InvoiceCalculator();
  final _outputBuilder = const InvoiceOutputBuilder();
  late TaxMode _taxMode;
  late InvoiceStatus _status;
  late bool _roundOffEnabled;
  late bool _shippingEnabled;
  late bool _amountsEnabled;
  late String _discountType;
  late DateTime _invoiceDate;
  late DateTime _dueDate;
  DateTime? _advancePaidDate;
  late List<_ItemControllers> _items;
  late List<_ChargeControllers> _extraCharges;
  Customer? _selectedCustomer;
  bool _seeded = false;
  bool _isSeedingControllers = false;
  bool _isLookingUpGstin = false;
  _GstinValidationState? _gstinValidation;
  _GstinAutofillSnapshot? _gstinAutofill;
  HsnGstLookup? _hsnGstLookup;

  @override
  void initState() {
    super.initState();
    _seedFromDraft(InvoiceDraft.initial());
    _loadHsnGstLookup();
    _gstin.addListener(_handleGstinTextChanged);
    for (final controller in [
      _customerName,
      _phone,
      _email,
      _gstin,
      _state,
      _stateCode,
      _billingAddress,
      _shippingAddress,
      _shipToName,
      _shipToPhone,
      _shipToEmail,
      _shipToState,
      _shipToStateCode,
      _shipToPincode,
      _discountValue,
      _advancePaid,
      _advancePaidMethod,
      _advancePaidReference,
      _notes,
      _terms,
      ..._customerCustomFields.values,
      ..._shippingCustomFields.values,
    ]) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _gstin.removeListener(_handleGstinTextChanged);
    for (final controller in [
      _customerName,
      _phone,
      _email,
      _gstin,
      _state,
      _stateCode,
      _billingAddress,
      _shippingAddress,
      _shipToName,
      _shipToPhone,
      _shipToEmail,
      _shipToState,
      _shipToStateCode,
      _shipToPincode,
      _discountValue,
      _advancePaid,
      _advancePaidMethod,
      _advancePaidReference,
      _notes,
      _terms,
      ..._customerCustomFields.values,
      ..._shippingCustomFields.values,
    ]) {
      controller
        ..removeListener(_refresh)
        ..dispose();
    }
    for (final charge in _extraCharges) {
      charge.dispose();
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
          for (final charge in _extraCharges) {
            charge.dispose();
          }
          for (final item in _items) {
            item.dispose();
          }
          _seedFromDraft(_initialDraft(state));
          _seeded = true;
        }

        final settings = state.settings ?? AppSettings.initial();
        final totals = _calculateTotals();
        final invoiceNumber = _invoiceNumberPreview(state);

        return ColoredBox(
          color: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                _CommandBar(
                  title: widget.args?.title ?? 'New Invoice',
                  invoiceNumber: invoiceNumber,
                  isSaving: state.status == InvoiceStatusView.saving,
                  isEdit: widget.args?.mode == CreateInvoiceMode.edit,
                  currentStatus: _status,
                  onBack: () => context.go(InvoicesPage.routePath),
                  onFillDemo: _fillDemoData,
                  onSaveDraft: () =>
                      _save(context, statusOverride: InvoiceStatus.draft),
                  onFinalize: () =>
                      _save(context, statusOverride: InvoiceStatus.unpaid),
                  onSave: () => _save(context),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: state.status == InvoiceStatusView.loading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final stackSummary = constraints.maxWidth < 1100;
                            final editorSettings = settings;
                            final visibleCustomerCustomFields =
                                editorSettings.showCustomerStateCode
                                ? editorSettings.customCustomerFields
                                      .where(
                                        (field) =>
                                            !_isStateCodeFieldName(field.name),
                                      )
                                      .toList(growable: false)
                                : editorSettings.customCustomerFields;
                            final visibleShippingCustomFields =
                                editorSettings.showCustomerStateCode
                                ? editorSettings.customShippingFields
                                      .where(
                                        (field) =>
                                            !_isStateCodeFieldName(field.name),
                                      )
                                      .toList(growable: false)
                                : editorSettings.customShippingFields;
                            for (final item in _items) {
                              item.ensureCustomFields(
                                editorSettings.customLineItemFields,
                              );
                            }
                            _ensureCustomerCustomFields(
                              visibleCustomerCustomFields,
                            );
                            _ensureShippingCustomFields(
                              visibleShippingCustomFields,
                            );
                            final formContent = _EditorForm(
                              customers: state.customers,
                              products: state.products,
                              customCustomerFields: visibleCustomerCustomFields,
                              customerCustomFieldControllers:
                                  _customerCustomFields,
                              customShippingFields: visibleShippingCustomFields,
                              shippingCustomFieldControllers:
                                  _shippingCustomFields,
                              showLineItemHsn: editorSettings.showLineItemHsn,
                              customLineItemFields:
                                  editorSettings.customLineItemFields,
                              selectedCustomer: _selectedCustomer,
                              customerName: _customerName,
                              phone: _phone,
                              email: _email,
                              gstin: _gstin,
                              state: _state,
                              stateCode: _stateCode,
                              showCustomerStateCode:
                                  editorSettings.showCustomerStateCode,
                              billingAddress: _billingAddress,
                              gstinLookupEnabled:
                                  editorSettings.gstinLookupEnabled,
                              gstinValidation: _gstinValidation,
                              isLookingUpGstin: _isLookingUpGstin,
                              shippingEnabled: _shippingEnabled,
                              shippingAddress: _shippingAddress,
                              shipToName: _shipToName,
                              shipToPhone: _shipToPhone,
                              shipToEmail: _shipToEmail,
                              shipToState: _shipToState,
                              shipToStateCode: _shipToStateCode,
                              shipToPincode: _shipToPincode,
                              invoiceDate: _invoiceDate,
                              dueDate: _dueDate,
                              taxMode: _taxMode,
                              status: _status,
                              roundOffEnabled: _roundOffEnabled,
                              amountsEnabled: _amountsEnabled,
                              discountType: _discountType,
                              discountValue: _discountValue,
                              extraCharges: _extraCharges,
                              advancePaid: _advancePaid,
                              advancePaidDate: _advancePaidDate,
                              advancePaidMethod: _advancePaidMethod,
                              advancePaidReference: _advancePaidReference,
                              items: _items,
                              notes: _notes,
                              terms: _terms,
                              onPickCustomer: _applyCustomer,
                              onLookupGstin: () => _lookupGstinDetails(context),
                              onShippingEnabledChanged: (value) => setState(() {
                                _shippingEnabled = value;
                                if (value && _shipToState.text.trim().isEmpty) {
                                  _shipToState.text =
                                      editorSettings.defaultShippingState;
                                }
                                if (value &&
                                    _showCustomerStateCode &&
                                    _shipToStateCode.text.trim().isEmpty) {
                                  _shipToStateCode.text = _stateCode.text
                                      .trim();
                                }
                              }),
                              onUseBillingForShipping:
                                  _copyBillingDetailsToShipping,
                              onInvoiceDateChanged: (date) =>
                                  setState(() => _invoiceDate = date),
                              onDueDateChanged: (date) =>
                                  setState(() => _dueDate = date),
                              onTaxModeChanged: (value) =>
                                  setState(() => _taxMode = value),
                              onRoundOffChanged: (value) =>
                                  setState(() => _roundOffEnabled = value),
                              onAmountsEnabledChanged: _setAmountsEnabled,
                              onDiscountTypeChanged: (value) =>
                                  setState(() => _discountType = value),
                              onAdvancePaidDateChanged: (value) =>
                                  setState(() => _advancePaidDate = value),
                              onAddCharge: _addCharge,
                              onRemoveCharge: _removeCharge,
                              onAddItem: _addItem,
                              onRemoveItem: _removeItem,
                              onChanged: _refresh,
                              onProductApplied: _applyHsnRate,
                            );
                            final summary = _SummaryPanel(
                              invoiceNumber: invoiceNumber,
                              customerName: _customerName.text.trim(),
                              status: _status,
                              taxMode: _taxMode,
                              totals: totals,
                              amountInWords: _amountInWords(totals.grandTotal),
                              amountPaid: _amountsEnabled
                                  ? _parsedAmount(_advancePaid)
                                  : 0,
                              balanceDue:
                                  (totals.grandTotal -
                                          (_amountsEnabled
                                              ? _parsedAmount(_advancePaid)
                                              : 0))
                                      .clamp(0, double.infinity)
                                      .toDouble(),
                              paymentHistoryPreview:
                                  _buildDraftPaymentHistoryPreview(),
                              paymentData: _outputBuilder.buildPaymentData(
                                companyProfile: state.companyProfile,
                                invoiceNumber: invoiceNumber,
                                grandTotal: totals.grandTotal,
                              ),
                              isSaving:
                                  state.status == InvoiceStatusView.saving,
                              isEdit:
                                  widget.args?.mode == CreateInvoiceMode.edit,
                              onSaveDraft: () => _save(
                                context,
                                statusOverride: InvoiceStatus.draft,
                              ),
                              onFinalize: () => _save(
                                context,
                                statusOverride: InvoiceStatus.unpaid,
                              ),
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
                                          const SizedBox(height: AppSpacing.lg),
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
    _isSeedingControllers = true;
    _gstinAutofill = null;
    _selectedCustomer = draft.existingCustomer;
    _customerName.text = draft.customerName;
    _phone.text = draft.customerPhone;
    _email.text = draft.customerEmail;
    _gstin.text = draft.customerGstin;
    _state.text = draft.customerState;
    _stateCode.text = draft.customerStateCode;
    _billingAddress.text = draft.billingAddress;
    _shippingAddress.text = draft.shippingAddress;
    _shipToName.text = draft.shipToName;
    _shipToPhone.text = draft.shipToPhone;
    _shipToEmail.text = draft.shipToEmail;
    _shipToState.text = draft.shipToState;
    _shipToStateCode.text = draft.shipToStateCode;
    _shipToPincode.text = draft.shipToPincode;
    for (final entry in draft.customerCustomFields.entries) {
      _customerCustomField(entry.key).text = entry.value;
    }
    for (final entry in draft.shippingCustomFields.entries) {
      _shippingCustomField(entry.key).text = entry.value;
    }
    _taxMode = draft.taxMode;
    _status = draft.status;
    _roundOffEnabled = draft.roundOffEnabled;
    _amountsEnabled = _hasAmountsData(draft);
    _discountType = draft.discountType;
    _discountValue.text = _formatEditableNumber(draft.discountValue);
    _advancePaid.text = _formatEditableNumber(draft.advancePaid);
    _advancePaidDate = draft.advancePaidDate;
    _advancePaidMethod.text = draft.advancePaidMethod;
    _advancePaidReference.text = draft.advancePaidReference;
    _shippingEnabled = draft.shippingEnabled;
    _invoiceDate = draft.invoiceDate;
    _dueDate = draft.dueDate;
    _extraCharges = draft.extraCharges
        .map(_ChargeControllers.fromCharge)
        .toList();
    _items = draft.items.map(_ItemControllers.fromItem).toList();
    for (final charge in _extraCharges) {
      charge.addListener(_refresh);
    }
    for (final item in _items) {
      _attachItem(item);
    }
    _isSeedingControllers = false;
  }

  InvoiceDraft _initialDraft(InvoiceState state) {
    final sourceInvoice = widget.args?.sourceInvoice;
    if (sourceInvoice == null) {
      return state.draft!;
    }

    Customer? matchedCustomer;
    for (final customer in state.customers) {
      if (customer.id == sourceInvoice.customerId) {
        matchedCustomer = customer;
        break;
      }
    }
    final customerSnapshot = sourceInvoice.customerSnapshot;
    final shippedToRaw = customerSnapshot['shippedTo'];
    final shippedTo = shippedToRaw is Map<String, dynamic>
        ? shippedToRaw
        : shippedToRaw is Map
        ? Map<String, dynamic>.from(shippedToRaw)
        : <String, dynamic>{};

    final isEdit = widget.args?.mode == CreateInvoiceMode.edit;
    final invoiceDate = isEdit ? sourceInvoice.invoiceDate : DateTime.now();
    final dueShift = sourceInvoice.dueDate.difference(
      sourceInvoice.invoiceDate,
    );
    final dueDate = isEdit
        ? sourceInvoice.dueDate
        : invoiceDate.add(
            dueShift.isNegative ? const Duration(days: 15) : dueShift,
          );
    InvoicePaymentRecord? initialPayment;
    if (isEdit) {
      for (final payment in sourceInvoice.paymentHistory) {
        if (payment.notes == 'Initial advance payment') {
          initialPayment = payment;
          break;
        }
      }
    }
    return InvoiceDraft(
      existingCustomer: matchedCustomer,
      customerName: customerSnapshot['name']?.toString() ?? '',
      customerPhone: customerSnapshot['phone']?.toString() ?? '',
      customerEmail: customerSnapshot['email']?.toString() ?? '',
      customerGstin: customerSnapshot['gstin']?.toString() ?? '',
      customerState: customerSnapshot['state']?.toString() ?? '',
      customerStateCode: _stateCodeFromSnapshot(customerSnapshot),
      billingAddress: customerSnapshot['billingAddress']?.toString() ?? '',
      shippingEnabled: shippedTo.isNotEmpty,
      shippingAddress:
          customerSnapshot['shippingAddress']?.toString() ??
          shippedTo['address']?.toString() ??
          '',
      shipToName: shippedTo['name']?.toString() ?? '',
      shipToPhone: shippedTo['phone']?.toString() ?? '',
      shipToEmail: shippedTo['email']?.toString() ?? '',
      shipToState: shippedTo['state']?.toString() ?? '',
      shipToStateCode: _stateCodeFromSnapshot(shippedTo),
      shipToPincode: shippedTo['pincode']?.toString() ?? '',
      shippingCustomFields: _stringMap(shippedTo['customFields']),
      customerCustomFields: _stringMap(customerSnapshot['customFields']),
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      taxMode: sourceInvoice.taxMode,
      status: isEdit ? sourceInvoice.status : InvoiceStatus.unpaid,
      roundOffEnabled: sourceInvoice.roundOffEnabled,
      discountType: sourceInvoice.discountType,
      discountValue: sourceInvoice.discountValue,
      extraCharges: sourceInvoice.extraCharges,
      advancePaid: initialPayment?.amount ?? 0,
      advancePaidDate: initialPayment?.paidAt,
      advancePaidMethod: initialPayment?.method ?? '',
      advancePaidReference: initialPayment?.reference ?? '',
      items: sourceInvoice.items,
      notes: sourceInvoice.notes,
      terms: sourceInvoice.terms,
    );
  }

  Map<String, String> _stringMap(dynamic source) {
    if (source is Map<String, String>) return source;
    if (source is Map<String, dynamic>) {
      return source.map(
        (key, value) => MapEntry(key, value?.toString().trim() ?? ''),
      );
    }
    if (source is Map) {
      return source.map(
        (key, value) =>
            MapEntry(key.toString(), value?.toString().trim() ?? ''),
      );
    }
    return const {};
  }

  bool get _showCustomerStateCode =>
      context.read<InvoiceCubit>().state.settings?.showCustomerStateCode ??
      true;

  String _customerStateCode(Customer customer) {
    final reserved =
        customer.customFields[_builtInCustomerStateCodeKey]?.trim() ?? '';
    if (reserved.isNotEmpty) return reserved;
    for (final entry in customer.customFields.entries) {
      if (_isStateCodeFieldName(entry.key) && entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
    return '';
  }

  String _stateCodeFromSnapshot(Map<String, dynamic> snapshot) {
    final topLevel = snapshot['stateCode']?.toString().trim() ?? '';
    if (topLevel.isNotEmpty) return topLevel;
    final customFields = _stringMap(snapshot['customFields']);
    final reserved = customFields[_builtInCustomerStateCodeKey]?.trim() ?? '';
    if (reserved.isNotEmpty) return reserved;
    for (final entry in customFields.entries) {
      if (_isStateCodeFieldName(entry.key) && entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
    return '';
  }

  Future<void> _loadHsnGstLookup() async {
    try {
      final raw = await rootBundle.loadString('assets/hsn_gst_dataset.json');
      final decoded = jsonDecode(raw);
      if (!mounted || decoded is! Map<String, dynamic>) return;
      _hsnGstLookup = HsnGstLookup.fromJsonMap(decoded);
      for (final item in _items) {
        _applyHsnRate(item);
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Keep manual GST entry working even if the lookup asset is unavailable.
    }
  }

  void _applyCustomer(Customer customer) {
    setState(() {
      _gstinAutofill = null;
      _selectedCustomer = customer;
      _customerName.text = customer.name;
      _phone.text = customer.phone;
      _email.text = customer.email;
      _gstin.text = customer.gstin;
      _state.text = customer.state;
      _stateCode.text = _customerStateCode(customer);
      _billingAddress.text = customer.billingAddress;
      if ((customer.defaultDiscountValue > 0) &&
          (_discountValue.text.trim().isEmpty ||
              _parsedAmount(_discountValue) == 0)) {
        _amountsEnabled = true;
        _discountType = customer.defaultDiscountType;
        _discountValue.text = _formatEditableNumber(
          customer.defaultDiscountValue,
        );
      }
      final currentTerms = _terms.text.trim();
      final defaultCompanyTerms =
          context
              .read<InvoiceCubit>()
              .state
              .companyProfile
              ?.defaultInvoiceTerms
              .trim() ??
          '';
      if (customer.defaultInvoiceTerms.trim().isNotEmpty &&
          (currentTerms.isEmpty || currentTerms == defaultCompanyTerms)) {
        _terms.text = customer.defaultInvoiceTerms.trim();
      }
      _shippingAddress.text = customer.shippingAddress;
      _shippingEnabled = customer.shippingAddress.trim().isNotEmpty;
      _shipToName.text = customer.name;
      _shipToPhone.text = customer.phone;
      _shipToEmail.text = customer.email;
      _shipToState.text = customer.state;
      _shipToStateCode.text = _customerStateCode(customer);
      for (final entry in customer.customFields.entries) {
        if (entry.key == _builtInCustomerStateCodeKey) continue;
        if (_showCustomerStateCode && _isStateCodeFieldName(entry.key)) {
          continue;
        }
        _customerCustomField(entry.key).text = entry.value;
      }
    });
  }

  void _copyBillingDetailsToShipping() {
    setState(() {
      _shippingEnabled = true;
      _shipToName.text = _customerName.text.trim();
      _shipToPhone.text = _phone.text.trim();
      _shipToEmail.text = _email.text.trim();
      _shipToState.text = _state.text.trim();
      _shipToStateCode.text = _stateCode.text.trim();
      _shippingAddress.text = _billingAddress.text.trim();
    });
  }

  void _handleGstinTextChanged() {
    if (_isSeedingControllers) return;
    final current = _gstin.text.trim().toUpperCase();
    final cached = _gstinValidation;
    final autofill = _gstinAutofill;
    final needsValidationReset = cached != null && cached.gstin != current;
    final needsAutofillClear = autofill != null && autofill.gstin != current;
    if (!needsValidationReset && !needsAutofillClear) {
      return;
    }

    setState(() {
      if (needsValidationReset) {
        _gstinValidation = null;
      }
      if (needsAutofillClear) {
        if (_customerName.text.trim() == autofill.customerName) {
          _customerName.clear();
        }
        if (_state.text.trim() == autofill.stateName) {
          _state.clear();
        }
        if (_billingAddress.text.trim() == autofill.billingAddress) {
          _billingAddress.clear();
        }
        if (_stateCode.text.trim() == autofill.stateCode) {
          _stateCode.clear();
        }
        for (final entry in autofill.customerCustomFields.entries) {
          final controller = _customerCustomFields[entry.key];
          if (controller == null) continue;
          if (controller.text.trim() == entry.value) {
            controller.clear();
          }
        }
        _gstinAutofill = null;
      }
    });
  }

  Future<_GstinValidationState?> _validateGstin(BuildContext context) async {
    final gstin = _gstin.text.trim().toUpperCase();
    final messenger = ScaffoldMessenger.of(context);
    if (gstin.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter a GSTIN before validating.')),
        );
      return null;
    }
    if (_gstinValidation?.gstin == gstin && _gstinValidation != null) {
      return _gstinValidation;
    }

    try {
      final result = await context.read<InvoiceCubit>().validateGstin(gstin);
      if (!mounted || !context.mounted) return null;
      final validation = _GstinValidationState(
        gstin: result.gstin,
        isValid: result.isValid,
      );
      setState(() => _gstinValidation = validation);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              result.isValid
                  ? 'GSTIN format is valid.'
                  : 'GSTIN format is invalid.',
            ),
            backgroundColor: result.isValid
                ? AppColors.success
                : AppColors.warning,
          ),
        );
      return validation;
    } on AppException catch (error) {
      if (!mounted || !context.mounted) return null;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.error,
          ),
        );
      return null;
    } catch (error) {
      if (!mounted || !context.mounted) return null;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to validate GSTIN: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      return null;
    }
  }

  Future<void> _lookupGstinDetails(BuildContext context) async {
    final gstin = _gstin.text.trim().toUpperCase();
    final messenger = ScaffoldMessenger.of(context);
    if (gstin.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Enter a GSTIN before fetching details.'),
          ),
        );
      return;
    }

    final validation = await _validateGstin(context);
    if (!mounted || !context.mounted || validation == null) return;
    if (!validation.isValid) {
      return;
    }

    setState(() => _isLookingUpGstin = true);
    try {
      final details = await context.read<InvoiceCubit>().lookupGstin(gstin);
      if (!mounted || !context.mounted) return;
      setState(() {
        _selectedCustomer = null;
        _gstin.text = details.gstin;
        if (details.displayName.isNotEmpty) {
          _customerName.text = details.displayName;
        }
        if (details.stateName.isNotEmpty) {
          _state.text = details.stateName;
        }
        if (_showCustomerStateCode && details.stateCode.isNotEmpty) {
          _stateCode.text = details.stateCode;
        }
        if (details.formattedAddress.isNotEmpty) {
          _billingAddress.text = details.formattedAddress;
        }
        final customFieldValues = _applyStateCodeCustomField(details);
        _gstinAutofill = _GstinAutofillSnapshot(
          gstin: details.gstin,
          customerName: _customerName.text.trim(),
          stateName: _state.text.trim(),
          stateCode: _showCustomerStateCode ? _stateCode.text.trim() : '',
          billingAddress: _billingAddress.text.trim(),
          customerCustomFields: customFieldValues,
        );
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              details.displayName.isEmpty
                  ? 'GSTIN details fetched.'
                  : 'Fetched GST details for ${details.displayName}.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
    } on AppException catch (error) {
      if (!mounted || !context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.error,
          ),
        );
    } catch (error) {
      if (!mounted || !context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to fetch GSTIN details: $error'),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted && context.mounted) {
        setState(() => _isLookingUpGstin = false);
      }
    }
  }

  Map<String, String> _applyStateCodeCustomField(GstinBusinessDetails details) {
    final applied = <String, String>{};
    if (details.stateCode.isEmpty) return applied;
    if (_showCustomerStateCode) {
      return applied;
    }
    for (final entry in _customerCustomFields.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('state') && key.contains('code')) {
        entry.value.text = details.stateCode;
        applied[entry.key] = details.stateCode;
      }
    }
    return applied;
  }

  void _fillDemoData() {
    final now = DateTime.now();
    final lineFieldNames = _items
        .expand((item) => item.customFields.keys)
        .toSet()
        .toList();

    setState(() {
      _gstinAutofill = null;
      _selectedCustomer = null;
      _customerName.text = 'TBS Enterprises';
      _phone.text = '9655246269';
      _email.text = 'test@gmail.com';
      _gstin.text = '33AHOPY8219N1ZE';
      _state.text = 'Tamil Nadu';
      _stateCode.text = '33';
      _billingAddress.text =
          'No: 22, MMS Complex, Pudupattinam Kalpakkam, Tamil Nadu 603102';

      _shippingEnabled = true;
      _shipToName.text = 'Site Office - Kalpakkam';
      _shipToPhone.text = '9840012345';
      _shipToEmail.text = 'site@example.com';
      _shipToState.text = 'Tamil Nadu';
      _shipToStateCode.text = '33';
      _shippingAddress.text =
          'Warehouse Gate 2, Pudupattinam, Kalpakkam, Tamil Nadu';
      _shipToPincode.text = '603102';

      for (final entry in _customerCustomFields.entries) {
        entry.value.text = _demoValueForField(entry.key);
      }
      for (final entry in _shippingCustomFields.entries) {
        entry.value.text = _demoValueForField(entry.key);
      }

      _invoiceDate = now;
      _dueDate = now.add(const Duration(days: 15));
      _taxMode = TaxMode.cgstSgst;
      _status = InvoiceStatus.unpaid;
      _roundOffEnabled = true;
      _discountType = 'percentage';
      _amountsEnabled = true;
      _discountValue.text = '10';
      _advancePaid.text = '5000';
      _advancePaidDate = now;
      _advancePaidMethod.text = 'Bank Transfer';
      _advancePaidReference.text = 'UTR-784512';
      _notes.text = 'Goods once sold will not be taken back.';
      _terms.text = 'Payment due within 15 days from invoice date.';
      _extraCharges = [
        _ChargeControllers(
          label: TextEditingController(text: 'Packing'),
          amount: TextEditingController(text: '250'),
        ),
        _ChargeControllers(
          label: TextEditingController(text: 'Shipping'),
          amount: TextEditingController(text: '450'),
        ),
      ];
      for (final charge in _extraCharges) {
        charge.addListener(_refresh);
      }

      for (final item in _items) {
        item.dispose();
      }
      for (final charge in _extraCharges) {
        charge.dispose();
      }
      _items = [
        _demoItem(
          name: 'Thermal Invoice Printer',
          hsnSac: '8443',
          quantity: '1',
          unit: 'pcs',
          rate: '12500',
          gstRate: '18',
          customFields: lineFieldNames,
        ),
        _demoItem(
          name: 'Installation & Setup',
          hsnSac: '9987',
          quantity: '1',
          unit: 'service',
          rate: '2500',
          gstRate: '18',
          customFields: lineFieldNames,
        ),
      ];
      for (final item in _items) {
        _attachItem(item);
      }
    });
  }

  _ItemControllers _demoItem({
    required String name,
    required String hsnSac,
    required String quantity,
    required String unit,
    required String rate,
    required String gstRate,
    required List<String> customFields,
  }) {
    return _ItemControllers(
      productId: '',
      name: TextEditingController(text: name),
      description: TextEditingController(),
      hsnSac: TextEditingController(text: hsnSac),
      quantity: TextEditingController(text: quantity),
      unit: TextEditingController(text: unit),
      rate: TextEditingController(text: rate),
      gstInclusiveRate: TextEditingController(text: '0.0'),
      gstRate: TextEditingController(text: gstRate),
      customFields: {
        for (final field in customFields) field: _demoValueForField(field),
      },
    );
  }

  String _demoValueForField(String field) {
    final key = field.toLowerCase();
    if (key.contains('state') && key.contains('code')) return '33';
    if (key.contains('contact')) return 'Yuvraj';
    if (key.contains('transport')) return 'ABC Transport';
    if (key == 'lr no' || key.contains('lr')) return 'LR-45821';
    if (key.contains('batch')) return 'B-2026-05';
    if (key.contains('serial')) return 'SN-PRN-1007';
    if (key.contains('warranty')) return '1 Year';
    if (key.contains('code')) return 'DEMO-01';
    return 'Demo value';
  }

  void _addItem() {
    setState(() {
      final settings = context.read<InvoiceCubit>().state.settings;
      final item = settings == null
          ? _ItemControllers.empty()
          : _ItemControllers.fromItem(
              InvoiceItem.empty().copyWith(
                unit: settings.defaultLineItemUnit,
                gstRate: settings.defaultGstRate,
              ),
            );
      _attachItem(item);
      _items.add(item);
    });
  }

  void _addCharge() {
    setState(() {
      final charge = _ChargeControllers.empty();
      charge.addListener(_refresh);
      _extraCharges.add(charge);
    });
  }

  void _removeCharge(_ChargeControllers charge) {
    setState(() {
      charge.dispose();
      _extraCharges.remove(charge);
    });
  }

  void _removeItem(_ItemControllers item) {
    if (_items.length == 1) return;
    setState(() {
      item.dispose();
      _items.remove(item);
    });
  }

  Future<void> _save(
    BuildContext context, {
    InvoiceStatus? statusOverride,
  }) async {
    final effectiveStatus = statusOverride ?? _status;
    final requiresStrictValidation = _requiresStrictValidation(effectiveStatus);
    if (requiresStrictValidation && !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Complete the required fields.')),
        );
      return;
    }
    Customer? existingCustomer = _selectedCustomer;
    if (requiresStrictValidation) {
      final resolvedCustomer = await _resolveCustomerBeforeSave(
        context.read<InvoiceCubit>().state.customers,
      );
      if (!context.mounted || resolvedCustomer.isCancelled) {
        return;
      }
      existingCustomer = resolvedCustomer.customer ?? _selectedCustomer;
    }
    if (!context.mounted) return;
    if (statusOverride != null && _status != effectiveStatus) {
      setState(() => _status = effectiveStatus);
    }
    final draft = InvoiceDraft(
      existingCustomer: existingCustomer,
      customerName: _customerName.text.trim(),
      customerPhone: _phone.text.trim(),
      customerEmail: _email.text.trim(),
      customerGstin: _gstin.text.trim(),
      customerState: _state.text.trim(),
      customerStateCode: _showCustomerStateCode ? _stateCode.text.trim() : '',
      billingAddress: _billingAddress.text.trim(),
      shippingEnabled: _shippingEnabled,
      shippingAddress: _shippingEnabled ? _shippingAddress.text.trim() : '',
      shipToName: _shippingEnabled ? _shipToName.text.trim() : '',
      shipToPhone: _shippingEnabled ? _shipToPhone.text.trim() : '',
      shipToEmail: _shippingEnabled ? _shipToEmail.text.trim() : '',
      shipToState: _shippingEnabled ? _shipToState.text.trim() : '',
      shipToStateCode: _shippingEnabled && _showCustomerStateCode
          ? _shipToStateCode.text.trim()
          : '',
      shipToPincode: _shippingEnabled ? _shipToPincode.text.trim() : '',
      shippingCustomFields: _shippingEnabled
          ? _shippingCustomFields.map((key, controller) {
              return MapEntry(key, controller.text.trim());
            })
          : const {},
      customerCustomFields: _customerCustomFields.map((key, controller) {
        return MapEntry(key, controller.text.trim());
      }),
      invoiceDate: _invoiceDate,
      dueDate: _dueDate,
      taxMode: _taxMode,
      status: effectiveStatus,
      roundOffEnabled: _roundOffEnabled,
      discountType: _amountsEnabled ? _discountType : 'none',
      discountValue: _amountsEnabled ? _parsedAmount(_discountValue) : 0,
      extraCharges: _amountsEnabled
          ? _extraCharges.map((charge) => charge.toCharge()).toList()
          : const [],
      advancePaid: _amountsEnabled ? _parsedAmount(_advancePaid) : 0,
      advancePaidDate: _amountsEnabled ? _advancePaidDate : null,
      advancePaidMethod: _amountsEnabled ? _advancePaidMethod.text.trim() : '',
      advancePaidReference: _amountsEnabled
          ? _advancePaidReference.text.trim()
          : '',
      items: _items.map((item) => item.toItem()).toList(),
      notes: _notes.text.trim(),
      terms: _terms.text.trim(),
    );
    final editInvoice = widget.args?.mode == CreateInvoiceMode.edit
        ? widget.args?.sourceInvoice
        : null;
    if (editInvoice != null) {
      context.read<InvoiceCubit>().updateInvoiceFromDraft(editInvoice, draft);
      return;
    }
    context.read<InvoiceCubit>().saveDraft(draft);
  }

  bool _requiresStrictValidation(InvoiceStatus status) {
    return status != InvoiceStatus.draft && status != InvoiceStatus.cancelled;
  }

  Future<_CustomerResolve> _resolveCustomerBeforeSave(
    List<Customer> customers,
  ) async {
    final phone = _phone.text.trim().toLowerCase();
    final name = _customerName.text.trim();
    final normalizedName = _normalizeCustomerName(name);
    final selected = _selectedCustomer;
    final phoneMatches = phone.isEmpty
        ? <Customer>[]
        : customers
              .where(
                (customer) =>
                    customer.phone.trim().toLowerCase() == phone &&
                    customer.id != selected?.id,
              )
              .toList();
    final phoneOwner = phoneMatches.isEmpty ? null : phoneMatches.first;

    if (selected != null && phoneOwner != null) {
      final action = await _showSelectedCustomerPhoneConflict(
        context,
        selectedCustomer: selected,
        phoneOwner: phoneOwner,
      );
      if (!mounted) return _CustomerResolve.cancelled;
      if (action == _SelectedCustomerConflictAction.cancel) {
        return _CustomerResolve.cancelled;
      }
      if (action == _SelectedCustomerConflictAction.usePhoneOwner) {
        _applyCustomer(phoneOwner);
        return _CustomerResolve(phoneOwner);
      }
      return _CustomerResolve(selected);
    }

    if (selected == null && phoneOwner != null) {
      final useExisting = await _showExistingPhoneCustomerDialog(
        context,
        phoneOwner,
      );
      if (!mounted) return _CustomerResolve.cancelled;
      if (useExisting == null) return _CustomerResolve.cancelled;
      if (useExisting) {
        setState(() => _selectedCustomer = phoneOwner);
        return _CustomerResolve(phoneOwner);
      }
    }

    if (selected == null && normalizedName.isNotEmpty) {
      final possibleMatches = customers
          .where((customer) {
            final existingName = _normalizeCustomerName(customer.name);
            if (existingName.isEmpty) return false;
            if (customer.phone.trim().toLowerCase() == phone) return false;
            return existingName == normalizedName ||
                existingName.contains(normalizedName) ||
                normalizedName.contains(existingName);
          })
          .take(5)
          .toList();
      if (possibleMatches.isNotEmpty) {
        final chosen = await _showPossibleDuplicateCustomerDialog(
          context,
          possibleMatches,
        );
        if (!mounted) return _CustomerResolve.cancelled;
        if (chosen.isCancelled) {
          return _CustomerResolve.cancelled;
        }
        if (chosen.customer != null) {
          setState(() => _selectedCustomer = chosen.customer);
          return chosen;
        }
      }
    }

    return _CustomerResolve(_selectedCustomer);
  }

  String _normalizeCustomerName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<_SelectedCustomerConflictAction> _showSelectedCustomerPhoneConflict(
    BuildContext context, {
    required Customer selectedCustomer,
    required Customer phoneOwner,
  }) async {
    final action = await showDialog<_SelectedCustomerConflictAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Phone number already used'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This phone number belongs to ${phoneOwner.name}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _CustomerConflictTile(
                label: 'Selected customer',
                customer: selectedCustomer,
              ),
              const SizedBox(height: AppSpacing.sm),
              _CustomerConflictTile(label: 'Phone owner', customer: phoneOwner),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_SelectedCustomerConflictAction.cancel),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_SelectedCustomerConflictAction.keepSelected),
              child: const Text('Keep Selected'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_SelectedCustomerConflictAction.usePhoneOwner),
              child: const Text('Use Phone Owner'),
            ),
          ],
        );
      },
    );
    return action ?? _SelectedCustomerConflictAction.cancel;
  }

  Future<bool?> _showExistingPhoneCustomerDialog(
    BuildContext context,
    Customer customer,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Existing customer found'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This phone number is already saved. Use that customer so loyalty and invoice history stay together.',
              ),
              const SizedBox(height: AppSpacing.md),
              _CustomerConflictTile(
                label: 'Matched customer',
                customer: customer,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Use Existing Customer'),
            ),
          ],
        );
      },
    );
  }

  Future<_CustomerResolve> _showPossibleDuplicateCustomerDialog(
    BuildContext context,
    List<Customer> customers,
  ) async {
    final chosen = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Possible duplicate customer'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A similar customer already exists. Choose one to merge history, or create a new customer.',
                ),
                const SizedBox(height: AppSpacing.md),
                for (final customer in customers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _CustomerConflictTile(
                      label: 'Possible match',
                      customer: customer,
                      onTap: () => Navigator.of(context).pop(customer),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_CustomerDialogExit.createNew),
              child: const Text('Create New'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_CustomerDialogExit.cancel),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (chosen == _CustomerDialogExit.cancel) return _CustomerResolve.cancelled;
    if (chosen == _CustomerDialogExit.createNew) {
      return const _CustomerResolve(null);
    }
    return _CustomerResolve(chosen is Customer ? chosen : null);
  }

  TextEditingController _customerCustomField(String field) {
    return _customerCustomFields.putIfAbsent(field, () {
      final definition = _currentSettingsCustomField(
        context.read<InvoiceCubit>().state.settings?.customCustomerFields,
        field,
      );
      final controller = TextEditingController(
        text: definition?.defaultValue ?? '',
      );
      controller.addListener(_refresh);
      return controller;
    });
  }

  void _ensureCustomerCustomFields(List<CustomFieldDefinition> fields) {
    for (final field in fields) {
      _customerCustomField(field.name);
    }
    final allowed = fields.map((field) => field.name.toLowerCase()).toSet();
    final staleKeys = _customerCustomFields.keys
        .where((field) => !allowed.contains(field.toLowerCase()))
        .toList();
    for (final key in staleKeys) {
      _customerCustomFields.remove(key)
        ?..removeListener(_refresh)
        ..dispose();
    }
  }

  TextEditingController _shippingCustomField(String field) {
    return _shippingCustomFields.putIfAbsent(field, () {
      final definition = _currentSettingsCustomField(
        context.read<InvoiceCubit>().state.settings?.customShippingFields,
        field,
      );
      final controller = TextEditingController(
        text: definition?.defaultValue ?? '',
      );
      controller.addListener(_refresh);
      return controller;
    });
  }

  void _ensureShippingCustomFields(List<CustomFieldDefinition> fields) {
    for (final field in fields) {
      _shippingCustomField(field.name);
    }
    final allowed = fields.map((field) => field.name.toLowerCase()).toSet();
    final staleKeys = _shippingCustomFields.keys
        .where((field) => !allowed.contains(field.toLowerCase()))
        .toList();
    for (final key in staleKeys) {
      _shippingCustomFields.remove(key)
        ?..removeListener(_refresh)
        ..dispose();
    }
  }

  _InvoiceTotals _calculateTotals() {
    final totals = _calculator.calculate(
      items: _items.map((item) => item.toItem()).toList(),
      taxMode: _taxMode,
      roundOffEnabled: _roundOffEnabled,
      discountType: _amountsEnabled ? _discountType : 'none',
      discountValue: _amountsEnabled ? _parsedAmount(_discountValue) : 0,
      extraCharges: _amountsEnabled
          ? _extraCharges.map((charge) => charge.toCharge()).toList()
          : const [],
    );
    return _InvoiceTotals(
      subtotal: totals.subtotal,
      discountTotal: totals.discountTotal,
      extraChargeTotal: totals.extraChargeTotal,
      taxableAmount: totals.taxableAmount,
      cgst: totals.cgstAmount,
      sgst: totals.sgstAmount,
      igst: totals.igstAmount,
      roundOff: totals.roundOffAmount,
      grandTotal: totals.grandTotal,
    );
  }

  String _invoiceNumberPreview(InvoiceState state) {
    if (widget.args?.mode == CreateInvoiceMode.edit) {
      final sourceInvoice = widget.args?.sourceInvoice;
      final invoiceNumber = sourceInvoice?.invoiceNumber;
      final isAlreadyNumbered =
          sourceInvoice != null &&
          sourceInvoice.invoiceSequence > 0 &&
          invoiceNumber != null &&
          invoiceNumber.trim().isNotEmpty;
      if (isAlreadyNumbered) {
        return invoiceNumber;
      }
    }
    if (_status == InvoiceStatus.draft || _status == InvoiceStatus.cancelled) {
      return 'Draft invoice';
    }
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
    return [
      settings.invoicePrefix,
      date,
      sequence,
    ].where((segment) => segment.trim().isNotEmpty).join(separator);
  }

  void _refresh() {
    if (_isSeedingControllers) return;
    if (mounted) setState(() {});
  }

  bool _hasAmountsData(InvoiceDraft draft) {
    return draft.discountType != 'none' ||
        draft.discountValue > 0 ||
        draft.extraCharges.any(
          (charge) => charge.label.trim().isNotEmpty || charge.amount.abs() > 0,
        ) ||
        draft.advancePaid > 0 ||
        draft.advancePaidDate != null ||
        draft.advancePaidMethod.trim().isNotEmpty ||
        draft.advancePaidReference.trim().isNotEmpty;
  }

  void _setAmountsEnabled(bool value) {
    setState(() {
      _amountsEnabled = value;
      if (value) return;
      _discountType = 'none';
      _discountValue.clear();
      _advancePaid.clear();
      _advancePaidDate = null;
      _advancePaidMethod.clear();
      _advancePaidReference.clear();
      for (final charge in _extraCharges) {
        charge.dispose();
      }
      _extraCharges = [];
    });
  }

  void _attachItem(_ItemControllers item) {
    item.addListener(_refresh, onHsnChanged: (_) => _applyHsnRate(item));
  }

  double _parsedAmount(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  String _formatEditableNumber(double value) {
    if (value == 0) return '';
    return InvoiceCalculator().formatRateInput(value);
  }

  List<InvoicePaymentRecord> _buildDraftPaymentHistoryPreview() {
    if (!_amountsEnabled) return const [];
    final amount = _parsedAmount(_advancePaid);
    if (amount <= 0) return const [];
    return [
      InvoicePaymentRecord(
        amount: amount,
        paidAt: _advancePaidDate ?? _invoiceDate,
        method: _advancePaidMethod.text.trim(),
        reference: _advancePaidReference.text.trim(),
        notes: 'Advance payment',
      ),
    ];
  }

  String _amountInWords(double amount) {
    return _NumberToWords.convert(amount);
  }

  void _applyHsnRate(_ItemControllers item) {
    final lookup = _hsnGstLookup;
    if (lookup == null) return;
    final matchedRate = lookup.findRate(item.hsnSac.text.trim());
    if (matchedRate == null) return;
    final formatted = InvoiceCalculator().formatRateInput(matchedRate);
    if (item.gstRate.text != formatted) {
      item.gstRate.text = formatted;
    }
  }

  CustomFieldDefinition? _currentSettingsCustomField(
    List<CustomFieldDefinition>? fields,
    String name,
  ) {
    if (fields == null) return null;
    for (final field in fields) {
      if (field.name.toLowerCase() == name.toLowerCase()) return field;
    }
    return null;
  }
}

class _EditorForm extends StatelessWidget {
  const _EditorForm({
    required this.customers,
    required this.products,
    required this.customCustomerFields,
    required this.customerCustomFieldControllers,
    required this.customShippingFields,
    required this.shippingCustomFieldControllers,
    required this.showLineItemHsn,
    required this.customLineItemFields,
    required this.selectedCustomer,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.state,
    required this.stateCode,
    required this.showCustomerStateCode,
    required this.billingAddress,
    required this.gstinLookupEnabled,
    required this.gstinValidation,
    required this.isLookingUpGstin,
    required this.shippingEnabled,
    required this.shippingAddress,
    required this.shipToName,
    required this.shipToPhone,
    required this.shipToEmail,
    required this.shipToState,
    required this.shipToStateCode,
    required this.shipToPincode,
    required this.invoiceDate,
    required this.dueDate,
    required this.taxMode,
    required this.status,
    required this.roundOffEnabled,
    required this.amountsEnabled,
    required this.discountType,
    required this.discountValue,
    required this.extraCharges,
    required this.advancePaid,
    required this.advancePaidDate,
    required this.advancePaidMethod,
    required this.advancePaidReference,
    required this.items,
    required this.notes,
    required this.terms,
    required this.onPickCustomer,
    required this.onLookupGstin,
    required this.onShippingEnabledChanged,
    required this.onUseBillingForShipping,
    required this.onInvoiceDateChanged,
    required this.onDueDateChanged,
    required this.onTaxModeChanged,
    required this.onRoundOffChanged,
    required this.onAmountsEnabledChanged,
    required this.onDiscountTypeChanged,
    required this.onAdvancePaidDateChanged,
    required this.onAddCharge,
    required this.onRemoveCharge,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onChanged,
    required this.onProductApplied,
  });

  final List<Customer> customers;
  final List<ProductService> products;
  final List<CustomFieldDefinition> customCustomerFields;
  final Map<String, TextEditingController> customerCustomFieldControllers;
  final List<CustomFieldDefinition> customShippingFields;
  final Map<String, TextEditingController> shippingCustomFieldControllers;
  final bool showLineItemHsn;
  final List<CustomFieldDefinition> customLineItemFields;
  final Customer? selectedCustomer;
  final TextEditingController customerName;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController gstin;
  final TextEditingController state;
  final TextEditingController stateCode;
  final bool showCustomerStateCode;
  final TextEditingController billingAddress;
  final bool gstinLookupEnabled;
  final _GstinValidationState? gstinValidation;
  final bool isLookingUpGstin;
  final bool shippingEnabled;
  final TextEditingController shippingAddress;
  final TextEditingController shipToName;
  final TextEditingController shipToPhone;
  final TextEditingController shipToEmail;
  final TextEditingController shipToState;
  final TextEditingController shipToStateCode;
  final TextEditingController shipToPincode;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final TaxMode taxMode;
  final InvoiceStatus status;
  final bool roundOffEnabled;
  final bool amountsEnabled;
  final String discountType;
  final TextEditingController discountValue;
  final List<_ChargeControllers> extraCharges;
  final TextEditingController advancePaid;
  final DateTime? advancePaidDate;
  final TextEditingController advancePaidMethod;
  final TextEditingController advancePaidReference;
  final List<_ItemControllers> items;
  final TextEditingController notes;
  final TextEditingController terms;
  final ValueChanged<Customer> onPickCustomer;
  final VoidCallback onLookupGstin;
  final ValueChanged<bool> onShippingEnabledChanged;
  final VoidCallback onUseBillingForShipping;
  final ValueChanged<DateTime> onInvoiceDateChanged;
  final ValueChanged<DateTime> onDueDateChanged;
  final ValueChanged<TaxMode> onTaxModeChanged;
  final ValueChanged<bool> onRoundOffChanged;
  final ValueChanged<bool> onAmountsEnabledChanged;
  final ValueChanged<String> onDiscountTypeChanged;
  final ValueChanged<DateTime> onAdvancePaidDateChanged;
  final VoidCallback onAddCharge;
  final ValueChanged<_ChargeControllers> onRemoveCharge;
  final VoidCallback onAddItem;
  final ValueChanged<_ItemControllers> onRemoveItem;
  final VoidCallback onChanged;
  final ValueChanged<_ItemControllers> onProductApplied;

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
          stateCode: stateCode,
          showCustomerStateCode: showCustomerStateCode,
          billingAddress: billingAddress,
          gstinLookupEnabled: gstinLookupEnabled,
          gstinValidation: gstinValidation,
          isLookingUpGstin: isLookingUpGstin,
          customFields: customCustomerFields,
          customFieldControllers: customerCustomFieldControllers,
          onPickCustomer: onPickCustomer,
          onLookupGstin: onLookupGstin,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ShippedToPanel(
          enabled: shippingEnabled,
          shipToName: shipToName,
          shipToPhone: shipToPhone,
          shipToEmail: shipToEmail,
          shippingAddress: shippingAddress,
          shipToState: shipToState,
          shipToStateCode: shipToStateCode,
          shipToPincode: shipToPincode,
          customFields: customShippingFields,
          customFieldControllers: shippingCustomFieldControllers,
          onEnabledChanged: onShippingEnabledChanged,
          onUseBillingDetails: onUseBillingForShipping,
          showStateCode: showCustomerStateCode,
        ),
        const SizedBox(height: AppSpacing.lg),
        _InvoiceMetaPanel(
          invoiceDate: invoiceDate,
          dueDate: dueDate,
          taxMode: taxMode,
          status: status,
          roundOffEnabled: roundOffEnabled,
          onInvoiceDateChanged: onInvoiceDateChanged,
          onDueDateChanged: onDueDateChanged,
          onTaxModeChanged: onTaxModeChanged,
          onRoundOffChanged: onRoundOffChanged,
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
          onProductApplied: onProductApplied,
        ),
        const SizedBox(height: AppSpacing.lg),
        _AmountsPanel(
          enabled: amountsEnabled,
          discountType: discountType,
          discountValue: discountValue,
          extraCharges: extraCharges,
          advancePaid: advancePaid,
          advancePaidDate: advancePaidDate,
          advancePaidMethod: advancePaidMethod,
          advancePaidReference: advancePaidReference,
          onEnabledChanged: onAmountsEnabledChanged,
          onDiscountTypeChanged: onDiscountTypeChanged,
          onAdvancePaidDateChanged: onAdvancePaidDateChanged,
          onAddCharge: onAddCharge,
          onRemoveCharge: onRemoveCharge,
        ),
        const SizedBox(height: AppSpacing.lg),
        _NotesPanel(notes: notes, terms: terms),
      ],
    );
  }
}

class _CommandBar extends StatelessWidget {
  const _CommandBar({
    required this.title,
    required this.invoiceNumber,
    required this.isSaving,
    required this.isEdit,
    required this.currentStatus,
    required this.onBack,
    required this.onFillDemo,
    required this.onSaveDraft,
    required this.onFinalize,
    required this.onSave,
  });

  final String title;
  final String invoiceNumber;
  final bool isSaving;
  final bool isEdit;
  final InvoiceStatus currentStatus;
  final VoidCallback onBack;
  final VoidCallback onFillDemo;
  final VoidCallback onSaveDraft;
  final VoidCallback onFinalize;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
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
                  title,
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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: isSaving ? null : onFillDemo,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Demo Data'),
              ),
              if (!isEdit || currentStatus == InvoiceStatus.draft)
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onSaveDraft,
                  icon: const Icon(Icons.drafts_outlined),
                  label: const Text('Save Draft'),
                ),
              ElevatedButton.icon(
                onPressed: isSaving
                    ? null
                    : isEdit && currentStatus != InvoiceStatus.draft
                    ? onSave
                    : onFinalize,
                icon: isSaving
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onAccent,
                        ),
                      )
                    : Icon(
                        isEdit && currentStatus != InvoiceStatus.draft
                            ? Icons.save_outlined
                            : Icons.verified_outlined,
                      ),
                label: Text(
                  isSaving
                      ? 'Saving...'
                      : isEdit && currentStatus != InvoiceStatus.draft
                      ? 'Save Changes'
                      : 'Finalize Invoice',
                ),
              ),
            ],
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
    required this.stateCode,
    required this.showCustomerStateCode,
    required this.billingAddress,
    required this.gstinLookupEnabled,
    required this.gstinValidation,
    required this.isLookingUpGstin,
    required this.customFields,
    required this.customFieldControllers,
    required this.onPickCustomer,
    required this.onLookupGstin,
  });

  final List<Customer> customers;
  final Customer? selectedCustomer;
  final TextEditingController customerName;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController gstin;
  final TextEditingController state;
  final TextEditingController stateCode;
  final bool showCustomerStateCode;
  final TextEditingController billingAddress;
  final bool gstinLookupEnabled;
  final _GstinValidationState? gstinValidation;
  final bool isLookingUpGstin;
  final List<CustomFieldDefinition> customFields;
  final Map<String, TextEditingController> customFieldControllers;
  final ValueChanged<Customer> onPickCustomer;
  final VoidCallback onLookupGstin;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.person_outline,
      title: 'Invoice Detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldCaption('Billed to'),
          _CustomerDropdownField(
            controller: customerName,
            customers: customers,
            selectedCustomer: selectedCustomer,
            label: 'Customer Name',
            hintText: 'Enter customer name',
            icon: Icons.person_outline,
            requiredField: true,
            displayStringForOption: (customer) => customer.name,
            optionMatchesQuery: (customer, query) {
              return customer.name.toLowerCase().contains(query) ||
                  customer.email.toLowerCase().contains(query);
            },
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? 'Customer name is required'
                : null,
            onPickCustomer: onPickCustomer,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _CustomerDropdownField(
                  controller: phone,
                  customers: customers,
                  selectedCustomer: selectedCustomer,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  requiredField: true,
                  displayStringForOption: (customer) => customer.phone,
                  optionMatchesQuery: (customer, query) {
                    return customer.phone.toLowerCase().contains(query) ||
                        customer.name.toLowerCase().contains(query);
                  },
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Phone is required'
                      : null,
                  onPickCustomer: onPickCustomer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _Field(email, 'Email')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 11,
                child: _Field(
                  gstin,
                  'GSTIN',
                  suffixIcon: gstinLookupEnabled
                      ? Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: Tooltip(
                            message: isLookingUpGstin
                                ? 'Fetching GST details'
                                : 'Fetch business details from GSTIN',
                            child: IconButton(
                              onPressed: isLookingUpGstin
                                  ? null
                                  : onLookupGstin,
                              icon: isLookingUpGstin
                                  ? SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryPurple,
                                      ),
                                    )
                                  : const Icon(Icons.travel_explore_outlined),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 10, child: _Field(state, 'State')),
            ],
          ),
          if (gstinLookupEnabled && gstinValidation != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _GstinValidationBanner(validation: gstinValidation!),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _Field(billingAddress, 'Billing Address')),
            ],
          ),
          if (showCustomerStateCode) ...[
            const SizedBox(height: AppSpacing.md),
            Row(children: [_Field(stateCode, 'State Code', width: 260)]),
          ],
          if (customFields.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final field in customFields)
                  _Field(
                    customFieldControllers[field.name]!,
                    field.name,
                    width: 260,
                    requiredField: field.isRequired,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShippedToPanel extends StatelessWidget {
  const _ShippedToPanel({
    required this.enabled,
    required this.shipToName,
    required this.shipToPhone,
    required this.shipToEmail,
    required this.shippingAddress,
    required this.shipToState,
    required this.shipToStateCode,
    required this.shipToPincode,
    required this.customFields,
    required this.customFieldControllers,
    required this.onEnabledChanged,
    required this.onUseBillingDetails,
    required this.showStateCode,
  });

  final bool enabled;
  final TextEditingController shipToName;
  final TextEditingController shipToPhone;
  final TextEditingController shipToEmail;
  final TextEditingController shippingAddress;
  final TextEditingController shipToState;
  final TextEditingController shipToStateCode;
  final TextEditingController shipToPincode;
  final List<CustomFieldDefinition> customFields;
  final Map<String, TextEditingController> customFieldControllers;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onUseBillingDetails;
  final bool showStateCode;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.local_shipping_outlined,
      title: 'Shipped To',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SwitchRow(
                  title: 'Add Shipping Details',
                  subtitle: enabled
                      ? 'Shipping data will be saved with this invoice.'
                      : 'Shipping fields will not be saved for this invoice.',
                  value: enabled,
                  onChanged: onEnabledChanged,
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: onUseBillingDetails,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Use billing details'),
                ),
              ],
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _Field(shipToName, 'Ship To Name')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _Field(shipToPhone, 'Shipping Phone')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _Field(shipToEmail, 'Shipping Email')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _Field(shipToState, 'Shipping State')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _Field(shippingAddress, 'Shipping Address')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _Field(shipToPincode, 'Shipping Pincode')),
              ],
            ),
            if (showStateCode) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _Field(shipToStateCode, 'Shipping State Code', width: 260),
                ],
              ),
            ],
            if (customFields.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final field in customFields)
                    _Field(
                      customFieldControllers[field.name]!,
                      field.name,
                      width: 260,
                      requiredField: field.isRequired,
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CustomerDropdownField extends StatefulWidget {
  const _CustomerDropdownField({
    required this.controller,
    required this.customers,
    required this.selectedCustomer,
    required this.label,
    required this.icon,
    this.requiredField = false,
    required this.displayStringForOption,
    required this.optionMatchesQuery,
    required this.onPickCustomer,
    this.hintText,
    this.validator,
  });

  final TextEditingController controller;
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final String label;
  final String? hintText;
  final IconData icon;
  final bool requiredField;
  final String Function(Customer customer) displayStringForOption;
  final bool Function(Customer customer, String query) optionMatchesQuery;
  final ValueChanged<Customer> onPickCustomer;
  final String? Function(String? value)? validator;

  @override
  State<_CustomerDropdownField> createState() => _CustomerDropdownFieldState();
}

class _CustomerDropdownFieldState extends State<_CustomerDropdownField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Customer>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: widget.displayStringForOption,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<Customer>.empty();
        return widget.customers
            .where((customer) => widget.optionMatchesQuery(customer, query))
            .take(20);
      },
      onSelected: widget.onPickCustomer,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: widget.requiredField
                    ? '${widget.label} *'
                    : widget.label,
                hintText: widget.hintText,
                prefixIcon: Icon(widget.icon),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              validator: widget.validator,
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        final visibleOptions = options.take(12).toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 280),
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: visibleOptions.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                  itemBuilder: (context, index) {
                    final customer = visibleOptions[index];
                    final selected = widget.selectedCustomer?.id == customer.id;
                    return InkWell(
                      onTap: () => onSelected(customer),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.person_outline,
                              color: selected
                                  ? AppColors.success
                                  : AppColors.primaryPurple,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name.isEmpty
                                        ? 'Unnamed customer'
                                        : customer.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  Text(
                                    customer.phone.isEmpty
                                        ? 'No phone'
                                        : customer.phone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
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

class _GstinValidationBanner extends StatelessWidget {
  const _GstinValidationBanner({required this.validation});

  final _GstinValidationState validation;

  @override
  Widget build(BuildContext context) {
    final isValid = validation.isValid;
    final color = isValid ? AppColors.success : AppColors.warning;
    final background = color.withValues(alpha: 0.12);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.verified_outlined : Icons.warning_amber_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isValid
                  ? 'GSTIN format is valid. You can fetch business details now.'
                  : 'GSTIN format looks invalid. Fix it before fetching details.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calculate_outlined,
            color: value ? AppColors.primaryPurple : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _StatusIntentField extends StatelessWidget {
  const _StatusIntentField({required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Status',
        prefixIcon: Icon(Icons.payments_outlined),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
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
    required this.roundOffEnabled,
    required this.onInvoiceDateChanged,
    required this.onDueDateChanged,
    required this.onTaxModeChanged,
    required this.onRoundOffChanged,
  });

  final DateTime invoiceDate;
  final DateTime dueDate;
  final TaxMode taxMode;
  final InvoiceStatus status;
  final bool roundOffEnabled;
  final ValueChanged<DateTime> onInvoiceDateChanged;
  final ValueChanged<DateTime> onDueDateChanged;
  final ValueChanged<TaxMode> onTaxModeChanged;
  final ValueChanged<bool> onRoundOffChanged;

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
                  decoration: const InputDecoration(
                    labelText: 'Tax Mode',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
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
              Expanded(child: _StatusIntentField(status: status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SwitchRow(
            title: 'Round Off This Invoice',
            subtitle: 'Round the grand total to the nearest rupee.',
            value: roundOffEnabled,
            onChanged: onRoundOffChanged,
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
    required this.onProductApplied,
  });

  final List<_ItemControllers> items;
  final List<ProductService> products;
  final bool showHsnSac;
  final List<CustomFieldDefinition> customFields;
  final VoidCallback onAdd;
  final ValueChanged<_ItemControllers> onRemove;
  final VoidCallback onChanged;
  final ValueChanged<_ItemControllers> onProductApplied;

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
                onProductApplied: () => onProductApplied(item),
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
    required this.onProductApplied,
  });

  final _ItemControllers item;
  final List<ProductService> products;
  final bool showHsnSac;
  final List<CustomFieldDefinition> customFields;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onProductApplied;

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
                  decoration: const InputDecoration(
                    labelText: 'Saved item',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
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
                    onProductApplied();
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: item.name,
                  decoration: const InputDecoration(
                    labelText: 'Item name *',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Item name is required'
                      : null,
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
              _SmallField(
                item.quantity,
                'Quantity',
                width: 116,
                requiredField: true,
                mustBeGreaterThanZero: true,
              ),
              _SmallField(
                item.unit,
                'Unit',
                width: 140,
                numeric: false,
                requiredField: true,
              ),
              _SmallField(
                item.rate,
                'Rate',
                width: 150,
                requiredField: true,
                mustBeGreaterThanZero: true,
              ),
              _SmallField(item.gstInclusiveRate, 'Rate incl. GST', width: 170),
              _SmallField(
                item.gstRate,
                'GST %',
                width: 120,
                requiredField: true,
                minValue: 0,
                maxValue: 100,
              ),
              if (showHsnSac)
                _SmallField(item.hsnSac, 'HSN/SAC', width: 150, numeric: false),
              for (final field in customFields)
                _SmallField(
                  item.customField(field.name),
                  field.name,
                  width: 150,
                  numeric: false,
                  requiredField: field.isRequired,
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

class _AmountsPanel extends StatelessWidget {
  const _AmountsPanel({
    required this.enabled,
    required this.discountType,
    required this.discountValue,
    required this.extraCharges,
    required this.advancePaid,
    required this.advancePaidDate,
    required this.advancePaidMethod,
    required this.advancePaidReference,
    required this.onEnabledChanged,
    required this.onDiscountTypeChanged,
    required this.onAdvancePaidDateChanged,
    required this.onAddCharge,
    required this.onRemoveCharge,
  });

  final bool enabled;
  final String discountType;
  final TextEditingController discountValue;
  final List<_ChargeControllers> extraCharges;
  final TextEditingController advancePaid;
  final DateTime? advancePaidDate;
  final TextEditingController advancePaidMethod;
  final TextEditingController advancePaidReference;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onDiscountTypeChanged;
  final ValueChanged<DateTime> onAdvancePaidDateChanged;
  final VoidCallback onAddCharge;
  final ValueChanged<_ChargeControllers> onRemoveCharge;

  @override
  Widget build(BuildContext context) {
    final helperStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    if (!enabled) {
      return _Panel(
        icon: Icons.calculate_outlined,
        title: 'Discounts, Charges & Payments',
        trailing: Switch.adaptive(value: enabled, onChanged: onEnabledChanged),
        child: Text(
          'Enable this only when you need discounts, extra charges, or payment details.',
          style: helperStyle,
        ),
      );
    }

    return _Panel(
      icon: Icons.calculate_outlined,
      title: 'Discounts, Charges & Payments',
      trailing: Switch.adaptive(value: enabled, onChanged: onEnabledChanged),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'These optional values will be saved with this invoice.',
            style: helperStyle,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: discountType,
                  decoration: const InputDecoration(
                    labelText: 'Discount Type',
                    prefixIcon: Icon(Icons.percent_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('No discount')),
                    DropdownMenuItem(
                      value: 'percentage',
                      child: Text('Percentage'),
                    ),
                    DropdownMenuItem(value: 'amount', child: Text('Amount')),
                  ],
                  onChanged: (value) {
                    if (value != null) onDiscountTypeChanged(value);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _SmallField(
                discountValue,
                discountType == 'percentage' ? 'Discount %' : 'Discount Amount',
                width: 180,
                minValue: 0,
                maxValue: discountType == 'percentage' ? 100 : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                'Extra Charges',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onAddCharge,
                icon: const Icon(Icons.add),
                label: const Text('Add Charge'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (extraCharges.isEmpty)
            Text(
              'No extra charges added.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            )
          else
            Column(
              children: [
                for (final charge in extraCharges)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(child: _Field(charge.label, 'Charge Label')),
                        const SizedBox(width: AppSpacing.md),
                        _SmallField(
                          charge.amount,
                          'Amount',
                          width: 160,
                          minValue: 0,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          onPressed: () => onRemoveCharge(charge),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Advance / Paid Amount',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _SmallField(advancePaid, 'Advance Paid', width: 160, minValue: 0),
              SizedBox(
                width: 220,
                child: _DateField(
                  label: 'Payment Date',
                  date: advancePaidDate ?? DateTime.now(),
                  onChanged: onAdvancePaidDateChanged,
                ),
              ),
              SizedBox(width: 220, child: _Field(advancePaidMethod, 'Method')),
              SizedBox(
                width: 220,
                child: _Field(advancePaidReference, 'Reference'),
              ),
            ],
          ),
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
    required this.amountInWords,
    required this.amountPaid,
    required this.balanceDue,
    required this.paymentHistoryPreview,
    required this.paymentData,
    required this.isSaving,
    required this.isEdit,
    required this.onSaveDraft,
    required this.onFinalize,
    required this.onSave,
    this.expanded = false,
  });

  final String invoiceNumber;
  final String customerName;
  final InvoiceStatus status;
  final TaxMode taxMode;
  final _InvoiceTotals totals;
  final String amountInWords;
  final double amountPaid;
  final double balanceDue;
  final List<InvoicePaymentRecord> paymentHistoryPreview;
  final InvoicePaymentData? paymentData;
  final bool isSaving;
  final bool isEdit;
  final VoidCallback onSaveDraft;
  final VoidCallback onFinalize;
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
            if (totals.discountTotal > 0)
              _MoneyLine('Discount', -totals.discountTotal, signed: true),
            if (totals.extraChargeTotal > 0)
              _MoneyLine(
                'Extra Charges',
                totals.extraChargeTotal,
                signed: true,
              ),
            _MoneyLine('CGST', totals.cgst),
            _MoneyLine('SGST', totals.sgst),
            _MoneyLine('IGST', totals.igst),
            if (totals.roundOff != 0)
              _MoneyLine('Round Off', totals.roundOff, signed: true),
            const Divider(height: AppSpacing.xl),
            _MoneyLine('Grand Total', totals.grandTotal, strong: true),
            if (amountPaid > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              _MoneyLine('Amount Paid', amountPaid),
              _MoneyLine('Balance Due', balanceDue, strong: true),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Amount in Words',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$amountInWords only',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (paymentHistoryPreview.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Payment History',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final payment in paymentHistoryPreview)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PaymentPreviewRow(payment: payment),
                ),
            ],
            if (paymentData != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _PaymentQrPanel(paymentData: paymentData!),
            ],
            if (expanded)
              const SizedBox(height: AppSpacing.lg)
            else
              const Spacer(),
            _SummaryActions(
              isSaving: isSaving,
              isEdit: isEdit,
              status: status,
              onSaveDraft: onSaveDraft,
              onFinalize: onFinalize,
              onSave: onSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryActions extends StatelessWidget {
  const _SummaryActions({
    required this.isSaving,
    required this.isEdit,
    required this.status,
    required this.onSaveDraft,
    required this.onFinalize,
    required this.onSave,
  });

  final bool isSaving;
  final bool isEdit;
  final InvoiceStatus status;
  final VoidCallback onSaveDraft;
  final VoidCallback onFinalize;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final canSaveDraft = !isEdit || status == InvoiceStatus.draft;
    final primarySavesChanges = isEdit && status != InvoiceStatus.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canSaveDraft) ...[
          OutlinedButton.icon(
            onPressed: isSaving ? null : onSaveDraft,
            icon: const Icon(Icons.drafts_outlined),
            label: const Text('Save Draft'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ElevatedButton.icon(
          onPressed: isSaving
              ? null
              : primarySavesChanges
              ? onSave
              : onFinalize,
          icon: isSaving
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onAccent,
                  ),
                )
              : Icon(
                  primarySavesChanges
                      ? Icons.save_outlined
                      : Icons.verified_outlined,
                ),
          label: Text(
            isSaving
                ? 'Saving...'
                : primarySavesChanges
                ? 'Save Changes'
                : 'Finalize Invoice',
          ),
        ),
      ],
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

class _PaymentQrPanel extends StatelessWidget {
  const _PaymentQrPanel({required this.paymentData});

  final InvoicePaymentData paymentData;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: paymentData.isDynamic
                    ? QrImageView(
                        data: paymentData.qrPayload,
                        size: 104,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      )
                    : Image.memory(
                        paymentData.imageBytes!,
                        fit: BoxFit.contain,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paymentData.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      paymentData.helperText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'INR ${paymentData.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentPreviewRow extends StatelessWidget {
  const _PaymentPreviewRow({required this.payment});

  final InvoicePaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final date =
        '${payment.paidAt.day.toString().padLeft(2, '0')}/${payment.paidAt.month.toString().padLeft(2, '0')}/${payment.paidAt.year}';
    final details = [
      date,
      if (payment.method.trim().isNotEmpty) payment.method.trim(),
      if (payment.reference.trim().isNotEmpty) payment.reference.trim(),
    ].join('  •  ');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (payment.notes.trim().isNotEmpty)
                Text(
                  payment.notes.trim(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        Text(
          payment.amount.toStringAsFixed(2),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
  const _MoneyLine(
    this.label,
    this.value, {
    this.strong = false,
    this.signed = false,
  });

  final String label;
  final double value;
  final bool strong;
  final bool signed;

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
            _formattedValue,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String get _formattedValue {
    final formatted = value.toStringAsFixed(2);
    if (!signed || value <= 0) return formatted;
    return '+$formatted';
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
              if (trailing case final trailingWidget?) ...[trailingWidget],
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
        prefixIcon: Icon(_fieldIconFor(label)),
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
    this.requiredField = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final double? width;
  final int maxLines;
  final bool requiredField;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        prefixIcon: Icon(_fieldIconFor(label)),
        suffixIcon: suffixIcon,
      ),
      validator: requiredField
          ? (value) =>
                (value?.trim().isEmpty ?? true) ? '$label is required' : null
          : null,
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
    this.requiredField = false,
    this.mustBeGreaterThanZero = false,
    this.minValue,
    this.maxValue,
  });

  final TextEditingController controller;
  final String label;
  final double width;
  final bool numeric;
  final bool requiredField;
  final bool mustBeGreaterThanZero;
  final double? minValue;
  final double? maxValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: requiredField ? '$label *' : label,
          prefixIcon: Icon(_fieldIconFor(label), size: 20),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (requiredField && text.isEmpty) {
            return '$label is required';
          }
          if (!numeric) return null;
          if (text.isEmpty) return null;
          final number = double.tryParse(text);
          if (number == null) {
            return 'Invalid';
          }
          if (mustBeGreaterThanZero && number <= 0) {
            return 'Must be > 0';
          }
          final min = minValue;
          if (min != null && number < min) {
            return 'Min ${min.toStringAsFixed(0)}';
          }
          final max = maxValue;
          if (max != null && number > max) {
            return 'Max ${max.toStringAsFixed(0)}';
          }
          return null;
        },
      ),
    );
  }
}

IconData _fieldIconFor(String label) {
  final key = label.toLowerCase();
  if (key.contains('discount')) return Icons.percent_outlined;
  if (key.contains('advance') || key.contains('paid')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (key.contains('charge')) return Icons.add_card_outlined;
  if (key.contains('amount')) return Icons.currency_rupee_outlined;
  if (key.contains('method')) return Icons.payments_outlined;
  if (key.contains('reference')) return Icons.receipt_long_outlined;
  if (key.contains('phone')) return Icons.phone_outlined;
  if (key.contains('email')) return Icons.email_outlined;
  if (key.contains('gst')) return Icons.badge_outlined;
  if (key.contains('state')) return Icons.map_outlined;
  if (key.contains('billing')) return Icons.receipt_long_outlined;
  if (key.contains('shipping')) return Icons.local_shipping_outlined;
  if (key.contains('date')) return Icons.event_outlined;
  if (key.contains('quantity')) return Icons.format_list_numbered_outlined;
  if (key == 'unit' || key.contains('unit')) return Icons.straighten_outlined;
  if (key.contains('rate')) return Icons.currency_rupee_outlined;
  if (key.contains('hsn')) return Icons.qr_code_2_outlined;
  if (key.contains('item')) return Icons.sell_outlined;
  if (key.contains('notes')) return Icons.notes_outlined;
  if (key.contains('terms')) return Icons.description_outlined;
  if (key.contains('code')) return Icons.tag_outlined;
  return Icons.text_fields_outlined;
}

bool _isStateCodeFieldName(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.contains('state') && normalized.contains('code');
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
    required this.gstInclusiveRate,
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
      gstInclusiveRate: TextEditingController(
        text: item.rateIncludingGst.toString(),
      ),
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
  final TextEditingController gstInclusiveRate;
  final TextEditingController gstRate;
  final Map<String, TextEditingController> customFields;
  bool _syncingRates = false;
  bool _inclusiveRateIsSource = false;

  double get quantityValue => double.tryParse(quantity.text.trim()) ?? 0;
  double get rateValue => double.tryParse(rate.text.trim()) ?? 0;
  double get gstInclusiveRateValue =>
      double.tryParse(gstInclusiveRate.text.trim()) ?? 0;
  double get gstRateValue => double.tryParse(gstRate.text.trim()) ?? 0;
  double get lineTotal => quantityValue * rateValue;

  TextEditingController customField(String field) {
    return customFields.putIfAbsent(field, () => TextEditingController());
  }

  void ensureCustomFields(List<CustomFieldDefinition> fields) {
    for (final field in fields) {
      customFields.putIfAbsent(
        field.name,
        () => TextEditingController(text: field.defaultValue),
      );
    }
    final allowed = fields.map((field) => field.name.toLowerCase()).toSet();
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
    gstInclusiveRate.clear();
    gstRate.text = product.gstRate.toString();
  }

  void addListener(
    VoidCallback listener, {
    ValueChanged<String>? onHsnChanged,
  }) {
    void syncInclusiveFromBaseRate() {
      _inclusiveRateIsSource = false;
      _applyBaseRate();
      listener();
    }

    void syncBaseRateFromInclusive() {
      _inclusiveRateIsSource = true;
      _applyInclusiveRate();
      listener();
    }

    void syncRateForGstChange() {
      if (_inclusiveRateIsSource) {
        _applyInclusiveRate();
      } else {
        _applyBaseRate();
      }
      listener();
    }

    void handleHsnChange() {
      onHsnChanged?.call(hsnSac.text.trim());
      listener();
    }

    rate.addListener(syncInclusiveFromBaseRate);
    gstInclusiveRate.addListener(syncBaseRateFromInclusive);
    gstRate.addListener(syncRateForGstChange);
    hsnSac.addListener(handleHsnChange);
    for (final controller in [
      name,
      description,
      quantity,
      unit,
      ...customFields.values,
    ]) {
      controller.addListener(listener);
    }
  }

  void _applyBaseRate() {
    if (_syncingRates) return;
    _syncingRates = true;
    try {
      final baseRate = rateValue;
      final gst = gstRateValue;
      final calculator = InvoiceCalculator();
      final inclusiveRate = calculator.rateIncludingTax(
        rate: baseRate,
        taxRate: gst,
      );
      final formatted = calculator.formatRateInput(inclusiveRate);
      if (gstInclusiveRate.text != formatted) {
        gstInclusiveRate.text = formatted;
      }
    } finally {
      _syncingRates = false;
    }
  }

  void _applyInclusiveRate() {
    if (_syncingRates) return;
    if (gstInclusiveRate.text.trim().isEmpty) return;
    _syncingRates = true;
    try {
      final inclusive = gstInclusiveRateValue;
      final gst = gstRateValue;
      if (inclusive <= 0) return;
      final calculator = InvoiceCalculator();
      final baseRate = calculator.rateBeforeTax(
        rateIncludingTax: inclusive,
        taxRate: gst,
      );
      final formatted = calculator.formatRateInput(baseRate);
      if (rate.text != formatted) {
        rate.text = formatted;
      }
    } finally {
      _syncingRates = false;
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
      rateIncludingGst: gstInclusiveRateValue,
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
    gstInclusiveRate.dispose();
    gstRate.dispose();
    for (final controller in customFields.values) {
      controller.dispose();
    }
  }
}

class _ChargeControllers {
  _ChargeControllers({required this.label, required this.amount});

  factory _ChargeControllers.empty() {
    return _ChargeControllers(
      label: TextEditingController(),
      amount: TextEditingController(),
    );
  }

  factory _ChargeControllers.fromCharge(InvoiceCharge charge) {
    return _ChargeControllers(
      label: TextEditingController(text: charge.label),
      amount: TextEditingController(
        text: InvoiceCalculator().formatRateInput(charge.amount),
      ),
    );
  }

  final TextEditingController label;
  final TextEditingController amount;

  void addListener(VoidCallback listener) {
    label.addListener(listener);
    amount.addListener(listener);
  }

  InvoiceCharge toCharge() {
    return InvoiceCharge(
      label: label.text.trim(),
      amount: double.tryParse(amount.text.trim()) ?? 0,
    );
  }

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}
