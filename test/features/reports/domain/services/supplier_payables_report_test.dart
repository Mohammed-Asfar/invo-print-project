import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/domain/entities/purchase_entry.dart';
import 'package:invo_print/features/products/domain/entities/supplier.dart';
import 'package:invo_print/features/reports/domain/services/supplier_payables_report.dart';

void main() {
  group('buildSupplierPayablesReport', () {
    test('summarizes bills and outstanding grouped by supplier', () {
      final suppliers = [
        _supplier(id: 'sup_1', name: 'Supply Hub'),
        _supplier(id: 'sup_2', name: 'Metro Traders'),
      ];
      final report = buildSupplierPayablesReport(
        suppliers: suppliers,
        purchaseEntries: [
          _entry(
            id: 'pur_1',
            supplierId: 'sup_1',
            supplierName: 'Supply Hub',
            purchaseDate: DateTime(2026, 6, 2),
            totalAmount: 4000,
            amountPaid: 0,
            status: PurchasePaymentStatus.unpaid,
          ),
          _entry(
            id: 'pur_2',
            supplierId: '',
            supplierName: 'Supply Hub',
            purchaseDate: DateTime(2026, 6, 5),
            totalAmount: 3000,
            amountPaid: 2000,
            status: PurchasePaymentStatus.partial,
          ),
          _entry(
            id: 'pur_3',
            supplierId: 'sup_2',
            supplierName: 'Metro Traders',
            purchaseDate: DateTime(2026, 6, 4),
            totalAmount: 1500,
            amountPaid: 1500,
            status: PurchasePaymentStatus.paid,
          ),
        ],
      );

      expect(report.supplierCount, 2);
      expect(report.billCount, 3);
      expect(report.openBillCount, 2);
      expect(report.unpaidBillCount, 1);
      expect(report.partialBillCount, 1);
      expect(report.totalPurchased, 8500);
      expect(report.totalPaid, 3500);
      expect(report.totalOutstanding, 5000);
      expect(report.rows.first.supplierName, 'Supply Hub');
      expect(report.rows.first.outstandingBalance, 5000);
    });
  });

  group('buildSupplierPayablesCsv', () {
    test('escapes special characters and prints summary', () {
      final report = buildSupplierPayablesReport(
        suppliers: [_supplier(id: 'sup_1', name: 'ACME, "South"')],
        purchaseEntries: [
          _entry(
            id: 'pur_1',
            supplierId: 'sup_1',
            supplierName: 'ACME, "South"',
            purchaseDate: DateTime(2026, 6, 2),
            totalAmount: 4000,
            amountPaid: 500,
            status: PurchasePaymentStatus.partial,
          ),
        ],
      );

      final csv = buildSupplierPayablesCsv(report);

      expect(csv, contains('"ACME, ""South"""'));
      expect(csv, contains('Total Outstanding,3500.00'));
    });
  });
}

Supplier _supplier({required String id, required String name}) {
  final now = DateTime(2026, 6, 5);
  return Supplier(
    id: id,
    name: name,
    phone: '',
    email: '',
    gstin: '',
    address: '',
    notes: '',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

PurchaseEntry _entry({
  required String id,
  required String supplierId,
  required String supplierName,
  required DateTime purchaseDate,
  required double totalAmount,
  required double amountPaid,
  required PurchasePaymentStatus status,
}) {
  return PurchaseEntry(
    id: id,
    entryNumber: 'PUR-${id.split('_').last}',
    supplierId: supplierId,
    supplierName: supplierName,
    billReference: '',
    purchaseDate: purchaseDate,
    items: const [],
    notes: '',
    totalAmount: totalAmount,
    amountPaid: amountPaid,
    paymentHistory: const [],
    status: status,
    isActive: true,
    createdAt: purchaseDate,
    updatedAt: purchaseDate,
  );
}
