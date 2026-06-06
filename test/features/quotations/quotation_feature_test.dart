import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/company/data/models/app_settings_model.dart';
import 'package:invo_print/features/company/data/models/company_profile_model.dart';
import 'package:invo_print/features/company/data/repositories/company_settings_repository.dart';
import 'package:invo_print/features/company/domain/entities/app_settings.dart';
import 'package:invo_print/features/company/domain/entities/company_profile.dart';
import 'package:invo_print/features/customers/data/repositories/customer_repository.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_calculator.dart';
import 'package:invo_print/features/quotations/data/models/quotation_model.dart';
import 'package:invo_print/features/quotations/data/repositories/quotation_repository.dart';
import 'package:invo_print/features/quotations/domain/entities/quotation.dart';
import 'package:invo_print/features/quotations/domain/services/quotation_pdf_service.dart';
import 'package:invo_print/features/quotations/presentation/cubit/quotation_cubit.dart';

import '../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('QuotationModel', () {
    test('round-trips totals, optional adjustments, and conversion fields', () {
      final quotation = _quotation(
        discountType: 'percentage',
        discountValue: 10,
        discountTotal: 100,
        extraCharges: const [InvoiceCharge(label: 'Packing', amount: 25)],
        extraChargeTotal: 25,
        roundOffEnabled: true,
        roundOffAmount: -0.20,
        convertedInvoiceId: 'inv_1',
        convertedAt: DateTime(2026, 5, 4),
      );

      final map = QuotationModel.fromEntity(quotation).toMap();
      final restored = QuotationModel.fromMap(quotation.id, map);

      expect(restored.quotationNumber, 'QUO-2026/05-0007');
      expect(restored.discountType, 'percentage');
      expect(restored.discountValue, 10);
      expect(restored.extraCharges.single.label, 'Packing');
      expect(restored.roundOffEnabled, isTrue);
      expect(restored.roundOffAmount, -0.20);
      expect(restored.convertedInvoiceId, 'inv_1');
      expect(restored.convertedAt, DateTime(2026, 5, 4));
    });
  });

  group('QuotationRepository', () {
    test(
      'fetchQuotations returns only active quotations sorted newest first',
      () async {
        final old = _quotation(id: 'old', createdAt: DateTime(2026, 5, 1));
        final latest = _quotation(
          id: 'latest',
          createdAt: DateTime(2026, 5, 3),
        );
        final archived = _quotation(
          id: 'archived',
          createdAt: DateTime(2026, 5, 4),
        );
        final firestore = FakeCustomerFirestoreRestClient({
          'quotations/${old.id}': QuotationModel.fromEntity(old).toMap(),
          'quotations/${latest.id}': QuotationModel.fromEntity(latest).toMap(),
          'quotations/${archived.id}': QuotationModel.fromEntity(
            archived,
          ).toArchiveMap(archivedAt: DateTime(2026, 5, 5)),
        });

        final quotations = await QuotationRepository(
          firestore,
        ).fetchQuotations();

        expect(quotations.map((entry) => entry.id), ['latest', 'old']);
      },
    );

    test('archiveQuotation marks the Firestore document inactive', () async {
      final quotation = _quotation();
      final firestore = FakeCustomerFirestoreRestClient({
        'quotations/${quotation.id}': QuotationModel.fromEntity(
          quotation,
        ).toMap(),
      });

      await QuotationRepository(firestore).archiveQuotation(quotation);

      expect(
        firestore.documents['quotations/${quotation.id}']!['isActive'],
        isFalse,
      );
      expect(
        firestore.documents['quotations/${quotation.id}']!['archivedAt'],
        isA<DateTime>(),
      );
    });
  });

  group('QuotationCubit', () {
    test('saveQuotation reserves a number for final quotations', () async {
      final cubit = _buildCubit(settings: _settings(quotationNextNumber: 7));
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.saveQuotation(
        customerName: 'TBS Enterprises',
        customerPhone: '9655246269',
        customerEmail: '',
        customerGstin: '',
        customerState: 'Tamil Nadu',
        billingAddress: 'No. 22',
        quotationDate: DateTime(2026, 5, 2),
        validUntil: DateTime(2026, 5, 17),
        taxMode: TaxMode.cgstSgst,
        status: QuotationStatus.sent,
        roundOffEnabled: false,
        discountType: 'none',
        discountValue: 0,
        extraCharges: const [],
        items: [_item()],
        notes: '',
        terms: '',
      );

      final saved = cubit.state.quotations.single;
      expect(saved.quotationSequence, 7);
      expect(saved.quotationNumber, 'QUO-2026/05-0007');
      expect(saved.grandTotal, 1180);
      expect(cubit.state.settings!.quotationNextNumber, 8);
      expect(
        _firestoreFor(cubit).documents['settings/app']!['quotationNextNumber'],
        8,
      );
    });

    test('draft quotations do not consume the next quotation number', () async {
      final cubit = _buildCubit(settings: _settings(quotationNextNumber: 7));
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.saveQuotation(
        customerName: 'Draft Customer',
        customerPhone: '',
        customerEmail: '',
        customerGstin: '',
        customerState: '',
        billingAddress: '',
        quotationDate: DateTime(2026, 5, 2),
        validUntil: DateTime(2026, 5, 17),
        taxMode: TaxMode.none,
        status: QuotationStatus.draft,
        roundOffEnabled: false,
        discountType: 'none',
        discountValue: 0,
        extraCharges: const [],
        items: const [],
        notes: '',
        terms: '',
      );

      expect(cubit.state.quotations.single.quotationNumber, isEmpty);
      expect(cubit.state.settings!.quotationNextNumber, 7);
    });

    test('saveQuotation rejects expired validity dates', () async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.saveQuotation(
        customerName: 'TBS Enterprises',
        customerPhone: '9655246269',
        customerEmail: '',
        customerGstin: '',
        customerState: '',
        billingAddress: '',
        quotationDate: DateTime(2026, 5, 20),
        validUntil: DateTime(2026, 5, 19),
        taxMode: TaxMode.none,
        status: QuotationStatus.sent,
        roundOffEnabled: false,
        discountType: 'none',
        discountValue: 0,
        extraCharges: const [],
        items: [_item()],
        notes: '',
        terms: '',
      );

      expect(cubit.state.status, QuotationViewStatus.failure);
      expect(cubit.state.message, contains('Valid until'));
    });

    test('toInvoiceSource preserves quote details for invoice conversion', () {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      final quotation = _quotation(
        discountType: 'amount',
        discountValue: 50,
        discountTotal: 50,
      );

      final invoice = cubit.toInvoiceSource(quotation);

      expect(invoice.invoiceNumber, isEmpty);
      expect(invoice.customerSnapshot, quotation.customerSnapshot);
      expect(invoice.items.single.name, 'Thermal Printer');
      expect(invoice.discountTotal, 50);
      expect(invoice.status, InvoiceStatus.unpaid);
      expect(invoice.balanceDue, quotation.grandTotal);
    });

    test('filteredQuotations matches number, customer, status, and total', () {
      final first = _quotation(quotationNumber: 'QUO-001');
      final second = _quotation(
        id: 'quo_2',
        quotationNumber: 'QUO-XYZ',
        customerSnapshot: const {'name': 'Acme Stores'},
        status: QuotationStatus.accepted,
        grandTotal: 2500,
      );

      expect(
        QuotationState(
          quotations: [first, second],
          searchQuery: '  accepted ',
        ).filteredQuotations,
        [second],
      );
      expect(
        QuotationState(
          quotations: [first, second],
          searchQuery: '2500',
        ).filteredQuotations,
        [second],
      );
      expect(
        QuotationState(
          quotations: [first, second],
          searchQuery: 'acme',
        ).filteredQuotations,
        [second],
      );
    });
  });

  test('QuotationPdfService builds a readable quotation PDF', () async {
    final bytes = await const QuotationPdfService().buildQuotationPdf(
      quotation: _quotation(
        notes: 'Delivery in 7 days',
        terms: 'Validity 15 days',
      ),
      currencySymbol: 'Rs',
      currentCompanyProfile: _profile(),
      settings: _settings(),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final decoded = _decodedPdfText(bytes);
    expect(decoded, contains('QUOTATION'));
    expect(decoded, contains('QUO-2026/05-0007'));
    expect(decoded, contains('Thermal'));
    expect(decoded, contains('Delivery'));
  });
}

QuotationCubit _buildCubit({
  AppSettings? settings,
  CompanyProfile? profile,
  List<Quotation> quotations = const [],
}) {
  final effectiveSettings = settings ?? _settings();
  final effectiveProfile = profile ?? _profile();
  final firestore = FakeCustomerFirestoreRestClient({
    'settings/app': AppSettingsModel.fromEntity(effectiveSettings).toMap(),
    'company/profile': CompanyProfileModel.fromEntity(effectiveProfile).toMap(),
    for (final quotation in quotations)
      'quotations/${quotation.id}': QuotationModel.fromEntity(
        quotation,
      ).toMap(),
  });
  final cubit = QuotationCubit(
    QuotationRepository(firestore),
    CustomerRepository(firestore),
    CompanySettingsRepository(firestore),
    InvoiceCalculator(),
    NumberingService(),
  );
  _cubitFirestores[cubit] = firestore;
  return cubit;
}

final _cubitFirestores = <QuotationCubit, FakeCustomerFirestoreRestClient>{};

FakeCustomerFirestoreRestClient _firestoreFor(QuotationCubit cubit) {
  return _cubitFirestores[cubit]!;
}

AppSettings _settings({int quotationNextNumber = 7}) {
  final initial = AppSettings.initial();
  return AppSettings(
    gstEnabled: initial.gstEnabled,
    defaultGstRate: initial.defaultGstRate,
    invoicePrefix: initial.invoicePrefix,
    invoiceSeparator: initial.invoiceSeparator,
    invoiceDateFormat: initial.invoiceDateFormat,
    invoiceNextNumber: initial.invoiceNextNumber,
    invoiceNumberPadding: initial.invoiceNumberPadding,
    quotationPrefix: 'QUO',
    quotationSeparator: '-',
    quotationDateFormat: 'yyyy/MM',
    quotationNextNumber: quotationNextNumber,
    quotationNumberPadding: 4,
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
    defaultCustomerState: initial.defaultCustomerState,
    defaultShippingState: initial.defaultShippingState,
    defaultLineItemUnit: initial.defaultLineItemUnit,
    customCustomerFields: initial.customCustomerFields,
    customShippingFields: initial.customShippingFields,
    customLineItemFields: initial.customLineItemFields,
    updatedAt: DateTime(2026, 5, 1),
  );
}

CompanyProfile _profile() {
  return CompanyProfile(
    businessName: 'CompanyTest',
    legalName: '',
    gstin: '',
    pan: '',
    email: 'test@example.com',
    phone: '9655246269',
    website: '',
    addressLine1: 'No. 22, MMS Complex',
    addressLine2: '',
    city: 'Kalpakkam',
    state: 'Tamil Nadu',
    pincode: '603102',
    country: 'India',
    bankName: '',
    bankAccountName: '',
    bankAccountNumber: '',
    ifscCode: '',
    upiId: '',
    defaultInvoiceTerms: 'Default invoice terms',
    defaultQuotationTerms: 'Default quote terms',
    logoBase64: '',
    paymentQrBase64: '',
    updatedAt: DateTime(2026, 5, 1),
  );
}

Quotation _quotation({
  String id = 'quo_1',
  String quotationNumber = 'QUO-2026/05-0007',
  int quotationSequence = 7,
  DateTime? createdAt,
  Map<String, dynamic> customerSnapshot = const {
    'name': 'TBS Enterprises',
    'phone': '9655246269',
    'billingAddress': 'No. 22',
  },
  QuotationStatus status = QuotationStatus.sent,
  String discountType = 'none',
  double discountValue = 0,
  double discountTotal = 0,
  List<InvoiceCharge> extraCharges = const [],
  double extraChargeTotal = 0,
  bool roundOffEnabled = false,
  double roundOffAmount = 0,
  double grandTotal = 1180,
  String notes = '',
  String terms = '',
  String convertedInvoiceId = '',
  DateTime? convertedAt,
}) {
  final now = createdAt ?? DateTime(2026, 5, 2);
  return Quotation(
    id: id,
    quotationNumber: quotationNumber,
    quotationSequence: quotationSequence,
    financialYear: '2026-27',
    quotationDate: DateTime(2026, 5, 2),
    validUntil: DateTime(2026, 5, 17),
    customerId: 'cust_1',
    customerSnapshot: customerSnapshot,
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: [_item()],
    taxMode: TaxMode.cgstSgst,
    status: status,
    subtotal: 1000,
    discountType: discountType,
    discountValue: discountValue,
    discountTotal: discountTotal,
    extraCharges: extraCharges,
    extraChargeTotal: extraChargeTotal,
    taxableAmount: 1000 - discountTotal,
    cgstAmount: 90,
    sgstAmount: 90,
    igstAmount: 0,
    roundOffEnabled: roundOffEnabled,
    roundOffAmount: roundOffAmount,
    grandTotal: grandTotal,
    notes: notes,
    terms: terms,
    convertedInvoiceId: convertedInvoiceId,
    convertedAt: convertedAt,
    createdAt: now,
    updatedAt: now,
  );
}

InvoiceItem _item() {
  return InvoiceItem.empty().copyWith(
    name: 'Thermal Printer',
    hsnSac: '8443',
    quantity: 1,
    unit: 'pcs',
    rate: 1000,
    gstRate: 18,
    taxableAmount: 1000,
    cgstAmount: 90,
    sgstAmount: 90,
    total: 1180,
  );
}

String _decodedPdfText(Uint8List bytes) {
  final rawPdf = latin1.decode(bytes, allowInvalid: true);
  final decodedStreams = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream')
      .allMatches(rawPdf)
      .map((match) {
        final stream = latin1.encode(match.group(1)!);
        try {
          return latin1.decode(zlib.decode(stream), allowInvalid: true);
        } on FormatException {
          return latin1.decode(stream, allowInvalid: true);
        }
      });

  return [rawPdf, ...decodedStreams].join('\n');
}
