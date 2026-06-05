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
        asOfDate: DateTime(2026, 10, 15),
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
      expect(report.overdueBillCount, 2);
      expect(report.unpaidBillCount, 1);
      expect(report.partialBillCount, 1);
      expect(report.totalPurchased, 8500);
      expect(report.totalPaid, 3500);
      expect(report.totalOutstanding, 5000);
      expect(report.totalOverdue, 5000);
      expect(report.currentBucketTotal, 0);
      expect(report.days31To60BucketTotal, 0);
      expect(report.days61To90BucketTotal, 0);
      expect(report.days90PlusBucketTotal, 5000);
      expect(report.rows.first.supplierName, 'Supply Hub');
      expect(report.rows.first.overdueBillCount, 2);
      expect(report.rows.first.overdueAmount, 5000);
      expect(report.rows.first.outstandingBalance, 5000);
    });

    test('calculates aging buckets from due date when available', () {
      final report = buildSupplierPayablesReport(
        suppliers: [_supplier(id: 'sup_1', name: 'Supply Hub')],
        asOfDate: DateTime(2026, 6, 30),
        purchaseEntries: [
          _entry(
            id: 'pur_1',
            supplierId: 'sup_1',
            supplierName: 'Supply Hub',
            purchaseDate: DateTime(2026, 6, 20),
            dueDate: DateTime(2026, 6, 20),
            totalAmount: 1000,
            amountPaid: 0,
            status: PurchasePaymentStatus.unpaid,
          ),
          _entry(
            id: 'pur_2',
            supplierId: 'sup_1',
            supplierName: 'Supply Hub',
            purchaseDate: DateTime(2026, 5, 20),
            dueDate: DateTime(2026, 5, 20),
            totalAmount: 2000,
            amountPaid: 0,
            status: PurchasePaymentStatus.unpaid,
          ),
          _entry(
            id: 'pur_3',
            supplierId: 'sup_1',
            supplierName: 'Supply Hub',
            purchaseDate: DateTime(2026, 4, 20),
            dueDate: DateTime(2026, 4, 20),
            totalAmount: 3000,
            amountPaid: 0,
            status: PurchasePaymentStatus.unpaid,
          ),
          _entry(
            id: 'pur_4',
            supplierId: 'sup_1',
            supplierName: 'Supply Hub',
            purchaseDate: DateTime(2026, 6, 25),
            dueDate: DateTime(2026, 3, 20),
            totalAmount: 4000,
            amountPaid: 0,
            status: PurchasePaymentStatus.unpaid,
          ),
        ],
      );

      final row = report.rows.single;
      expect(row.currentBucketAmount, 1000);
      expect(row.days31To60BucketAmount, 2000);
      expect(row.days61To90BucketAmount, 3000);
      expect(row.days90PlusBucketAmount, 4000);
      expect(row.overdueBillCount, 4);
      expect(row.overdueAmount, 10000);
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

      expect(csv, contains('Overdue Bills'));
      expect(csv, contains('Overdue Amount'));
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
  DateTime? dueDate,
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
    dueDate: dueDate,
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
