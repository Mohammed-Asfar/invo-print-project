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

part 'invoice_state.dart';

class InvoiceCubit extends Cubit<InvoiceState> {
  InvoiceCubit(
    this._invoiceRepository,
    this._customerRepository,
    this._productRepository,
    this._settingsRepository,
    this._calculator,
    this._numberingService,
  ) : super(const InvoiceState());

  final InvoiceRepository _invoiceRepository;
  final CustomerRepository _customerRepository;
  final ProductRepository _productRepository;
  final CompanySettingsRepository _settingsRepository;
  final InvoiceCalculator _calculator;
  final NumberingService _numberingService;

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
        status: draft.status,
        subtotal: totals.subtotal,
        discountType: 'none',
        discountValue: 0,
        discountTotal: 0,
        taxableAmount: totals.taxableAmount,
        cgstAmount: totals.cgstAmount,
        sgstAmount: totals.sgstAmount,
        igstAmount: totals.igstAmount,
        grandTotal: totals.grandTotal,
        amountPaid: draft.status == InvoiceStatus.paid ? totals.grandTotal : 0,
        paidAt: draft.status == InvoiceStatus.paid ? now : null,
        notes: draft.notes,
        terms: draft.terms.isEmpty
            ? companyProfile.defaultInvoiceTerms
            : draft.terms,
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

  InvoiceDraft _defaultDraft(AppSettings settings) {
    final now = DateTime.now();
    return InvoiceDraft(
      customerName: '',
      customerPhone: '',
      customerEmail: '',
      customerGstin: '',
      customerState: '',
      billingAddress: '',
      shippingAddress: '',
      shipToName: '',
      shipToPhone: '',
      shipToEmail: '',
      shipToState: '',
      shipToPincode: '',
      shippingCustomFields: const {},
      invoiceDate: now,
      dueDate: now.add(const Duration(days: 15)),
      taxMode: settings.gstEnabled ? TaxMode.cgstSgst : TaxMode.none,
      status: InvoiceStatus.unpaid,
      items: [InvoiceItem.empty().copyWith(gstRate: settings.defaultGstRate)],
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
    };
  }
}
