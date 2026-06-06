import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../company/data/repositories/company_settings_repository.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../company/domain/entities/company_profile.dart';
import '../../../customers/data/repositories/customer_repository.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/entities/invoice_item.dart';
import '../../../invoices/domain/services/invoice_calculator.dart';
import '../../data/repositories/quotation_repository.dart';
import '../../domain/entities/quotation.dart';

part 'quotation_state.dart';

class QuotationCubit extends Cubit<QuotationState> {
  QuotationCubit(
    this._quotationRepository,
    this._customerRepository,
    this._settingsRepository,
    this._calculator,
    this._numberingService,
  ) : super(const QuotationState());

  final QuotationRepository _quotationRepository;
  final CustomerRepository _customerRepository;
  final CompanySettingsRepository _settingsRepository;
  final InvoiceCalculator _calculator;
  final NumberingService _numberingService;

  Future<void> load() async {
    emit(
      state.copyWith(status: QuotationViewStatus.loading, clearMessage: true),
    );
    try {
      final results = await Future.wait<Object>([
        _quotationRepository.fetchQuotations(),
        _customerRepository.fetchCustomers(),
        _settingsRepository.fetchAppSettings(),
        _settingsRepository.fetchCompanyProfile(),
      ]);
      emit(
        state.copyWith(
          status: QuotationViewStatus.loaded,
          quotations: results[0] as List<Quotation>,
          customers: results[1] as List<Customer>,
          settings: results[2] as AppSettings,
          companyProfile: results[3] as CompanyProfile,
          clearMessage: true,
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: QuotationViewStatus.failure,
          message: error.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: QuotationViewStatus.failure,
          message: 'Unable to load quotations: $error',
        ),
      );
    }
  }

  void search(String value) {
    emit(state.copyWith(searchQuery: value));
  }

  Future<void> saveQuotation({
    Quotation? existing,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String customerGstin,
    required String customerState,
    required String billingAddress,
    required DateTime quotationDate,
    required DateTime validUntil,
    required TaxMode taxMode,
    required QuotationStatus status,
    required bool roundOffEnabled,
    required String discountType,
    required double discountValue,
    required List<InvoiceCharge> extraCharges,
    required List<InvoiceItem> items,
    required String notes,
    required String terms,
    Customer? selectedCustomer,
  }) async {
    final settings = state.settings;
    final companyProfile = state.companyProfile;
    if (settings == null || companyProfile == null) {
      emit(
        state.copyWith(
          status: QuotationViewStatus.failure,
          message: 'Company settings are not loaded.',
        ),
      );
      return;
    }
    emit(state.copyWith(status: QuotationViewStatus.saving));
    try {
      final validItems = items
          .where((item) => item.name.trim().isNotEmpty)
          .toList();
      _validate(
        customerName: customerName,
        quotationDate: quotationDate,
        validUntil: validUntil,
        items: validItems,
        status: status,
      );
      final customer = await _resolveCustomer(
        selectedCustomer: selectedCustomer,
        name: customerName,
        phone: customerPhone,
        email: customerEmail,
        gstin: customerGstin,
        stateName: customerState,
        billingAddress: billingAddress,
      );
      final totals = _calculator.calculate(
        items: validItems,
        taxMode: taxMode,
        roundOffEnabled: roundOffEnabled,
        discountType: discountType,
        discountValue: discountValue,
        extraCharges: extraCharges,
      );
      final needsNumber =
          status != QuotationStatus.draft &&
          (existing == null || existing.quotationSequence <= 0);
      final reservation = needsNumber
          ? await _settingsRepository.reserveNextQuotationNumber(
              fallbackSettings: settings,
            )
          : null;
      final numberingSettings =
          reservation?.settingsBeforeReservation ?? settings;
      final sequence =
          reservation?.reservedSequence ?? existing?.quotationSequence ?? 0;
      final quotationNumber = needsNumber
          ? _numberingService.buildNumber(
              prefix: numberingSettings.quotationPrefix,
              separator: numberingSettings.quotationSeparator,
              dateFormat: numberingSettings.quotationDateFormat,
              sequence: sequence,
              padding: numberingSettings.quotationNumberPadding,
              date: quotationDate,
            )
          : existing?.quotationNumber ?? '';
      final now = DateTime.now();
      final quotation = Quotation(
        id: existing?.id ?? 'quo_${now.microsecondsSinceEpoch}',
        quotationNumber: quotationNumber,
        quotationSequence: sequence,
        financialYear: sequence > 0
            ? _numberingService.financialYear(quotationDate)
            : existing?.financialYear ?? '',
        quotationDate: quotationDate,
        validUntil: validUntil,
        customerId: customer.id,
        customerSnapshot: {
          'name': customerName.trim(),
          'phone': customerPhone.trim(),
          'email': customerEmail.trim(),
          'gstin': customerGstin.trim(),
          'state': customerState.trim(),
          'billingAddress': billingAddress.trim(),
        },
        companySnapshot: _companySnapshot(companyProfile),
        items: totals.items,
        taxMode: taxMode,
        status: status,
        subtotal: totals.subtotal,
        discountType: discountType,
        discountValue: discountValue,
        discountTotal: totals.discountTotal,
        extraCharges: extraCharges,
        extraChargeTotal: totals.extraChargeTotal,
        taxableAmount: totals.taxableAmount,
        cgstAmount: totals.cgstAmount,
        sgstAmount: totals.sgstAmount,
        igstAmount: totals.igstAmount,
        roundOffEnabled: roundOffEnabled,
        roundOffAmount: totals.roundOffAmount,
        grandTotal: totals.grandTotal,
        notes: notes.trim(),
        terms: terms.trim().isEmpty
            ? companyProfile.defaultQuotationTerms
            : terms.trim(),
        convertedInvoiceId: existing?.convertedInvoiceId ?? '',
        convertedAt: existing?.convertedAt,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _quotationRepository.saveQuotation(quotation);
      final quotations = _replaceQuotation(state.quotations, quotation)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      emit(
        state.copyWith(
          status: QuotationViewStatus.saved,
          quotations: quotations,
          customers: _upsertCustomer(state.customers, customer),
          settings: reservation?.updatedSettings ?? settings,
          message: quotation.quotationNumber.trim().isEmpty
              ? 'Draft quotation saved.'
              : 'Quotation ${quotation.quotationNumber} saved.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: QuotationViewStatus.failure,
          message: error.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: QuotationViewStatus.failure,
          message: 'Unable to save quotation: $error',
        ),
      );
    }
  }

  Future<void> updateStatus(Quotation quotation, QuotationStatus status) async {
    emit(state.copyWith(status: QuotationViewStatus.saving));
    try {
      final updated = quotation.copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      await _quotationRepository.saveQuotation(updated);
      emit(
        state.copyWith(
          status: QuotationViewStatus.saved,
          quotations: _replaceQuotation(state.quotations, updated),
          message: 'Quotation marked ${status.label.toLowerCase()}.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: QuotationViewStatus.failure,
          message: 'Unable to update quotation: $error',
        ),
      );
    }
  }

  Future<void> archive(Quotation quotation) async {
    emit(state.copyWith(status: QuotationViewStatus.saving));
    try {
      await _quotationRepository.archiveQuotation(quotation);
      emit(
        state.copyWith(
          status: QuotationViewStatus.saved,
          quotations: state.quotations
              .where((entry) => entry.id != quotation.id)
              .toList(),
          message: 'Quotation archived.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: QuotationViewStatus.failure,
          message: 'Unable to archive quotation: $error',
        ),
      );
    }
  }

  Invoice toInvoiceSource(Quotation quotation) {
    final now = DateTime.now();
    return Invoice(
      id: 'quote_source_${quotation.id}',
      invoiceNumber: '',
      invoiceSequence: 0,
      financialYear: '',
      invoiceDate: now,
      dueDate: now.add(const Duration(days: 15)),
      customerId: quotation.customerId,
      customerSnapshot: quotation.customerSnapshot,
      companySnapshot: quotation.companySnapshot,
      items: quotation.items,
      taxMode: quotation.taxMode,
      status: InvoiceStatus.unpaid,
      subtotal: quotation.subtotal,
      discountType: quotation.discountType,
      discountValue: quotation.discountValue,
      discountTotal: quotation.discountTotal,
      extraCharges: quotation.extraCharges,
      extraChargeTotal: quotation.extraChargeTotal,
      taxableAmount: quotation.taxableAmount,
      cgstAmount: quotation.cgstAmount,
      sgstAmount: quotation.sgstAmount,
      igstAmount: quotation.igstAmount,
      roundOffEnabled: quotation.roundOffEnabled,
      roundOffAmount: quotation.roundOffAmount,
      grandTotal: quotation.grandTotal,
      amountPaid: 0,
      balanceDue: quotation.grandTotal,
      notes: quotation.notes,
      terms: '',
      paymentHistory: const [],
      loyaltyPointsAwarded: false,
      pointsEarned: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<Customer> _resolveCustomer({
    required Customer? selectedCustomer,
    required String name,
    required String phone,
    required String email,
    required String gstin,
    required String stateName,
    required String billingAddress,
  }) async {
    final base = selectedCustomer ?? Customer.empty();
    final customer = base.copyWith(
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      gstin: gstin.trim(),
      state: stateName.trim(),
      billingAddress: billingAddress.trim(),
      updatedAt: DateTime.now(),
    );
    if (customer.name.trim().isEmpty || customer.phone.trim().isEmpty) {
      return customer;
    }
    return _customerRepository.findOrCreateFromInvoice(
      customer,
      existingCustomers: state.customers,
    );
  }

  void _validate({
    required String customerName,
    required DateTime quotationDate,
    required DateTime validUntil,
    required List<InvoiceItem> items,
    required QuotationStatus status,
  }) {
    if (customerName.trim().isEmpty) {
      throw const AppException('Customer name is required.');
    }
    if (validUntil.isBefore(quotationDate)) {
      throw const AppException(
        'Valid until cannot be earlier than quotation date.',
      );
    }
    if (status != QuotationStatus.draft && items.isEmpty) {
      throw const AppException('Add at least one quotation item.');
    }
    for (final item in items) {
      if (item.quantity <= 0) {
        throw const AppException('Quantity must be greater than zero.');
      }
      if (item.rate <= 0 && status != QuotationStatus.draft) {
        throw const AppException('Rate must be greater than zero.');
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
      'logoBase64': profile.logoBase64,
    };
  }

  List<Customer> _upsertCustomer(List<Customer> customers, Customer customer) {
    if (customer.id.isEmpty) return customers;
    final index = customers.indexWhere((entry) => entry.id == customer.id);
    if (index == -1) return [...customers, customer];
    final updated = [...customers];
    updated[index] = customer;
    return updated
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<Quotation> _replaceQuotation(
    List<Quotation> quotations,
    Quotation quotation,
  ) {
    final index = quotations.indexWhere((entry) => entry.id == quotation.id);
    if (index == -1) return [quotation, ...quotations];
    final updated = [...quotations];
    updated[index] = quotation;
    return updated;
  }
}
