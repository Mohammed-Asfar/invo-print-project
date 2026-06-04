import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/company/data/models/app_settings_model.dart';
import 'package:invo_print/features/company/data/models/company_profile_model.dart';
import 'package:invo_print/features/company/data/repositories/company_settings_repository.dart';
import 'package:invo_print/features/company/domain/entities/app_settings.dart';
import 'package:invo_print/features/company/domain/entities/company_profile.dart';
import 'package:invo_print/features/customers/data/models/customer_model.dart';
import 'package:invo_print/features/customers/data/repositories/customer_repository.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';
import 'package:invo_print/features/invoices/data/models/invoice_model.dart';
import 'package:invo_print/features/invoices/data/repositories/invoice_repository.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_draft.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_calculator.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_creator.dart';
import 'package:invo_print/features/products/data/repositories/product_inventory_repository.dart';
import 'package:invo_print/features/products/data/models/product_service_model.dart';
import 'package:invo_print/features/products/data/repositories/product_repository.dart';
import 'package:invo_print/features/products/domain/entities/product_inventory_entry.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';
import 'package:invo_print/features/products/domain/services/inventory_transition_service.dart';

import '../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('invoice creation workflow', () {
    test(
      'creates invoice, preserves loyalty, records advance, increments number',
      () async {
        final existingCustomer = _customer(
          id: 'cust_1',
          phone: '9655246269',
          loyaltyPointsBalance: 120,
          lifetimePointsEarned: 400,
          defaultInvoiceTerms: 'Customer terms',
        );
        final settings = _settings(invoiceNextNumber: 7);
        final profile = _profile(defaultInvoiceTerms: 'Company terms');
        final firestore = FakeCustomerFirestoreRestClient({
          'customers/cust_1': CustomerModel.fromEntity(
            existingCustomer,
          ).toMap(),
          'settings/app': AppSettingsModel.fromEntity(settings).toMap(),
          'company/profile': CompanyProfileModel.fromEntity(profile).toMap(),
        });
        final creator = InvoiceCreator(
          invoiceRepository: InvoiceRepository(firestore),
          customerRepository: CustomerRepository(firestore),
          settingsRepository: CompanySettingsRepository(firestore),
          calculator: InvoiceCalculator(),
          numberingService: NumberingService(),
        );

        final result = await creator.createFromDraft(
          draft: _draft(existingCustomer: existingCustomer),
          settings: settings,
          companyProfile: profile,
          knownCustomers: [existingCustomer],
        );

        expect(result.invoice.invoiceNumber, 'INV-2026/05-007');
        expect(result.invoice.customerId, 'cust_1');
        expect(result.invoice.subtotal, 3500);
        expect(result.invoice.discountTotal, 350);
        expect(result.invoice.extraChargeTotal, 100);
        expect(result.invoice.grandTotal, 3817);
        expect(result.invoice.amountPaid, 500);
        expect(result.invoice.balanceDue, 3317);
        expect(result.invoice.status, InvoiceStatus.partialPaid);
        expect(result.invoice.paymentHistory.single.method, 'UPI');
        expect(result.invoice.terms, 'Customer terms');
        expect(result.customer.loyaltyPointsBalance, 120);
        expect(result.customer.lifetimePointsEarned, 400);
        expect(result.updatedSettings.invoiceNextNumber, 8);

        final savedInvoiceMap = firestore.documents.entries
            .singleWhere((entry) => entry.key.startsWith('invoices/'))
            .value;
        final savedInvoice = InvoiceModel.fromMap(
          savedInvoiceMap['id']?.toString() ?? result.invoice.id,
          savedInvoiceMap,
        );
        expect(savedInvoice.invoiceNumber, result.invoice.invoiceNumber);
        expect(savedInvoice.paymentHistory, hasLength(1));

        final savedSettings = await CompanySettingsRepository(
          firestore,
        ).fetchAppSettings();
        expect(savedSettings.invoiceNextNumber, 8);
      },
    );

    test(
      'saves plain invoice without optional adjustment/payment fields',
      () async {
        final settings = _settings();
        final profile = _profile();
        final firestore = FakeCustomerFirestoreRestClient();
        final creator = InvoiceCreator(
          invoiceRepository: InvoiceRepository(firestore),
          customerRepository: CustomerRepository(firestore),
          settingsRepository: CompanySettingsRepository(firestore),
          calculator: InvoiceCalculator(),
          numberingService: NumberingService(),
        );

        final result = await creator.createFromDraft(
          draft: _draft(discountType: 'none', discountValue: 0, advancePaid: 0),
          settings: settings,
          companyProfile: profile,
          knownCustomers: const [],
        );

        final savedInvoiceMap =
            firestore.documents['invoices/${result.invoice.id}']!;
        expect(savedInvoiceMap.containsKey('discountType'), isFalse);
        expect(savedInvoiceMap.containsKey('discountValue'), isFalse);
        expect(savedInvoiceMap.containsKey('extraCharges'), isFalse);
        expect(savedInvoiceMap.containsKey('amountPaid'), isFalse);
        expect(savedInvoiceMap.containsKey('paymentHistory'), isFalse);
        expect(result.invoice.status, InvoiceStatus.unpaid);
        expect(result.invoice.balanceDue, result.invoice.grandTotal);
      },
    );

    test('saves draft without consuming invoice number', () async {
      final settings = _settings(invoiceNextNumber: 7);
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient({
        'settings/app': AppSettingsModel.fromEntity(settings).toMap(),
      });
      final creator = InvoiceCreator(
        invoiceRepository: InvoiceRepository(firestore),
        customerRepository: CustomerRepository(firestore),
        settingsRepository: CompanySettingsRepository(firestore),
        calculator: InvoiceCalculator(),
        numberingService: NumberingService(),
      );

      final result = await creator.createFromDraft(
        draft: _draft(status: InvoiceStatus.draft, advancePaid: 0),
        settings: settings,
        companyProfile: profile,
        knownCustomers: const [],
      );

      expect(result.invoice.status, InvoiceStatus.draft);
      expect(result.invoice.invoiceNumber, isEmpty);
      expect(result.invoice.invoiceSequence, 0);
      expect(result.invoice.financialYear, isEmpty);
      expect(result.updatedSettings.invoiceNextNumber, 7);

      final savedSettings = await CompanySettingsRepository(
        firestore,
      ).fetchAppSettings();
      expect(savedSettings.invoiceNextNumber, 7);
      expect(
        firestore.documents.keys.where((key) => key.startsWith('invoices/')),
        hasLength(1),
      );
    });

    test(
      'saves an incomplete draft without creating a customer record or consuming a number',
      () async {
        final settings = _settings(invoiceNextNumber: 7);
        final profile = _profile();
        final firestore = FakeCustomerFirestoreRestClient({
          'settings/app': AppSettingsModel.fromEntity(settings).toMap(),
        });
        final creator = InvoiceCreator(
          invoiceRepository: InvoiceRepository(firestore),
          customerRepository: CustomerRepository(firestore),
          settingsRepository: CompanySettingsRepository(firestore),
          calculator: InvoiceCalculator(),
          numberingService: NumberingService(),
        );

        final result = await creator.createFromDraft(
          draft: InvoiceDraft(
            customerName: '',
            customerPhone: '',
            customerEmail: '',
            customerGstin: '',
            customerState: '',
            customerStateCode: '',
            billingAddress: '',
            shippingEnabled: false,
            shippingAddress: '',
            invoiceDate: DateTime(2026, 5, 2),
            dueDate: DateTime(2026, 5, 17),
            taxMode: TaxMode.cgstSgst,
            status: InvoiceStatus.draft,
            roundOffEnabled: false,
            discountType: 'none',
            discountValue: 0,
            extraCharges: const [],
            advancePaid: 0,
            advancePaidDate: null,
            advancePaidMethod: '',
            advancePaidReference: '',
            items: [InvoiceItem.empty()],
            notes: '',
            terms: '',
          ),
          settings: settings,
          companyProfile: profile,
          knownCustomers: const [],
        );

        expect(result.invoice.status, InvoiceStatus.draft);
        expect(result.invoice.customerId, isEmpty);
        expect(result.invoice.invoiceNumber, isEmpty);
        expect(result.invoice.subtotal, 0);
        expect(result.updatedSettings.invoiceNextNumber, 7);
        expect(
          firestore.documents.keys.where((key) => key.startsWith('customers/')),
          isEmpty,
        );
      },
    );

    test('edits draft without assigning or consuming invoice number', () async {
      final settings = _settings(invoiceNextNumber: 7);
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient({
        'settings/app': AppSettingsModel.fromEntity(settings).toMap(),
      });
      final creator = InvoiceCreator(
        invoiceRepository: InvoiceRepository(firestore),
        customerRepository: CustomerRepository(firestore),
        settingsRepository: CompanySettingsRepository(firestore),
        calculator: InvoiceCalculator(),
        numberingService: NumberingService(),
      );
      final original = await creator.createFromDraft(
        draft: _draft(
          status: InvoiceStatus.draft,
          discountType: 'none',
          discountValue: 0,
          advancePaid: 0,
        ),
        settings: settings,
        companyProfile: profile,
        knownCustomers: const [],
      );

      final updated = await creator.updateFromDraft(
        existingInvoice: original.invoice,
        draft: _draft(
          existingCustomer: original.customer,
          status: InvoiceStatus.draft,
          discountType: 'amount',
          discountValue: 100,
          advancePaid: 0,
        ),
        settings: original.updatedSettings,
        companyProfile: profile,
        knownCustomers: [original.customer],
      );

      expect(updated.invoice.id, original.invoice.id);
      expect(updated.invoice.status, InvoiceStatus.draft);
      expect(updated.invoice.invoiceNumber, isEmpty);
      expect(updated.invoice.invoiceSequence, 0);
      expect(updated.invoice.discountType, 'amount');
      expect(updated.invoice.discountTotal, 100);
      expect(updated.updatedSettings.invoiceNextNumber, 7);

      final savedSettings = await CompanySettingsRepository(
        firestore,
      ).fetchAppSettings();
      expect(savedSettings.invoiceNextNumber, 7);
      expect(
        firestore.documents.keys.where((key) => key.startsWith('invoices/')),
        hasLength(1),
      );
    });

    test('converts draft to final using next invoice number once', () async {
      final settings = _settings(invoiceNextNumber: 7);
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient({
        'settings/app': AppSettingsModel.fromEntity(settings).toMap(),
      });
      final creator = InvoiceCreator(
        invoiceRepository: InvoiceRepository(firestore),
        customerRepository: CustomerRepository(firestore),
        settingsRepository: CompanySettingsRepository(firestore),
        calculator: InvoiceCalculator(),
        numberingService: NumberingService(),
      );
      final draftResult = await creator.createFromDraft(
        draft: _draft(status: InvoiceStatus.draft, advancePaid: 0),
        settings: settings,
        companyProfile: profile,
        knownCustomers: const [],
      );

      final converted = await creator.updateFromDraft(
        existingInvoice: draftResult.invoice,
        draft: _draft(
          existingCustomer: draftResult.customer,
          status: InvoiceStatus.unpaid,
          advancePaid: 0,
        ),
        settings: draftResult.updatedSettings,
        companyProfile: profile,
        knownCustomers: [draftResult.customer],
      );

      expect(converted.invoice.id, draftResult.invoice.id);
      expect(converted.invoice.createdAt, draftResult.invoice.createdAt);
      expect(converted.invoice.status, InvoiceStatus.unpaid);
      expect(converted.invoice.invoiceNumber, 'INV-2026/05-007');
      expect(converted.invoice.invoiceSequence, 7);
      expect(converted.invoice.financialYear, '2026-27');
      expect(converted.updatedSettings.invoiceNextNumber, 8);

      final savedSettings = await CompanySettingsRepository(
        firestore,
      ).fetchAppSettings();
      expect(savedSettings.invoiceNextNumber, 8);
      expect(
        firestore.documents.keys.where((key) => key.startsWith('invoices/')),
        hasLength(1),
      );
    });

    test('edits existing invoice without creating a new number', () async {
      final settings = _settings(invoiceNextNumber: 12);
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient();
      final creator = InvoiceCreator(
        invoiceRepository: InvoiceRepository(firestore),
        customerRepository: CustomerRepository(firestore),
        settingsRepository: CompanySettingsRepository(firestore),
        calculator: InvoiceCalculator(),
        numberingService: NumberingService(),
      );
      final original = await creator.createFromDraft(
        draft: _draft(discountType: 'none', discountValue: 0, advancePaid: 0),
        settings: settings,
        companyProfile: profile,
        knownCustomers: const [],
      );
      final settingsAfterCreate = await CompanySettingsRepository(
        firestore,
      ).fetchAppSettings();

      final updated = await creator.updateFromDraft(
        existingInvoice: original.invoice,
        draft: _draft(
          existingCustomer: original.customer,
          discountType: 'amount',
          discountValue: 100,
          advancePaid: 50,
        ),
        settings: settingsAfterCreate,
        companyProfile: profile,
        knownCustomers: [original.customer],
      );

      expect(updated.invoice.id, original.invoice.id);
      expect(updated.invoice.invoiceNumber, original.invoice.invoiceNumber);
      expect(updated.invoice.invoiceSequence, original.invoice.invoiceSequence);
      expect(updated.invoice.createdAt, original.invoice.createdAt);
      expect(updated.invoice.discountType, 'amount');
      expect(updated.invoice.discountTotal, 100);
      expect(updated.invoice.amountPaid, 50);
      expect(updated.invoice.paymentHistory, hasLength(1));
      expect(
        firestore.documents.keys.where((key) => key.startsWith('invoices/')),
        hasLength(1),
      );

      final settingsAfterEdit = await CompanySettingsRepository(
        firestore,
      ).fetchAppSettings();
      expect(settingsAfterEdit.invoiceNextNumber, 13);
    });

    test('rejects final save when phone is missing', () async {
      final settings = _settings();
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient();
      final creator = InvoiceCreator(
        invoiceRepository: InvoiceRepository(firestore),
        customerRepository: CustomerRepository(firestore),
        settingsRepository: CompanySettingsRepository(firestore),
        calculator: InvoiceCalculator(),
        numberingService: NumberingService(),
      );

      expect(
        () => creator.createFromDraft(
          draft: _draft(customerPhone: ''),
          settings: settings,
          companyProfile: profile,
          knownCustomers: const [],
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Phone is required.'),
          ),
        ),
      );
    });

    test(
      'rejects final save when due date is earlier than invoice date',
      () async {
        final settings = _settings();
        final profile = _profile();
        final firestore = FakeCustomerFirestoreRestClient();
        final creator = InvoiceCreator(
          invoiceRepository: InvoiceRepository(firestore),
          customerRepository: CustomerRepository(firestore),
          settingsRepository: CompanySettingsRepository(firestore),
          calculator: InvoiceCalculator(),
          numberingService: NumberingService(),
        );

        expect(
          () => creator.createFromDraft(
            draft: _draft(
              invoiceDate: DateTime(2026, 5, 17),
              dueDate: DateTime(2026, 5, 2),
            ),
            settings: settings,
            companyProfile: profile,
            knownCustomers: const [],
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('Due date cannot be earlier than invoice date.'),
            ),
          ),
        );
      },
    );

    test('rejects final save when an item rate is zero', () async {
      final settings = _settings();
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient();
      final creator = InvoiceCreator(
        invoiceRepository: InvoiceRepository(firestore),
        customerRepository: CustomerRepository(firestore),
        settingsRepository: CompanySettingsRepository(firestore),
        calculator: InvoiceCalculator(),
        numberingService: NumberingService(),
      );

      expect(
        () => creator.createFromDraft(
          draft: _draft(itemRate: 0),
          settings: settings,
          companyProfile: profile,
          knownCustomers: const [],
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Rate must be greater than zero for all invoice items.'),
          ),
        ),
      );
    });

    test(
      'caps advance payment at grand total and marks invoice paid',
      () async {
        final settings = _settings();
        final profile = _profile();
        final firestore = FakeCustomerFirestoreRestClient();
        final creator = InvoiceCreator(
          invoiceRepository: InvoiceRepository(firestore),
          customerRepository: CustomerRepository(firestore),
          settingsRepository: CompanySettingsRepository(firestore),
          calculator: InvoiceCalculator(),
          numberingService: NumberingService(),
        );

        final result = await creator.createFromDraft(
          draft: _draft(
            discountType: 'none',
            discountValue: 0,
            advancePaid: 5000,
          ),
          settings: settings,
          companyProfile: profile,
          knownCustomers: const [],
        );

        expect(result.invoice.grandTotal, 4130);
        expect(result.invoice.amountPaid, 4130);
        expect(result.invoice.balanceDue, 0);
        expect(result.invoice.status, InvoiceStatus.paid);
        expect(result.invoice.paidAt, isNotNull);
        expect(result.invoice.paymentHistory.single.amount, 4130);
      },
    );

    test('entered terms override customer and company defaults', () async {
      final existingCustomer = _customer(
        id: 'cust_1',
        phone: '9655246269',
        defaultInvoiceTerms: 'Customer terms',
      );
      final settings = _settings();
      final profile = _profile(defaultInvoiceTerms: 'Company terms');
      final firestore = FakeCustomerFirestoreRestClient({
        'customers/cust_1': CustomerModel.fromEntity(existingCustomer).toMap(),
      });
      final creator = InvoiceCreator(
        invoiceRepository: InvoiceRepository(firestore),
        customerRepository: CustomerRepository(firestore),
        settingsRepository: CompanySettingsRepository(firestore),
        calculator: InvoiceCalculator(),
        numberingService: NumberingService(),
      );

      final result = await creator.createFromDraft(
        draft: _draft(
          existingCustomer: existingCustomer,
          terms: 'Typed on invoice',
        ),
        settings: settings,
        companyProfile: profile,
        knownCustomers: [existingCustomer],
      );

      expect(result.invoice.terms, 'Typed on invoice');
    });

    test(
      'uses the latest reserved invoice number even when caller settings are stale',
      () async {
        final settings = _settings(invoiceNextNumber: 7);
        final profile = _profile();
        final firestore = FakeCustomerFirestoreRestClient({
          'settings/app': AppSettingsModel.fromEntity(settings).toMap(),
        });
        final creator = InvoiceCreator(
          invoiceRepository: InvoiceRepository(firestore),
          customerRepository: CustomerRepository(firestore),
          settingsRepository: CompanySettingsRepository(firestore),
          calculator: InvoiceCalculator(),
          numberingService: NumberingService(),
        );

        final first = await creator.createFromDraft(
          draft: _draft(discountType: 'none', discountValue: 0, advancePaid: 0),
          settings: settings,
          companyProfile: profile,
          knownCustomers: const [],
        );

        final second = await creator.createFromDraft(
          draft: _draft(
            discountType: 'none',
            discountValue: 0,
            advancePaid: 0,
            existingCustomer: first.customer,
          ),
          settings: settings,
          companyProfile: profile,
          knownCustomers: [first.customer],
        );

        expect(first.invoice.invoiceNumber, 'INV-2026/05-007');
        expect(second.invoice.invoiceNumber, 'INV-2026/05-008');
        expect(second.invoice.invoiceSequence, 8);

        final savedSettings = await CompanySettingsRepository(
          firestore,
        ).fetchAppSettings();
        expect(savedSettings.invoiceNextNumber, 9);
      },
    );

    test('deducts tracked product stock only for final invoices', () async {
      final product = _product(stockQuantity: 10);
      final settings = _settings();
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
      });
      final creator = _inventoryAwareCreator(firestore);

      final result = await creator.createFromDraft(
        draft: _draft(
          trackedProduct: product,
          itemQuantity: 2,
          advancePaid: 0,
          discountType: 'none',
          discountValue: 0,
        ),
        settings: settings,
        companyProfile: profile,
        knownCustomers: const [],
      );

      final savedProduct = ProductServiceModel.fromMap(
        product.id,
        firestore.documents['products/${product.id}']!,
      );
      expect(result.invoice.status, InvoiceStatus.unpaid);
      expect(savedProduct.stockQuantity, 8);
      final historyEntry = firestore.documents.entries
          .singleWhere(
            (entry) => entry.key.startsWith('product_inventory_entries/'),
          )
          .value;
      expect(
        historyEntry['type'],
        ProductInventoryEntryType.invoiceIssued.firestoreValue,
      );
      expect(historyEntry['quantityDelta'], -2);
      expect(historyEntry['balanceAfter'], 8);
      expect(historyEntry['reference'], result.invoice.invoiceNumber);
    });

    test('does not deduct tracked stock for draft invoices', () async {
      final product = _product(stockQuantity: 10);
      final settings = _settings();
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
      });
      final creator = _inventoryAwareCreator(firestore);

      await creator.createFromDraft(
        draft: _draft(
          trackedProduct: product,
          itemQuantity: 2,
          status: InvoiceStatus.draft,
          advancePaid: 0,
          discountType: 'none',
          discountValue: 0,
        ),
        settings: settings,
        companyProfile: profile,
        knownCustomers: const [],
      );

      final savedProduct = ProductServiceModel.fromMap(
        product.id,
        firestore.documents['products/${product.id}']!,
      );
      expect(savedProduct.stockQuantity, 10);
    });

    test('deducts stock once when draft becomes final', () async {
      final product = _product(stockQuantity: 10);
      final settings = _settings();
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
      });
      final creator = _inventoryAwareCreator(firestore);

      final draftResult = await creator.createFromDraft(
        draft: _draft(
          trackedProduct: product,
          itemQuantity: 2,
          status: InvoiceStatus.draft,
          advancePaid: 0,
          discountType: 'none',
          discountValue: 0,
        ),
        settings: settings,
        companyProfile: profile,
        knownCustomers: const [],
      );

      await creator.updateFromDraft(
        existingInvoice: draftResult.invoice,
        draft: _draft(
          trackedProduct: product,
          itemQuantity: 2,
          existingCustomer: draftResult.customer,
          status: InvoiceStatus.unpaid,
          advancePaid: 0,
          discountType: 'none',
          discountValue: 0,
        ),
        settings: draftResult.updatedSettings,
        companyProfile: profile,
        knownCustomers: [draftResult.customer],
      );

      final savedProduct = ProductServiceModel.fromMap(
        product.id,
        firestore.documents['products/${product.id}']!,
      );
      expect(savedProduct.stockQuantity, 8);
    });

    test('adjusts stock by net delta when editing a final invoice', () async {
      final product = _product(stockQuantity: 10);
      final settings = _settings();
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
      });
      final creator = _inventoryAwareCreator(firestore);

      final created = await creator.createFromDraft(
        draft: _draft(
          trackedProduct: product,
          itemQuantity: 2,
          advancePaid: 0,
          discountType: 'none',
          discountValue: 0,
        ),
        settings: settings,
        companyProfile: profile,
        knownCustomers: const [],
      );

      await creator.updateFromDraft(
        existingInvoice: created.invoice,
        draft: _draft(
          trackedProduct: product,
          itemQuantity: 3,
          existingCustomer: created.customer,
          advancePaid: 0,
          discountType: 'none',
          discountValue: 0,
        ),
        settings: created.updatedSettings,
        companyProfile: profile,
        knownCustomers: [created.customer],
      );

      final savedProduct = ProductServiceModel.fromMap(
        product.id,
        firestore.documents['products/${product.id}']!,
      );
      expect(savedProduct.stockQuantity, 7);
      final historyEntries = firestore.documents.entries
          .where((entry) => entry.key.startsWith('product_inventory_entries/'))
          .map((entry) => entry.value)
          .toList();
      expect(historyEntries, hasLength(2));
      expect(
        historyEntries.last['type'],
        ProductInventoryEntryType.invoiceUpdated.firestoreValue,
      );
      expect(historyEntries.last['quantityDelta'], -1);
      expect(historyEntries.last['balanceAfter'], 7);
    });

    test('rejects final invoice when tracked stock is insufficient', () async {
      final product = _product(stockQuantity: 1);
      final settings = _settings();
      final profile = _profile();
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
      });
      final creator = _inventoryAwareCreator(firestore);

      expect(
        () => creator.createFromDraft(
          draft: _draft(
            trackedProduct: product,
            itemQuantity: 2,
            advancePaid: 0,
            discountType: 'none',
            discountValue: 0,
          ),
          settings: settings,
          companyProfile: profile,
          knownCustomers: const [],
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Not enough stock'),
          ),
        ),
      );
    });
  });
}

InvoiceDraft _draft({
  Customer? existingCustomer,
  ProductService? trackedProduct,
  InvoiceStatus status = InvoiceStatus.unpaid,
  String discountType = 'percentage',
  double discountValue = 10,
  double advancePaid = 500,
  String customerPhone = '9655246269',
  String terms = '',
  DateTime? invoiceDate,
  DateTime? dueDate,
  double itemRate = 1000,
  double itemQuantity = 1,
}) {
  final resolvedInvoiceDate = invoiceDate ?? DateTime(2026, 5, 2);
  return InvoiceDraft(
    existingCustomer: existingCustomer,
    customerName: 'TBS Enterprises',
    customerPhone: customerPhone,
    customerEmail: 'test@example.com',
    customerGstin: '33AHOPY8219N1ZE',
    customerState: 'Tamil Nadu',
    customerStateCode: '33',
    billingAddress: 'Billing address',
    shippingEnabled: true,
    shippingAddress: 'Shipping address',
    shipToName: 'Site Office',
    shipToPhone: '9840012345',
    shipToEmail: '',
    shipToState: 'Tamil Nadu',
    shipToStateCode: '33',
    shipToPincode: '603102',
    invoiceDate: resolvedInvoiceDate,
    dueDate: dueDate ?? DateTime(2026, 5, 17),
    taxMode: TaxMode.cgstSgst,
    status: status,
    roundOffEnabled: true,
    discountType: discountType,
    discountValue: discountValue,
    extraCharges: discountType == 'none'
        ? const []
        : const [InvoiceCharge(label: 'Packing', amount: 100)],
    advancePaid: advancePaid,
    advancePaidDate: DateTime(2026, 5, 2),
    advancePaidMethod: advancePaid > 0 ? 'UPI' : '',
    advancePaidReference: advancePaid > 0 ? 'UTR-1' : '',
    items: [
      InvoiceItem.empty().copyWith(
        productId: trackedProduct?.id ?? '',
        name: 'Thermal Printer',
        quantity: itemQuantity,
        unit: trackedProduct?.unit ?? 'pcs',
        rate: trackedProduct?.defaultRate ?? itemRate,
        gstRate: 18,
        hsnSac: trackedProduct?.hsnSac ?? '',
      ),
      InvoiceItem.empty().copyWith(
        name: 'Installation',
        quantity: 1,
        unit: 'service',
        rate: 2500,
        gstRate: 18,
      ),
    ],
    notes: '',
    terms: terms,
  );
}

InvoiceCreator _inventoryAwareCreator(
  FakeCustomerFirestoreRestClient firestore,
) {
  return InvoiceCreator(
    invoiceRepository: InvoiceRepository(firestore),
    customerRepository: CustomerRepository(firestore),
    productRepository: ProductRepository(firestore),
    productInventoryRepository: ProductInventoryRepository(firestore),
    settingsRepository: CompanySettingsRepository(firestore),
    calculator: InvoiceCalculator(),
    inventoryTransitionService: const InventoryTransitionService(),
    numberingService: NumberingService(),
  );
}

Customer _customer({
  required String id,
  required String phone,
  int loyaltyPointsBalance = 0,
  int lifetimePointsEarned = 0,
  String defaultInvoiceTerms = '',
}) {
  final now = DateTime(2026, 5, 1);
  return Customer(
    id: id,
    name: 'TBS Enterprises',
    phone: phone,
    email: 'old@example.com',
    billingAddress: 'Old address',
    shippingAddress: '',
    gstin: '',
    state: 'Tamil Nadu',
    defaultDiscountType: 'none',
    defaultDiscountValue: 0,
    loyaltyEnabled: true,
    loyaltyPointsBalance: loyaltyPointsBalance,
    lifetimePointsEarned: lifetimePointsEarned,
    lifetimePointsRedeemed: 0,
    totalBilled: 0,
    totalPaid: 0,
    outstandingAmount: 0,
    notes: '',
    defaultInvoiceTerms: defaultInvoiceTerms,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

AppSettings _settings({int invoiceNextNumber = 1}) {
  final initial = AppSettings.initial();
  return AppSettings(
    gstEnabled: initial.gstEnabled,
    defaultGstRate: initial.defaultGstRate,
    invoicePrefix: 'INV',
    invoiceSeparator: '-',
    invoiceDateFormat: 'yyyy/MM',
    invoiceNextNumber: invoiceNextNumber,
    invoiceNumberPadding: 3,
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
    defaultCustomerState: initial.defaultCustomerState,
    defaultShippingState: initial.defaultShippingState,
    defaultLineItemUnit: initial.defaultLineItemUnit,
    customCustomerFields: initial.customCustomerFields,
    customShippingFields: initial.customShippingFields,
    customLineItemFields: initial.customLineItemFields,
    updatedAt: DateTime(2026, 5, 1),
  );
}

CompanyProfile _profile({String defaultInvoiceTerms = 'Company terms'}) {
  final empty = CompanyProfile.empty();
  return CompanyProfile(
    businessName: 'CompanyTest',
    legalName: empty.legalName,
    gstin: empty.gstin,
    pan: empty.pan,
    email: empty.email,
    phone: empty.phone,
    website: empty.website,
    addressLine1: empty.addressLine1,
    addressLine2: empty.addressLine2,
    city: empty.city,
    state: empty.state,
    pincode: empty.pincode,
    country: empty.country,
    bankName: empty.bankName,
    bankAccountName: empty.bankAccountName,
    bankAccountNumber: empty.bankAccountNumber,
    ifscCode: empty.ifscCode,
    upiId: empty.upiId,
    defaultInvoiceTerms: defaultInvoiceTerms,
    defaultQuotationTerms: empty.defaultQuotationTerms,
    logoBase64: empty.logoBase64,
    paymentQrBase64: empty.paymentQrBase64,
    updatedAt: DateTime(2026, 5, 1),
  );
}

ProductService _product({double stockQuantity = 10}) {
  final now = DateTime(2026, 5, 1);
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
    costPrice: 0,
    stockQuantity: stockQuantity,
    reorderLevel: 2,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
