import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/company/data/models/app_settings_model.dart';
import 'package:invo_print/features/company/data/models/company_profile_model.dart';
import 'package:invo_print/features/company/data/repositories/company_settings_repository.dart';
import 'package:invo_print/features/company/domain/entities/app_settings.dart';
import 'package:invo_print/features/company/domain/entities/company_profile.dart';
import 'package:invo_print/features/customers/data/repositories/customer_repository.dart';
import 'package:invo_print/features/customers/data/services/gstin_lookup_service.dart';
import 'package:invo_print/features/invoices/data/models/invoice_model.dart';
import 'package:invo_print/features/invoices/data/repositories/invoice_repository.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_calculator.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_creator.dart';
import 'package:invo_print/features/invoices/presentation/cubit/invoice_cubit.dart';
import 'package:invo_print/features/products/data/repositories/product_repository.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('InvoiceCubit', () {
    test('load seeds draft defaults from settings', () async {
      final settings = _settings(
        gstEnabled: false,
        defaultCustomerState: 'Tamil Nadu',
        defaultShippingState: 'Kerala',
        defaultLineItemUnit: 'pcs',
      );
      final cubit = _buildCubit(settings: settings);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, InvoiceStatusView.loaded);
      expect(cubit.state.draft, isNotNull);
      expect(cubit.state.draft!.taxMode, TaxMode.none);
      expect(cubit.state.draft!.customerState, 'Tamil Nadu');
      expect(cubit.state.draft!.shipToState, 'Kerala');
      expect(cubit.state.draft!.items.single.unit, 'pcs');
      expect(
        cubit.state.draft!.dueDate
            .difference(cubit.state.draft!.invoiceDate)
            .inDays,
        15,
      );
    });

    test(
      'deleteInvoice archives the document and removes it from active state',
      () async {
        final invoice = _invoice();
        final cubit = _buildCubit(invoices: [invoice]);
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.deleteInvoice(invoice);

        expect(cubit.state.status, InvoiceStatusView.saved);
        expect(cubit.state.invoices, isEmpty);
        expect(cubit.state.message, contains('archived'));

        final repository = InvoiceRepository(_firestoreFor(cubit));
        final invoices = await repository.fetchInvoices();
        expect(invoices, isEmpty);
        expect(
          _firestoreFor(cubit).documents['invoices/${invoice.id}']!['isActive'],
          isFalse,
        );
      },
    );
  });
}

InvoiceCubit _buildCubit({
  AppSettings? settings,
  CompanyProfile? profile,
  List<Invoice> invoices = const [],
}) {
  final effectiveSettings = settings ?? _settings();
  final effectiveProfile = profile ?? CompanyProfile.empty();
  final firestore = FakeCustomerFirestoreRestClient({
    'settings/app': AppSettingsModel.fromEntity(effectiveSettings).toMap(),
    'company/profile': CompanyProfileModel.fromEntity(effectiveProfile).toMap(),
    for (final invoice in invoices)
      'invoices/${invoice.id}': InvoiceModel.fromEntity(invoice).toMap(),
  });
  final invoiceRepository = InvoiceRepository(firestore);
  final customerRepository = CustomerRepository(firestore);
  final productRepository = ProductRepository(firestore);
  final settingsRepository = CompanySettingsRepository(firestore);
  final invoiceCreator = InvoiceCreator(
    invoiceRepository: invoiceRepository,
    customerRepository: customerRepository,
    settingsRepository: settingsRepository,
    calculator: InvoiceCalculator(),
    numberingService: NumberingService(),
  );

  final cubit = InvoiceCubit(
    invoiceRepository,
    customerRepository,
    productRepository,
    settingsRepository,
    GstinLookupService(),
    invoiceCreator,
  );
  _cubitFirestores[cubit] = firestore;
  return cubit;
}

final _cubitFirestores = <InvoiceCubit, FakeCustomerFirestoreRestClient>{};

FakeCustomerFirestoreRestClient _firestoreFor(InvoiceCubit cubit) {
  return _cubitFirestores[cubit]!;
}

AppSettings _settings({
  bool gstEnabled = true,
  String defaultCustomerState = '',
  String defaultShippingState = '',
  String defaultLineItemUnit = 'service',
}) {
  final initial = AppSettings.initial();
  return AppSettings(
    gstEnabled: gstEnabled,
    defaultGstRate: initial.defaultGstRate,
    invoicePrefix: initial.invoicePrefix,
    invoiceSeparator: initial.invoiceSeparator,
    invoiceDateFormat: initial.invoiceDateFormat,
    invoiceNextNumber: initial.invoiceNextNumber,
    invoiceNumberPadding: initial.invoiceNumberPadding,
    quotationPrefix: initial.quotationPrefix,
    quotationSeparator: initial.quotationSeparator,
    quotationDateFormat: initial.quotationDateFormat,
    quotationNextNumber: initial.quotationNextNumber,
    quotationNumberPadding: initial.quotationNumberPadding,
    loyaltyEnabled: initial.loyaltyEnabled,
    pointsPerRupee: initial.pointsPerRupee,
    pointsRedemptionValue: initial.pointsRedemptionValue,
    currencyCode: initial.currencyCode,
    currencySymbol: initial.currencySymbol,
    themeMode: initial.themeMode,
    primaryColorHex: initial.primaryColorHex,
    showLineItemHsn: initial.showLineItemHsn,
    showCustomerStateCode: initial.showCustomerStateCode,
    gstinLookupEnabled: initial.gstinLookupEnabled,
    gstinLookupApiKey: initial.gstinLookupApiKey,
    gstinLookupApiHost: initial.gstinLookupApiHost,
    gstinValidationApiPath: initial.gstinValidationApiPath,
    gstinLookupApiPath: initial.gstinLookupApiPath,
    defaultCustomerState: defaultCustomerState,
    defaultShippingState: defaultShippingState,
    defaultLineItemUnit: defaultLineItemUnit,
    customCustomerFields: initial.customCustomerFields,
    customShippingFields: initial.customShippingFields,
    customLineItemFields: initial.customLineItemFields,
    updatedAt: DateTime(2026, 6, 2),
  );
}

Invoice _invoice() {
  final now = DateTime(2026, 5, 2);
  return Invoice(
    id: 'inv_1',
    invoiceNumber: 'INV-001',
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: now,
    dueDate: now.add(const Duration(days: 15)),
    customerId: 'cust_1',
    customerSnapshot: const {'name': 'TBS Enterprises'},
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: [
      InvoiceItem.empty().copyWith(
        name: 'Service',
        quantity: 1,
        rate: 1000,
        gstRate: 18,
        taxableAmount: 1000,
        cgstAmount: 90,
        sgstAmount: 90,
        total: 1180,
      ),
    ],
    taxMode: TaxMode.cgstSgst,
    status: InvoiceStatus.unpaid,
    subtotal: 1000,
    discountType: 'none',
    discountValue: 0,
    discountTotal: 0,
    extraCharges: const [],
    extraChargeTotal: 0,
    taxableAmount: 1000,
    cgstAmount: 90,
    sgstAmount: 90,
    igstAmount: 0,
    roundOffEnabled: false,
    roundOffAmount: 0,
    grandTotal: 1180,
    amountPaid: 0,
    balanceDue: 1180,
    notes: '',
    terms: '',
    paymentHistory: const [],
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: now,
    updatedAt: now,
  );
}
