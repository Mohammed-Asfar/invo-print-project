import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../company/data/repositories/company_settings_repository.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../company/domain/entities/company_profile.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../products/domain/entities/product_service.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_draft.dart';
import '../../domain/entities/invoice_item.dart';
import '../../domain/services/invoice_calculator.dart';
import '../../../customers/data/services/gstin_lookup_service.dart';

part 'invoice_state.dart';

class InvoiceCubit extends Cubit<InvoiceState> {
  InvoiceCubit(
    this._invoiceRepository,
    this._customerRepository,
    this._productRepository,
    this._settingsRepository,
    this._calculator,
    this._numberingService,
    this._gstinLookupService,
  ) : super(const InvoiceState());

  final InvoiceRepository _invoiceRepository;
  final CustomerRepository _customerRepository;
  final ProductRepository _productRepository;
  final CompanySettingsRepository _settingsRepository;
  final InvoiceCalculator _calculator;
  final NumberingService _numberingService;
  final GstinLookupService _gstinLookupService;

  Future<void> load() async {
    emit(state.copyWith(status: InvoiceStatusView.loading, clearMessage: true));
    try {
      final results = await Future.wait<Object>([
        _invoiceRepository.fetchInvoices(),
        _customerRepository.fetchCustomers(),
        _productRepository.fetchProducts(),
        _settingsRepository.fetchAppSettings(),
        _settingsRepository.fetchCompanyProfile(),
      ]);
      final settings = results[3] as AppSettings;
      emit(
        state.copyWith(
          status: InvoiceStatusView.loaded,
          invoices: results[0] as List<Invoice>,
          customers: results[1] as List<Customer>,
          products: results[2] as List<ProductService>,
          settings: settings,
          companyProfile: results[4] as CompanyProfile,
          draft: _defaultDraft(settings),
          clearMessage: true,
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: error.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Unable to load invoices: $error',
        ),
      );
    }
  }

  void search(String value) {
    emit(state.copyWith(searchQuery: value));
  }

  Future<GstinBusinessDetails> lookupGstin(String gstin) {
    final settings = state.settings;
    if (settings == null) {
      throw const AppException('Company settings are not loaded yet.');
    }
    if (!settings.gstinLookupEnabled) {
      throw const AppException(
        'Enable GSTIN lookup in Company Settings before using this action.',
      );
    }
    return _gstinLookupService.lookup(
      gstin: gstin,
      apiKey: settings.gstinLookupApiKey,
      host: settings.gstinLookupApiHost,
      endpointPath: settings.gstinLookupApiPath,
    );
  }

  Future<GstinValidationResult> validateGstin(String gstin) {
    final settings = state.settings;
    if (settings == null) {
      throw const AppException('Company settings are not loaded yet.');
    }
    if (!settings.gstinLookupEnabled) {
      throw const AppException(
        'Enable GSTIN lookup in Company Settings before using this action.',
      );
    }
    return _gstinLookupService.validate(
      gstin: gstin,
      apiKey: settings.gstinLookupApiKey,
      host: settings.gstinLookupApiHost,
      endpointPath: settings.gstinValidationApiPath,
    );
  }

  Future<void> saveDraft(InvoiceDraft draft) async {
    if (state.settings == null || state.companyProfile == null) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Company settings are not loaded.',
        ),
      );
      return;
    }

    final validItems = draft.items
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
    if (draft.customerName.trim().isEmpty) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Customer name is required.',
        ),
      );
      return;
    }
    if (validItems.isEmpty) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Add at least one invoice item.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: InvoiceStatusView.saving));
    try {
      final settings = state.settings!;
      final companyProfile = state.companyProfile!;
      final customer = await _customerRepository.findOrCreateFromInvoice(
        draft.toCustomerDraft(loyaltyEnabled: settings.loyaltyEnabled),
      );
      final totals = _calculator.calculate(
        items: validItems,
        taxMode: draft.taxMode,
        roundOffEnabled: draft.roundOffEnabled,
        discountType: draft.discountType,
        discountValue: draft.discountValue,
        extraCharges: draft.extraCharges,
      );
      final now = DateTime.now();
      final sequence = settings.invoiceNextNumber;
      final invoiceNumber = _numberingService.buildNumber(
        prefix: settings.invoicePrefix,
        separator: settings.invoiceSeparator,
        dateFormat: settings.invoiceDateFormat,
        sequence: sequence,
        padding: settings.invoiceNumberPadding,
        date: draft.invoiceDate,
      );
      final paymentHistory = <InvoicePaymentRecord>[
        if (draft.advancePaid > 0)
          InvoicePaymentRecord(
            amount: draft.advancePaid.clamp(0, totals.grandTotal),
            paidAt: draft.advancePaidDate ?? now,
            method: draft.advancePaidMethod.trim(),
            reference: draft.advancePaidReference.trim(),
            notes: 'Initial advance payment',
          ),
      ];
      final amountPaid = _roundMoney(
        paymentHistory.fold<double>(0, (sum, payment) => sum + payment.amount),
      ).clamp(0, totals.grandTotal).toDouble();
      final balanceDue = _roundMoney(totals.grandTotal - amountPaid);
      final status = _statusFromAmounts(
        requestedStatus: draft.status,
        amountPaid: amountPaid,
        grandTotal: totals.grandTotal,
      );
      final paidAt = status == InvoiceStatus.paid && paymentHistory.isNotEmpty
          ? paymentHistory.last.paidAt
          : null;
      final invoice = Invoice(
        id: 'inv_${now.microsecondsSinceEpoch}',
        invoiceNumber: invoiceNumber,
        invoiceSequence: sequence,
        financialYear: _numberingService.financialYear(draft.invoiceDate),
        invoiceDate: draft.invoiceDate,
        dueDate: draft.dueDate,
        customerId: customer.id,
        customerSnapshot: draft.customerSnapshot,
        companySnapshot: _companySnapshot(companyProfile),
        items: totals.items,
        taxMode: draft.taxMode,
        status: status,
        subtotal: totals.subtotal,
        discountType: draft.discountType,
        discountValue: draft.discountValue,
        discountTotal: totals.discountTotal,
        extraCharges: draft.extraCharges,
        extraChargeTotal: totals.extraChargeTotal,
        taxableAmount: totals.taxableAmount,
        cgstAmount: totals.cgstAmount,
        sgstAmount: totals.sgstAmount,
        igstAmount: totals.igstAmount,
        roundOffEnabled: draft.roundOffEnabled,
        roundOffAmount: totals.roundOffAmount,
        grandTotal: totals.grandTotal,
        amountPaid: amountPaid,
        balanceDue: balanceDue,
        paidAt: paidAt,
        notes: draft.notes,
        terms: _resolvedTerms(
          enteredTerms: draft.terms,
          customer: customer,
          companyProfile: companyProfile,
        ),
        paymentHistory: paymentHistory,
        loyaltyPointsAwarded: false,
        pointsEarned: 0,
        createdAt: now,
        updatedAt: now,
      );
      await _invoiceRepository.saveInvoice(invoice);
      await _settingsRepository.saveAppSettings(
        _incrementInvoiceNumber(settings),
      );
      final results = await Future.wait<Object>([
        _invoiceRepository.fetchInvoices(),
        _customerRepository.fetchCustomers(),
      ]);
      emit(
        state.copyWith(
          status: InvoiceStatusView.saved,
          invoices: results[0] as List<Invoice>,
          customers: results[1] as List<Customer>,
          settings: _incrementInvoiceNumber(settings),
          draft: _defaultDraft(_incrementInvoiceNumber(settings)),
          message: 'Invoice $invoiceNumber saved.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: error.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Unable to save invoice: $error',
        ),
      );
    }
  }

  Future<void> cancelInvoice(Invoice invoice) async {
    if (invoice.status == InvoiceStatus.cancelled) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: '${invoice.invoiceNumber} is already cancelled.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: InvoiceStatusView.saving, clearMessage: true));
    try {
      final updatedInvoice = invoice.copyWith(
        status: InvoiceStatus.cancelled,
        amountPaid: 0,
        balanceDue: invoice.grandTotal,
        clearPaidAt: true,
        updatedAt: DateTime.now(),
      );
      await _invoiceRepository.saveInvoice(updatedInvoice);
      final invoices = await _invoiceRepository.fetchInvoices();
      emit(
        state.copyWith(
          status: InvoiceStatusView.saved,
          invoices: invoices,
          message: '${invoice.invoiceNumber} cancelled.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: error.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Unable to cancel invoice: $error',
        ),
      );
    }
  }

  Future<void> deleteInvoice(Invoice invoice) async {
    emit(state.copyWith(status: InvoiceStatusView.saving, clearMessage: true));
    try {
      await _invoiceRepository.deleteInvoice(invoice.id);
      final invoices = await _invoiceRepository.fetchInvoices();
      emit(
        state.copyWith(
          status: InvoiceStatusView.saved,
          invoices: invoices,
          message: '${invoice.invoiceNumber} deleted.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: error.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Unable to delete invoice: $error',
        ),
      );
    }
  }

  Future<void> recordPayment(
    Invoice invoice, {
    required double amount,
    required DateTime paidAt,
    String method = '',
    String reference = '',
    String notes = '',
  }) async {
    if (invoice.status == InvoiceStatus.cancelled) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Cancelled invoices cannot receive payments.',
        ),
      );
      return;
    }
    final normalizedAmount = _roundMoney(amount);
    if (normalizedAmount <= 0) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Enter a payment amount greater than zero.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: InvoiceStatusView.saving, clearMessage: true));
    try {
      final cappedAmount = _roundMoney(
        normalizedAmount > invoice.balanceDue
            ? invoice.balanceDue
            : normalizedAmount,
      );
      final payment = InvoicePaymentRecord(
        amount: cappedAmount,
        paidAt: paidAt,
        method: method.trim(),
        reference: reference.trim(),
        notes: notes.trim(),
      );
      final paymentHistory = [...invoice.paymentHistory, payment]
        ..sort((a, b) => a.paidAt.compareTo(b.paidAt));
      final amountPaid = _roundMoney(
        paymentHistory.fold<double>(0, (sum, entry) => sum + entry.amount),
      ).clamp(0, invoice.grandTotal).toDouble();
      final balanceDue = _roundMoney(invoice.grandTotal - amountPaid);
      final status = _statusFromAmounts(
        requestedStatus: invoice.status,
        amountPaid: amountPaid,
        grandTotal: invoice.grandTotal,
      );
      final updatedInvoice = invoice.copyWith(
        status: status,
        amountPaid: amountPaid,
        balanceDue: balanceDue,
        paidAt: status == InvoiceStatus.paid ? paidAt : null,
        paymentHistory: paymentHistory,
        updatedAt: DateTime.now(),
      );
      await _invoiceRepository.saveInvoice(updatedInvoice);
      final invoices = await _invoiceRepository.fetchInvoices();
      emit(
        state.copyWith(
          status: InvoiceStatusView.saved,
          invoices: invoices,
          message: status == InvoiceStatus.paid
              ? '${invoice.invoiceNumber} marked as paid.'
              : 'Payment recorded for ${invoice.invoiceNumber}.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: error.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Unable to record payment: $error',
        ),
      );
    }
  }

  InvoiceDraft _defaultDraft(AppSettings settings) {
    final now = DateTime.now();
    return InvoiceDraft(
      customerName: '',
      customerPhone: '',
      customerEmail: '',
      customerGstin: '',
      customerState: settings.defaultCustomerState,
      customerStateCode: '',
      billingAddress: '',
      shippingEnabled: false,
      shippingAddress: '',
      shipToName: '',
      shipToPhone: '',
      shipToEmail: '',
      shipToState: settings.defaultShippingState,
      shipToPincode: '',
      shippingCustomFields: const {},
      invoiceDate: now,
      dueDate: now.add(const Duration(days: 15)),
      taxMode: settings.gstEnabled ? TaxMode.cgstSgst : TaxMode.none,
      status: InvoiceStatus.unpaid,
      roundOffEnabled: false,
      discountType: 'none',
      discountValue: 0,
      extraCharges: const [],
      advancePaid: 0,
      advancePaidDate: null,
      advancePaidMethod: '',
      advancePaidReference: '',
      items: [
        InvoiceItem.empty().copyWith(
          unit: settings.defaultLineItemUnit,
          gstRate: settings.defaultGstRate,
        ),
      ],
      notes: '',
      terms: '',
    );
  }

  AppSettings _incrementInvoiceNumber(AppSettings settings) {
    return AppSettings(
      gstEnabled: settings.gstEnabled,
      defaultGstRate: settings.defaultGstRate,
      invoicePrefix: settings.invoicePrefix,
      invoiceSeparator: settings.invoiceSeparator,
      invoiceDateFormat: settings.invoiceDateFormat,
      invoiceNextNumber: settings.invoiceNextNumber + 1,
      invoiceNumberPadding: settings.invoiceNumberPadding,
      quotationPrefix: settings.quotationPrefix,
      quotationSeparator: settings.quotationSeparator,
      quotationDateFormat: settings.quotationDateFormat,
      quotationNextNumber: settings.quotationNextNumber,
      quotationNumberPadding: settings.quotationNumberPadding,
      loyaltyEnabled: settings.loyaltyEnabled,
      pointsPerRupee: settings.pointsPerRupee,
      pointsRedemptionValue: settings.pointsRedemptionValue,
      currencyCode: settings.currencyCode,
      currencySymbol: settings.currencySymbol,
      themeMode: settings.themeMode,
      primaryColorHex: settings.primaryColorHex,
      showLineItemHsn: settings.showLineItemHsn,
      showCustomerStateCode: settings.showCustomerStateCode,
      gstinLookupEnabled: settings.gstinLookupEnabled,
      gstinLookupApiKey: settings.gstinLookupApiKey,
      gstinLookupApiHost: settings.gstinLookupApiHost,
      gstinValidationApiPath: settings.gstinValidationApiPath,
      gstinLookupApiPath: settings.gstinLookupApiPath,
      defaultCustomerState: settings.defaultCustomerState,
      defaultShippingState: settings.defaultShippingState,
      defaultLineItemUnit: settings.defaultLineItemUnit,
      customCustomerFields: settings.customCustomerFields,
      customShippingFields: settings.customShippingFields,
      customLineItemFields: settings.customLineItemFields,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> _companySnapshot(CompanyProfile profile) {
    return {
      'businessName': profile.businessName,
      'legalName': profile.legalName,
      'gstin': profile.gstin,
      'pan': profile.pan,
      'email': profile.email,
      'phone': profile.phone,
      'website': profile.website,
      'addressLine1': profile.addressLine1,
      'addressLine2': profile.addressLine2,
      'city': profile.city,
      'state': profile.state,
      'pincode': profile.pincode,
      'country': profile.country,
      'bankName': profile.bankName,
      'bankAccountName': profile.bankAccountName,
      'bankAccountNumber': profile.bankAccountNumber,
      'ifscCode': profile.ifscCode,
      'upiId': profile.upiId,
      'logoBase64': profile.logoBase64,
      'paymentQrBase64': profile.paymentQrBase64,
    };
  }

  String _resolvedTerms({
    required String enteredTerms,
    required Customer customer,
    required CompanyProfile companyProfile,
  }) {
    if (enteredTerms.trim().isNotEmpty) return enteredTerms.trim();
    if (customer.defaultInvoiceTerms.trim().isNotEmpty) {
      return customer.defaultInvoiceTerms.trim();
    }
    return companyProfile.defaultInvoiceTerms;
  }

  InvoiceStatus _statusFromAmounts({
    required InvoiceStatus requestedStatus,
    required double amountPaid,
    required double grandTotal,
  }) {
    if (requestedStatus == InvoiceStatus.draft ||
        requestedStatus == InvoiceStatus.cancelled) {
      return requestedStatus;
    }
    if (grandTotal <= 0) return requestedStatus;
    if (amountPaid >= grandTotal) return InvoiceStatus.paid;
    if (amountPaid > 0) return InvoiceStatus.partialPaid;
    return InvoiceStatus.unpaid;
  }

  double _roundMoney(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
