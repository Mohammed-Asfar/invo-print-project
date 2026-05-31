import '../../../../core/errors/app_exception.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../company/domain/entities/company_profile.dart';
import '../../../company/data/repositories/company_settings_repository.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../data/repositories/invoice_repository.dart';
import '../entities/invoice.dart';
import '../entities/invoice_draft.dart';
import '../services/invoice_calculator.dart';

class InvoiceCreationResult {
  const InvoiceCreationResult({
    required this.invoice,
    required this.customer,
    required this.invoiceNumber,
    required this.updatedSettings,
  });

  final Invoice invoice;
  final Customer customer;
  final String invoiceNumber;
  final AppSettings updatedSettings;
}

class InvoiceUpdateResult {
  const InvoiceUpdateResult({required this.invoice, required this.customer});

  final Invoice invoice;
  final Customer customer;
}

class InvoiceCreator {
  const InvoiceCreator({
    required InvoiceRepository invoiceRepository,
    required CustomerRepository customerRepository,
    required CompanySettingsRepository settingsRepository,
    required InvoiceCalculator calculator,
    required NumberingService numberingService,
  }) : _invoiceRepository = invoiceRepository,
       _customerRepository = customerRepository,
       _settingsRepository = settingsRepository,
       _calculator = calculator,
       _numberingService = numberingService;

  final InvoiceRepository _invoiceRepository;
  final CustomerRepository _customerRepository;
  final CompanySettingsRepository _settingsRepository;
  final InvoiceCalculator _calculator;
  final NumberingService _numberingService;

  Future<InvoiceCreationResult> createFromDraft({
    required InvoiceDraft draft,
    required AppSettings settings,
    required CompanyProfile companyProfile,
    List<Customer>? knownCustomers,
  }) async {
    final validItems = draft.items.where((item) => item.name.trim().isNotEmpty);
    final items = validItems.toList();
    if (draft.customerName.trim().isEmpty) {
      throw const AppException('Customer name is required.');
    }
    if (items.isEmpty) {
      throw const AppException('Add at least one invoice item.');
    }

    final customer = await _customerRepository.findOrCreateFromInvoice(
      draft.toCustomerDraft(loyaltyEnabled: settings.loyaltyEnabled),
      existingCustomers: knownCustomers,
    );

    final totals = _calculator.calculate(
      items: items,
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

    final updatedSettings = _incrementInvoiceNumber(settings);
    await _settingsRepository.saveAppSettings(updatedSettings);

    return InvoiceCreationResult(
      invoice: invoice,
      customer: customer,
      invoiceNumber: invoiceNumber,
      updatedSettings: updatedSettings,
    );
  }

  Future<InvoiceUpdateResult> updateFromDraft({
    required Invoice existingInvoice,
    required InvoiceDraft draft,
    required AppSettings settings,
    required CompanyProfile companyProfile,
    List<Customer>? knownCustomers,
  }) async {
    final validItems = draft.items.where((item) => item.name.trim().isNotEmpty);
    final items = validItems.toList();
    if (draft.customerName.trim().isEmpty) {
      throw const AppException('Customer name is required.');
    }
    if (items.isEmpty) {
      throw const AppException('Add at least one invoice item.');
    }

    final customer = await _customerRepository.findOrCreateFromInvoice(
      draft.toCustomerDraft(loyaltyEnabled: settings.loyaltyEnabled),
      existingCustomers: knownCustomers,
    );

    final totals = _calculator.calculate(
      items: items,
      taxMode: draft.taxMode,
      roundOffEnabled: draft.roundOffEnabled,
      discountType: draft.discountType,
      discountValue: draft.discountValue,
      extraCharges: draft.extraCharges,
    );

    final enteredAdvance = draft.advancePaid
        .clamp(0, totals.grandTotal)
        .toDouble();
    final existingFollowUpPayments = existingInvoice.paymentHistory
        .where((payment) => payment.notes != 'Initial advance payment')
        .toList();
    final paymentHistory = <InvoicePaymentRecord>[
      if (enteredAdvance > 0)
        InvoicePaymentRecord(
          amount: enteredAdvance,
          paidAt: draft.advancePaidDate ?? existingInvoice.invoiceDate,
          method: draft.advancePaidMethod.trim(),
          reference: draft.advancePaidReference.trim(),
          notes: 'Initial advance payment',
        ),
      ...existingFollowUpPayments,
    ]..sort((a, b) => a.paidAt.compareTo(b.paidAt));
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

    final updatedInvoice = existingInvoice.copyWith(
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
      clearPaidAt: paidAt == null,
      notes: draft.notes,
      terms: _resolvedTerms(
        enteredTerms: draft.terms,
        customer: customer,
        companyProfile: companyProfile,
      ),
      paymentHistory: paymentHistory,
      updatedAt: DateTime.now(),
    );

    await _invoiceRepository.saveInvoice(updatedInvoice);
    return InvoiceUpdateResult(invoice: updatedInvoice, customer: customer);
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
