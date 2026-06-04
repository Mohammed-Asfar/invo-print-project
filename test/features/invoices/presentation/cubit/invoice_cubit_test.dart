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
import 'package:invo_print/features/products/data/models/product_service_model.dart';
import 'package:invo_print/features/products/data/repositories/product_inventory_repository.dart';
import 'package:invo_print/features/products/data/repositories/product_repository.dart';
import 'package:invo_print/features/products/domain/entities/product_inventory_entry.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';
import 'package:invo_print/features/products/domain/services/inventory_transition_service.dart';

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

    test(
      'deleteInvoice restores tracked product stock for final invoices',
      () async {
        final product = _product(stockQuantity: 3);
        final invoice = _invoice(
          items: [
            InvoiceItem.empty().copyWith(
              productId: product.id,
              name: product.name,
              quantity: 2,
              unit: product.unit,
              rate: product.defaultRate,
              gstRate: product.gstRate,
            ),
          ],
        );
        final cubit = _buildCubit(invoices: [invoice], products: [product]);
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.deleteInvoice(invoice);

        final savedProduct = ProductServiceModel.fromMap(
          product.id,
          _firestoreFor(cubit).documents['products/${product.id}']!,
        );
        expect(savedProduct.stockQuantity, 5);
        final historyEntries = _firestoreFor(cubit).documents.entries
            .where(
              (entry) => entry.key.startsWith('product_inventory_entries/'),
            )
            .map((entry) => entry.value)
            .toList();
        expect(historyEntries, hasLength(1));
        expect(
          historyEntries.single['type'],
          ProductInventoryEntryType.invoiceArchived.firestoreValue,
        );
        expect(historyEntries.single['quantityDelta'], 2);
      },
    );

    test('recordPayment rejects zero or negative amounts', () async {
      final invoice = _invoice();
      final cubit = _buildCubit(invoices: [invoice]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.recordPayment(
        invoice,
        amount: 0,
        paidAt: DateTime(2026, 5, 3),
      );

      expect(cubit.state.status, InvoiceStatusView.failure);
      expect(cubit.state.message, contains('greater than zero'));
    });

    test('recordPayment rejects fully paid invoices', () async {
      final invoice = _invoice(
        status: InvoiceStatus.paid,
        amountPaid: 1180,
        balanceDue: 0,
        paidAt: DateTime(2026, 5, 2),
        paymentHistory: [
          InvoicePaymentRecord(amount: 1180, paidAt: DateTime(2026, 5, 2)),
        ],
      );
      final cubit = _buildCubit(invoices: [invoice]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.recordPayment(
        invoice,
        amount: 100,
        paidAt: DateTime(2026, 5, 3),
      );

      expect(cubit.state.status, InvoiceStatusView.failure);
      expect(cubit.state.message, contains('already fully paid'));
    });

    test('recordPayment caps overpayment and marks invoice as paid', () async {
      final invoice = _invoice();
      final cubit = _buildCubit(invoices: [invoice]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.recordPayment(
        invoice,
        amount: 2000,
        paidAt: DateTime(2026, 5, 3),
        method: 'UPI',
      );

      final updated = cubit.state.invoices.single;
      expect(cubit.state.status, InvoiceStatusView.saved);
      expect(updated.amountPaid, 1180);
      expect(updated.balanceDue, 0);
      expect(updated.status, InvoiceStatus.paid);
      expect(updated.paidAt, DateTime(2026, 5, 3));
      expect(updated.paymentHistory.single.amount, 1180);
      expect(cubit.state.message, contains('marked as paid'));
    });

    test(
      'recordPayment sets paidAt from the latest sorted payment date',
      () async {
        final invoice = _invoice(
          amountPaid: 1000,
          balanceDue: 180,
          status: InvoiceStatus.partialPaid,
          paymentHistory: [
            InvoicePaymentRecord(
              amount: 1000,
              paidAt: DateTime(2026, 5, 5),
              method: 'Bank',
            ),
          ],
        );
        final cubit = _buildCubit(invoices: [invoice]);
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.recordPayment(
          invoice,
          amount: 180,
          paidAt: DateTime(2026, 5, 3),
          method: 'Cash',
        );

        final updated = cubit.state.invoices.single;
        expect(updated.status, InvoiceStatus.paid);
        expect(updated.paidAt, DateTime(2026, 5, 5));
        expect(updated.paymentHistory.map((entry) => entry.paidAt), [
          DateTime(2026, 5, 3),
          DateTime(2026, 5, 5),
        ]);
      },
    );

    test(
      'recordPayment keeps payments sorted and status partial for balance due',
      () async {
        final invoice = _invoice(
          paymentHistory: [
            InvoicePaymentRecord(
              amount: 200,
              paidAt: DateTime(2026, 5, 4),
              method: 'Cash',
            ),
          ],
          amountPaid: 200,
          balanceDue: 980,
          status: InvoiceStatus.partialPaid,
        );
        final cubit = _buildCubit(invoices: [invoice]);
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.recordPayment(
          invoice,
          amount: 300,
          paidAt: DateTime(2026, 5, 3),
          method: 'Bank',
        );

        final updated = cubit.state.invoices.single;
        expect(updated.status, InvoiceStatus.partialPaid);
        expect(updated.amountPaid, 500);
        expect(updated.balanceDue, 680);
        expect(updated.paymentHistory.map((entry) => entry.paidAt), [
          DateTime(2026, 5, 3),
          DateTime(2026, 5, 4),
        ]);
        expect(cubit.state.message, contains('Payment recorded'));
      },
    );

    test('cancelInvoice rejects invoices with recorded payments', () async {
      final invoice = _invoice(
        status: InvoiceStatus.partialPaid,
        amountPaid: 300,
        balanceDue: 880,
        paymentHistory: [
          InvoicePaymentRecord(amount: 300, paidAt: DateTime(2026, 5, 2)),
        ],
      );
      final cubit = _buildCubit(invoices: [invoice]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.cancelInvoice(invoice);

      expect(cubit.state.status, InvoiceStatusView.failure);
      expect(cubit.state.message, contains('cannot be cancelled'));
    });

    test('cancelInvoice rejects invoices with credit notes', () async {
      final invoice = _invoice(
        creditTotal: 100,
        balanceDue: 1080,
        creditNotes: [
          InvoiceCreditNote(
            amount: 100,
            issuedAt: DateTime(2026, 5, 4),
            reason: 'Adjustment',
          ),
        ],
      );
      final cubit = _buildCubit(invoices: [invoice]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.cancelInvoice(invoice);

      expect(cubit.state.status, InvoiceStatusView.failure);
      expect(cubit.state.message, contains('credit notes'));
    });

    test('cancelInvoice marks unpaid invoices as cancelled', () async {
      final invoice = _invoice();
      final cubit = _buildCubit(invoices: [invoice]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.cancelInvoice(invoice);

      final updated = cubit.state.invoices.single;
      expect(updated.status, InvoiceStatus.cancelled);
      expect(updated.amountPaid, 0);
      expect(updated.balanceDue, 1180);
      expect(updated.paidAt, isNull);
      expect(cubit.state.message, contains('cancelled'));
    });

    test('cancelInvoice restores tracked product stock', () async {
      final product = _product(stockQuantity: 4);
      final invoice = _invoice(
        items: [
          InvoiceItem.empty().copyWith(
            productId: product.id,
            name: product.name,
            quantity: 2,
            unit: product.unit,
            rate: product.defaultRate,
            gstRate: product.gstRate,
          ),
        ],
      );
      final cubit = _buildCubit(invoices: [invoice], products: [product]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.cancelInvoice(invoice);

      final savedProduct = ProductServiceModel.fromMap(
        product.id,
        _firestoreFor(cubit).documents['products/${product.id}']!,
      );
      expect(savedProduct.stockQuantity, 6);
      final historyEntries = _firestoreFor(cubit).documents.entries
          .where((entry) => entry.key.startsWith('product_inventory_entries/'))
          .map((entry) => entry.value)
          .toList();
      expect(historyEntries, hasLength(1));
      expect(
        historyEntries.single['type'],
        ProductInventoryEntryType.invoiceCancelled.firestoreValue,
      );
      expect(historyEntries.single['quantityDelta'], 2);
    });

    test('cancelInvoice rejects already cancelled invoices', () async {
      final invoice = _invoice(status: InvoiceStatus.cancelled, balanceDue: 0);
      final cubit = _buildCubit(invoices: [invoice]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.cancelInvoice(invoice);

      expect(cubit.state.status, InvoiceStatusView.failure);
      expect(cubit.state.message, contains('already cancelled'));
    });

    test('issueCreditNote rejects invalid credit details', () async {
      final invoice = _invoice();
      final cubit = _buildCubit(invoices: [invoice]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.issueCreditNote(
        invoice,
        amount: 0,
        issuedAt: DateTime(2026, 5, 4),
        reason: 'Adjustment',
      );
      expect(cubit.state.status, InvoiceStatusView.failure);
      expect(cubit.state.message, contains('greater than zero'));

      await cubit.issueCreditNote(
        invoice,
        amount: 100,
        issuedAt: DateTime(2026, 5, 4),
        reason: '',
      );
      expect(cubit.state.status, InvoiceStatusView.failure);
      expect(cubit.state.message, contains('reason'));
    });

    test(
      'issueCreditNote reduces balance and keeps partial paid status',
      () async {
        final invoice = _invoice(
          status: InvoiceStatus.partialPaid,
          amountPaid: 500,
          balanceDue: 680,
          paymentHistory: [
            InvoicePaymentRecord(amount: 500, paidAt: DateTime(2026, 5, 3)),
          ],
        );
        final cubit = _buildCubit(invoices: [invoice]);
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.issueCreditNote(
          invoice,
          amount: 100,
          issuedAt: DateTime(2026, 5, 5),
          reason: 'Short supply',
          reference: 'CN-1',
        );

        final updated = cubit.state.invoices.single;
        expect(cubit.state.status, InvoiceStatusView.saved);
        expect(updated.status, InvoiceStatus.partialPaid);
        expect(updated.creditTotal, 100);
        expect(updated.balanceDue, 580);
        expect(updated.creditNotes.single.reason, 'Short supply');
        expect(updated.creditNotes.single.reference, 'CN-1');
      },
    );

    test(
      'issueCreditNote can settle a paid invoice into credit balance',
      () async {
        final invoice = _invoice(
          status: InvoiceStatus.paid,
          amountPaid: 1180,
          balanceDue: 0,
          paidAt: DateTime(2026, 5, 3),
          paymentHistory: [
            InvoicePaymentRecord(amount: 1180, paidAt: DateTime(2026, 5, 3)),
          ],
        );
        final cubit = _buildCubit(invoices: [invoice]);
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.issueCreditNote(
          invoice,
          amount: 200,
          issuedAt: DateTime(2026, 5, 5),
          reason: 'Post-payment adjustment',
        );

        final updated = cubit.state.invoices.single;
        expect(updated.status, InvoiceStatus.paid);
        expect(updated.creditTotal, 200);
        expect(updated.balanceDue, -200);
      },
    );

    test('issueCreditNote caps total credits at invoice total', () async {
      final invoice = _invoice(
        creditTotal: 1000,
        balanceDue: 180,
        creditNotes: [
          InvoiceCreditNote(
            amount: 1000,
            issuedAt: DateTime(2026, 5, 3),
            reason: 'Earlier credit',
          ),
        ],
      );
      final cubit = _buildCubit(invoices: [invoice]);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.issueCreditNote(
        invoice,
        amount: 500,
        issuedAt: DateTime(2026, 5, 5),
        reason: 'Final adjustment',
      );

      final updated = cubit.state.invoices.single;
      expect(updated.creditTotal, 1180);
      expect(updated.creditNotes.last.amount, 180);
      expect(updated.balanceDue, 0);
      expect(updated.status, InvoiceStatus.paid);
    });
  });

  group('InvoiceState', () {
    test(
      'filteredInvoices trims and matches number, customer name, and status',
      () {
        final invoices = [
          _invoice(invoiceNumber: 'INV-001'),
          _invoice(
            id: 'inv_2',
            invoiceNumber: 'INV-XYZ',
            customerName: 'Acme Stores',
            status: InvoiceStatus.partialPaid,
          ),
        ];

        expect(
          InvoiceState(
            invoices: invoices,
            searchQuery: '  xyz ',
          ).filteredInvoices,
          [invoices[1]],
        );
        expect(
          InvoiceState(
            invoices: invoices,
            searchQuery: 'acme',
          ).filteredInvoices,
          [invoices[1]],
        );
        expect(
          InvoiceState(
            invoices: invoices,
            searchQuery: 'partial paid',
          ).filteredInvoices,
          [invoices[1]],
        );
      },
    );
  });
}

InvoiceCubit _buildCubit({
  AppSettings? settings,
  CompanyProfile? profile,
  List<Invoice> invoices = const [],
  List<ProductService> products = const [],
}) {
  final effectiveSettings = settings ?? _settings();
  final effectiveProfile = profile ?? CompanyProfile.empty();
  final firestore = FakeCustomerFirestoreRestClient({
    'settings/app': AppSettingsModel.fromEntity(effectiveSettings).toMap(),
    'company/profile': CompanyProfileModel.fromEntity(effectiveProfile).toMap(),
    for (final invoice in invoices)
      'invoices/${invoice.id}': InvoiceModel.fromEntity(invoice).toMap(),
    for (final product in products)
      'products/${product.id}': ProductServiceModel.fromEntity(product).toMap(),
  });
  final invoiceRepository = InvoiceRepository(firestore);
  final customerRepository = CustomerRepository(firestore);
  final productRepository = ProductRepository(firestore);
  final productInventoryRepository = ProductInventoryRepository(firestore);
  final settingsRepository = CompanySettingsRepository(firestore);
  final invoiceCreator = InvoiceCreator(
    invoiceRepository: invoiceRepository,
    customerRepository: customerRepository,
    productRepository: productRepository,
    productInventoryRepository: productInventoryRepository,
    settingsRepository: settingsRepository,
    calculator: InvoiceCalculator(),
    inventoryTransitionService: const InventoryTransitionService(),
    numberingService: NumberingService(),
  );

  final cubit = InvoiceCubit(
    invoiceRepository,
    customerRepository,
    productRepository,
    productInventoryRepository,
    settingsRepository,
    GstinLookupService(),
    invoiceCreator,
    const InventoryTransitionService(),
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

Invoice _invoice({
  String id = 'inv_1',
  String invoiceNumber = 'INV-001',
  String customerName = 'TBS Enterprises',
  InvoiceStatus status = InvoiceStatus.unpaid,
  double amountPaid = 0,
  double balanceDue = 1180,
  DateTime? paidAt,
  List<InvoicePaymentRecord> paymentHistory = const [],
  double creditTotal = 0,
  List<InvoiceCreditNote> creditNotes = const [],
  List<InvoiceItem>? items,
}) {
  final now = DateTime(2026, 5, 2);
  return Invoice(
    id: id,
    invoiceNumber: invoiceNumber,
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: now,
    dueDate: now.add(const Duration(days: 15)),
    customerId: 'cust_1',
    customerSnapshot: {'name': customerName},
    companySnapshot: const {'businessName': 'CompanyTest'},
    items:
        items ??
        [
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
    status: status,
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
    amountPaid: amountPaid,
    balanceDue: balanceDue,
    creditTotal: creditTotal,
    paidAt: paidAt,
    notes: '',
    terms: '',
    paymentHistory: paymentHistory,
    creditNotes: creditNotes,
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: now,
    updatedAt: now,
  );
}

ProductService _product({double stockQuantity = 5}) {
  final now = DateTime(2026, 5, 2);
  return ProductService(
    id: 'prod_1',
    name: 'Thermal Printer',
    description: '',
    type: ProductServiceType.product,
    sku: 'PRN-1',
    unit: 'pcs',
    defaultRate: 1000,
    hsnSac: '8443',
    gstRate: 18,
    trackInventory: true,
    stockQuantity: stockQuantity,
    reorderLevel: 2,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
