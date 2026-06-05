import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/domain/entities/purchase_entry.dart';
import 'package:invo_print/features/products/domain/entities/supplier.dart';
import 'package:invo_print/features/products/domain/services/supplier_ledger.dart';

void main() {
  group('buildSupplierLedger', () {
    test('summarizes purchases, payments, and outstanding balance', () {
      final supplier = Supplier(
        id: 'sup_1',
        name: 'Supply Hub',
        phone: '',
        email: '',
        gstin: '',
        address: '',
        notes: '',
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );

      final ledger = buildSupplierLedger(
        supplier: supplier,
        purchaseEntries: [
          _entry(
            id: 'pur_1',
            supplierId: supplier.id,
            purchaseDate: DateTime(2026, 6, 5),
            totalAmount: 6000,
            amountPaid: 2500,
            status: PurchasePaymentStatus.partial,
            paymentHistory: [
              PurchasePayment(
                amount: 1000,
                paidAt: DateTime(2026, 6, 6),
                method: 'UPI',
                reference: 'PAY-1',
              ),
              PurchasePayment(
                amount: 1500,
                paidAt: DateTime(2026, 6, 7),
                method: 'Bank',
                reference: 'PAY-2',
              ),
            ],
          ),
          _entry(
            id: 'pur_2',
            supplierId: '',
            supplierName: supplier.name,
            purchaseDate: DateTime(2026, 6, 8),
            totalAmount: 4000,
            amountPaid: 0,
            status: PurchasePaymentStatus.unpaid,
            paymentHistory: const [],
          ),
          _entry(
            id: 'pur_3',
            supplierId: 'sup_other',
            supplierName: 'Elsewhere',
            purchaseDate: DateTime(2026, 6, 9),
            totalAmount: 999,
            amountPaid: 0,
            status: PurchasePaymentStatus.unpaid,
            paymentHistory: const [],
          ),
        ],
      );

      expect(ledger.purchaseEntries.map((entry) => entry.id), [
        'pur_2',
        'pur_1',
      ]);
      expect(ledger.totalPurchased, 10000);
      expect(ledger.totalPaid, 2500);
      expect(ledger.outstandingBalance, 7500);
      expect(ledger.entries, hasLength(4));
      expect(
        ledger.entries.first.reference,
        'pur_2'.replaceFirst('pur_', 'PUR-'),
      );
      expect(ledger.entries.first.type, SupplierLedgerEntryType.purchase);
      expect(
        ledger.entries.where(
          (entry) => entry.type == SupplierLedgerEntryType.payment,
        ),
        hasLength(2),
      );
      expect(
        ledger.entries
            .where((entry) => entry.type == SupplierLedgerEntryType.payment)
            .first
            .amount,
        lessThan(0),
      );
    });
  });
}

PurchaseEntry _entry({
  required String id,
  required DateTime purchaseDate,
  required double totalAmount,
  required double amountPaid,
  required PurchasePaymentStatus status,
  required List<PurchasePayment> paymentHistory,
  String supplierId = 'sup_1',
  String supplierName = 'Supply Hub',
}) {
  return PurchaseEntry(
    id: id,
    entryNumber: id.replaceFirst('pur_', 'PUR-'),
    supplierId: supplierId,
    supplierName: supplierName,
    billReference: '',
    purchaseDate: purchaseDate,
    items: const [],
    notes: '',
    totalAmount: totalAmount,
    amountPaid: amountPaid,
    paymentHistory: paymentHistory,
    status: status,
    isActive: true,
    createdAt: purchaseDate,
    updatedAt: purchaseDate,
  );
}
