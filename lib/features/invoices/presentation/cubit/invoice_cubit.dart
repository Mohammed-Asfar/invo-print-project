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
import '../../domain/services/invoice_creator.dart';
import '../../../customers/data/services/gstin_lookup_service.dart';

part 'invoice_state.dart';

class InvoiceCubit extends Cubit<InvoiceState> {
  InvoiceCubit(
    this._invoiceRepository,
    this._customerRepository,
    this._productRepository,
    this._settingsRepository,
    this._gstinLookupService,
    this._invoiceCreator,
  ) : super(const InvoiceState());

  final InvoiceRepository _invoiceRepository;
  final CustomerRepository _customerRepository;
  final ProductRepository _productRepository;
  final CompanySettingsRepository _settingsRepository;
  final GstinLookupService _gstinLookupService;
  final InvoiceCreator _invoiceCreator;

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

  List<Customer> _upsertCustomer(List<Customer> customers, Customer customer) {
    final index = customers.indexWhere((entry) => entry.id == customer.id);
    if (index == -1) return [...customers, customer];
    final updated = [...customers];
    updated[index] = customer;
    return updated;
  }

  List<Invoice> _replaceInvoice(
    List<Invoice> invoices,
    Invoice updatedInvoice,
  ) {
    final index = invoices.indexWhere((entry) => entry.id == updatedInvoice.id);
    if (index == -1) return [updatedInvoice, ...invoices];
    final updated = [...invoices];
    updated[index] = updatedInvoice;
    return updated;
  }

  List<Invoice> _removeInvoice(List<Invoice> invoices, String invoiceId) {
    return invoices.where((invoice) => invoice.id != invoiceId).toList();
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

    emit(state.copyWith(status: InvoiceStatusView.saving));
    try {
      final settings = state.settings!;
      final companyProfile = state.companyProfile!;
      final result = await _invoiceCreator.createFromDraft(
        draft: draft,
        settings: settings,
        companyProfile: companyProfile,
        knownCustomers: state.customers,
      );
      final updatedInvoices = [result.invoice, ...state.invoices]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final updatedCustomers = _upsertCustomer(state.customers, result.customer)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      emit(
        state.copyWith(
          status: InvoiceStatusView.saved,
          invoices: updatedInvoices,
          customers: updatedCustomers,
          settings: result.updatedSettings,
          draft: _defaultDraft(result.updatedSettings),
          message: 'Invoice ${result.invoiceNumber} saved.',
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

  Future<void> updateInvoiceFromDraft(
    Invoice invoice,
    InvoiceDraft draft,
  ) async {
    if (state.settings == null || state.companyProfile == null) {
      emit(
        state.copyWith(
          status: InvoiceStatusView.failure,
          message: 'Company settings are not loaded.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: InvoiceStatusView.saving));
    try {
      final result = await _invoiceCreator.updateFromDraft(
        existingInvoice: invoice,
        draft: draft,
        settings: state.settings!,
        companyProfile: state.companyProfile!,
        knownCustomers: state.customers,
      );
      final updatedInvoices = _replaceInvoice(state.invoices, result.invoice)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final updatedCustomers = _upsertCustomer(state.customers, result.customer)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      emit(
        state.copyWith(
          status: InvoiceStatusView.saved,
          invoices: updatedInvoices,
          customers: updatedCustomers,
          message: 'Invoice ${result.invoice.invoiceNumber} updated.',
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
          message: 'Unable to update invoice: $error',
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
      emit(
        state.copyWith(
          status: InvoiceStatusView.saved,
          invoices: _replaceInvoice(state.invoices, updatedInvoice)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
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
      emit(
        state.copyWith(
          status: InvoiceStatusView.saved,
          invoices: _removeInvoice(state.invoices, invoice.id),
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
      emit(
        state.copyWith(
          status: InvoiceStatusView.saved,
          invoices: _replaceInvoice(state.invoices, updatedInvoice)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
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
