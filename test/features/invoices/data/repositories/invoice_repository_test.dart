import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/invoices/data/models/invoice_model.dart';
import 'package:invo_print/features/invoices/data/repositories/invoice_repository.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('InvoiceRepository', () {
    test(
      'fetchInvoices returns only active invoices sorted by createdAt desc',
      () async {
        final newer = _invoice(
          id: 'inv_new',
          invoiceNumber: 'INV-002',
          createdAt: DateTime(2026, 5, 3),
        );
        final older = _invoice(
          id: 'inv_old',
          invoiceNumber: 'INV-001',
          createdAt: DateTime(2026, 5, 2),
        );
        final firestore = FakeCustomerFirestoreRestClient({
          'invoices/${older.id}': InvoiceModel.fromEntity(older).toMap(),
          'invoices/${newer.id}': InvoiceModel.fromEntity(newer).toMap(),
          'invoices/inv_archived': InvoiceModel.fromEntity(
            _invoice(
              id: 'inv_archived',
              invoiceNumber: 'INV-000',
              createdAt: DateTime(2026, 5, 1),
            ),
          ).toArchiveMap(archivedAt: DateTime(2026, 6, 2)),
        });

        final invoices = await InvoiceRepository(firestore).fetchInvoices();

        expect(invoices.map((invoice) => invoice.id), ['inv_new', 'inv_old']);
      },
    );

    test(
      'archiveInvoice keeps document but removes it from active fetches',
      () async {
        final invoice = _invoice();
        final firestore = FakeCustomerFirestoreRestClient({
          'invoices/${invoice.id}': InvoiceModel.fromEntity(invoice).toMap(),
        });
        final repository = InvoiceRepository(firestore);

        await repository.archiveInvoice(invoice);

        final stored = firestore.documents['invoices/${invoice.id}']!;
        expect(stored['isActive'], isFalse);
        expect(stored['archivedAt'], isA<DateTime>());

        final invoices = await repository.fetchInvoices();
        expect(invoices, isEmpty);
      },
    );
  });
}

Invoice _invoice({
  String id = 'inv_1',
  String invoiceNumber = 'INV-001',
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2026, 5, 2);
  return Invoice(
    id: id,
    invoiceNumber: invoiceNumber,
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
