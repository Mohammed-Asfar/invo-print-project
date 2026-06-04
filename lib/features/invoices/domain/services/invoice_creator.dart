import '../../../../core/errors/app_exception.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../company/domain/entities/company_profile.dart';
import '../../../company/data/repositories/company_settings_repository.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../products/data/repositories/product_repository.dart';
import '../../../products/domain/services/inventory_transition_service.dart';
import '../../data/repositories/invoice_repository.dart';
import '../entities/invoice.dart';
import '../entities/invoice_draft.dart';
import '../entities/invoice_item.dart';
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
  const InvoiceUpdateResult({
    required this.invoice,
    required this.customer,
    required this.updatedSettings,
  });

  final Invoice invoice;
  final Customer customer;
  final AppSettings updatedSettings;
}

class InvoiceCreator {
  const InvoiceCreator({
    required InvoiceRepository invoiceRepository,
    required CustomerRepository customerRepository,
    ProductRepository? productRepository,
    required CompanySettingsRepository settingsRepository,
    required InvoiceCalculator calculator,
    InventoryTransitionService? inventoryTransitionService,
    required NumberingService numberingService,
  }) : _invoiceRepository = invoiceRepository,
       _customerRepository = customerRepository,
       _productRepository = productRepository,
       _settingsRepository = settingsRepository,
       _calculator = calculator,
       _inventoryTransitionService = inventoryTransitionService,
       _numberingService = numberingService;

  final InvoiceRepository _invoiceRepository;
  final CustomerRepository _customerRepository;
  final ProductRepository? _productRepository;
  final CompanySettingsRepository _settingsRepository;
  final InvoiceCalculator _calculator;
  final InventoryTransitionService? _inventoryTransitionService;
  final NumberingService _numberingService;

  Future<InvoiceCreationResult> createFromDraft({
    required InvoiceDraft draft,
    required AppSettings settings,
    required CompanyProfile companyProfile,
    List<Customer>? knownCustomers,
  }) async {
    final validItems = draft.items.where((item) => item.name.trim().isNotEmpty);
    final items = validItems.toList();
    _validateDraftForSave(draft: draft, items: items);

    final shouldPersistCustomer = _shouldPersistCustomerRecord(draft);
    final customer = shouldPersistCustomer
        ? await _customerRepository.findOrCreateFromInvoice(
            draft.toCustomerDraft(loyaltyEnabled: settings.loyaltyEnabled),
            existingCustomers: knownCustomers,
          )
        : (draft.existingCustomer ?? Customer.empty());

    final totals = _calculator.calculate(
      items: items,
      taxMode: draft.taxMode,
      roundOffEnabled: draft.roundOffEnabled,
      discountType: draft.discountType,
      discountValue: draft.discountValue,
      extraCharges: draft.extraCharges,
    );

    final now = DateTime.now();
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
    final shouldAssignFinalNumber = _consumesInvoiceNumber(status);
    final reservation = shouldAssignFinalNumber
        ? await _settingsRepository.reserveNextInvoiceNumber(
            fallbackSettings: settings,
          )
        : null;
    final numberingSettings =
        reservation?.settingsBeforeReservation ?? settings;
    final sequence = reservation?.reservedSequence ?? 0;
    final invoiceNumber = shouldAssignFinalNumber
        ? _buildInvoiceNumber(
            settings: numberingSettings,
            date: draft.invoiceDate,
            sequence: sequence,
          )
        : '';
    final financialYear = shouldAssignFinalNumber
        ? _numberingService.financialYear(draft.invoiceDate)
        : '';

    final invoice = Invoice(
      id: 'inv_${now.microsecondsSinceEpoch}',
      invoiceNumber: invoiceNumber,
      invoiceSequence: sequence,
      financialYear: financialYear,
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

    await _persistInvoiceWithInventoryTransition(
      previousItems: const [],
      previousStatus: InvoiceStatus.draft,
      nextInvoice: invoice,
    );

    final updatedSettings = reservation?.updatedSettings ?? settings;

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
    _validateDraftForSave(draft: draft, items: items);

    final shouldPersistCustomer = _shouldPersistCustomerRecord(draft);
    final customer = shouldPersistCustomer
        ? await _customerRepository.findOrCreateFromInvoice(
            draft.toCustomerDraft(loyaltyEnabled: settings.loyaltyEnabled),
            existingCustomers: knownCustomers,
          )
        : (draft.existingCustomer ?? Customer.empty());

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
    final shouldAssignFinalNumber =
        existingInvoice.status == InvoiceStatus.draft &&
        _consumesInvoiceNumber(status) &&
        existingInvoice.invoiceSequence <= 0;
    final reservation = shouldAssignFinalNumber
        ? await _settingsRepository.reserveNextInvoiceNumber(
            fallbackSettings: settings,
          )
        : null;
    final numberingSettings =
        reservation?.settingsBeforeReservation ?? settings;
    final invoiceNumber = shouldAssignFinalNumber
        ? _buildInvoiceNumber(
            settings: numberingSettings,
            date: draft.invoiceDate,
            sequence: reservation!.reservedSequence,
          )
        : existingInvoice.invoiceNumber;
    final invoiceSequence = shouldAssignFinalNumber
        ? reservation!.reservedSequence
        : existingInvoice.invoiceSequence;
    final financialYear = shouldAssignFinalNumber
        ? _numberingService.financialYear(draft.invoiceDate)
        : existingInvoice.financialYear;

    final updatedInvoice = existingInvoice.copyWith(
      invoiceNumber: invoiceNumber,
      invoiceSequence: invoiceSequence,
      financialYear: financialYear,
      invoiceDate: draft.invoiceDate,
      dueDate: draft.dueDate,
      customerId: customer.id.isEmpty
          ? existingInvoice.customerId
          : customer.id,
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

    await _persistInvoiceWithInventoryTransition(
      previousItems: existingInvoice.items,
      previousStatus: existingInvoice.status,
      nextInvoice: updatedInvoice,
    );
    final updatedSettings = reservation?.updatedSettings ?? settings;
    return InvoiceUpdateResult(
      invoice: updatedInvoice,
      customer: customer,
      updatedSettings: updatedSettings,
    );
  }

  String _buildInvoiceNumber({
    required AppSettings settings,
    required DateTime date,
    required int sequence,
  }) {
    return _numberingService.buildNumber(
      prefix: settings.invoicePrefix,
      separator: settings.invoiceSeparator,
      dateFormat: settings.invoiceDateFormat,
      sequence: sequence,
      padding: settings.invoiceNumberPadding,
      date: date,
    );
  }

  bool _consumesInvoiceNumber(InvoiceStatus status) {
    return status != InvoiceStatus.draft && status != InvoiceStatus.cancelled;
  }

  bool _shouldPersistCustomerRecord(InvoiceDraft draft) {
    return draft.customerName.trim().isNotEmpty &&
        draft.customerPhone.trim().isNotEmpty;
  }

  void _validateDraftForSave({
    required InvoiceDraft draft,
    required List<InvoiceItem> items,
  }) {
    final requiresFinalValidation = _consumesInvoiceNumber(draft.status);
    if (!requiresFinalValidation) {
      return;
    }
    if (draft.customerName.trim().isEmpty) {
      throw const AppException('Customer name is required.');
    }
    if (draft.customerPhone.trim().isEmpty) {
      throw const AppException('Phone is required.');
    }
    if (items.isEmpty) {
      throw const AppException('Add at least one invoice item.');
    }
    if (draft.dueDate.isBefore(draft.invoiceDate)) {
      throw const AppException('Due date cannot be earlier than invoice date.');
    }
    for (final item in items) {
      if (item.quantity <= 0) {
        throw const AppException(
          'Quantity must be greater than zero for all invoice items.',
        );
      }
      if (item.unit.trim().isEmpty) {
        throw const AppException('Unit is required for all invoice items.');
      }
      if (item.rate <= 0) {
        throw const AppException(
          'Rate must be greater than zero for all invoice items.',
        );
      }
      if (item.gstRate < 0 || item.gstRate > 100) {
        throw const AppException('GST percentage must stay between 0 and 100.');
      }
    }
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

  Future<void> _persistInvoiceWithInventoryTransition({
    required List<InvoiceItem> previousItems,
    required InvoiceStatus previousStatus,
    required Invoice nextInvoice,
  }) async {
    if (_productRepository == null || _inventoryTransitionService == null) {
      await _invoiceRepository.saveInvoice(nextInvoice);
      return;
    }
    final inventoryProducts = await _productRepository.fetchProducts(
      includeInactive: true,
    );
    final inventoryResult = _inventoryTransitionService.applyInvoiceTransition(
      products: inventoryProducts,
      previousItems: previousItems,
      previousStatus: previousStatus,
      nextItems: nextInvoice.items,
      nextStatus: nextInvoice.status,
    );
    final updatedProducts = inventoryResult.products
        .where(
          (product) => inventoryResult.updatedProductIds.contains(product.id),
        )
        .toList();
    final originalProducts = inventoryProducts
        .where(
          (product) => inventoryResult.updatedProductIds.contains(product.id),
        )
        .toList();

    if (updatedProducts.isEmpty) {
      await _invoiceRepository.saveInvoice(nextInvoice);
      return;
    }

    await _productRepository.saveProducts(updatedProducts);
    try {
      await _invoiceRepository.saveInvoice(nextInvoice);
    } catch (_) {
      await _productRepository.saveProducts(originalProducts);
      rethrow;
    }
  }
}
