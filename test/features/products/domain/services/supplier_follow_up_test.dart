import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/domain/entities/purchase_entry.dart';
import 'package:invo_print/features/products/domain/entities/supplier.dart';
import 'package:invo_print/features/products/domain/services/supplier_follow_up.dart';

void main() {
  group('buildSupplierFollowUpQueue', () {
    test('prioritizes overdue suppliers and reminder-due follow-ups', () {
      final today = DateTime(2026, 6, 6);
      final overdueSupplier = _supplier(
        id: 'sup_1',
        name: 'Supply Hub',
        followUpStatus: SupplierFollowUpStatus.pending,
        nextFollowUpDate: today.subtract(const Duration(days: 1)),
      );
      final waitingSupplier = _supplier(
        id: 'sup_2',
        name: 'Metro Traders',
        followUpStatus: SupplierFollowUpStatus.waiting,
        lastContactedAt: today.subtract(const Duration(days: 2)),
        nextFollowUpDate: today.add(const Duration(days: 3)),
      );
      final queue = buildSupplierFollowUpQueue(
        suppliers: [overdueSupplier, waitingSupplier],
        purchaseEntries: [
          _purchaseEntry(
            id: 'pur_1',
            supplierId: overdueSupplier.id,
            supplierName: overdueSupplier.name,
            totalAmount: 5000,
            amountPaid: 1000,
            purchaseDate: today.subtract(const Duration(days: 20)),
            dueDate: today.subtract(const Duration(days: 5)),
          ),
          _purchaseEntry(
            id: 'pur_2',
            supplierId: waitingSupplier.id,
            supplierName: waitingSupplier.name,
            totalAmount: 4000,
            amountPaid: 1500,
            purchaseDate: today.subtract(const Duration(days: 8)),
            dueDate: today.add(const Duration(days: 7)),
          ),
        ],
        today: today,
      );

      expect(queue.actionCount, 1);
      expect(queue.overdueSupplierCount, 1);
      expect(queue.reminderDueCount, 1);
      expect(queue.totalOverdueAmount, 4000);
      expect(queue.rows.first.supplier.id, overdueSupplier.id);
      expect(queue.rows.first.needsAction, isTrue);
      expect(queue.rows.first.reminderDue, isTrue);
      expect(queue.rows.last.supplier.id, waitingSupplier.id);
      expect(queue.rows.last.needsAction, isFalse);
    });

    test('skips suppliers with no payables and no follow-up action', () {
      final today = DateTime(2026, 6, 6);
      final supplier = _supplier(id: 'sup_1', name: 'Quiet Supply');

      final queue = buildSupplierFollowUpQueue(
        suppliers: [supplier],
        purchaseEntries: const [],
        today: today,
      );

      expect(queue.rows, isEmpty);
      expect(queue.actionCount, 0);
      expect(queue.totalOverdueAmount, 0);
    });
  });

  test('buildSupplierFollowUpCsv exports reminder and overdue details', () {
    final today = DateTime(2026, 6, 6);
    final supplier = _supplier(
      id: 'sup_1',
      name: 'Supply Hub',
      followUpStatus: SupplierFollowUpStatus.pending,
      lastContactedAt: today.subtract(const Duration(days: 2)),
      nextFollowUpDate: today,
    ).copyWith(followUpNotes: 'Call on Monday');

    final queue = buildSupplierFollowUpQueue(
      suppliers: [supplier],
      purchaseEntries: [
        _purchaseEntry(
          id: 'pur_1',
          supplierId: supplier.id,
          supplierName: supplier.name,
          totalAmount: 5000,
          amountPaid: 1000,
          purchaseDate: today.subtract(const Duration(days: 20)),
          dueDate: today.subtract(const Duration(days: 5)),
        ),
      ],
      today: today,
    );

    final csv = buildSupplierFollowUpCsv(queue);

    expect(csv, contains('Supplier,Status,Outstanding'));
    expect(csv, contains('Supply Hub'));
    expect(csv, contains('Needs follow-up'));
    expect(csv, contains('Call on Monday'));
    expect(csv, contains('Action Queue'));
  });
}

Supplier _supplier({
  required String id,
  required String name,
  SupplierFollowUpStatus followUpStatus = SupplierFollowUpStatus.none,
  DateTime? lastContactedAt,
  DateTime? nextFollowUpDate,
}) {
  final now = DateTime(2026, 6, 5);
  return Supplier(
    id: id,
    name: name,
    phone: '',
    email: '',
    gstin: '',
    address: '',
    notes: '',
    followUpStatus: followUpStatus,
    lastContactedAt: lastContactedAt,
    nextFollowUpDate: nextFollowUpDate,
    followUpNotes: '',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

PurchaseEntry _purchaseEntry({
  required String id,
  required String supplierId,
  required String supplierName,
  required double totalAmount,
  required double amountPaid,
  required DateTime purchaseDate,
  required DateTime dueDate,
}) {
  return PurchaseEntry(
    id: id,
    entryNumber: 'PUR-${id.split('_').last}',
    supplierId: supplierId,
    supplierName: supplierName,
    billReference: '',
    purchaseDate: purchaseDate,
    dueDate: dueDate,
    items: const [
      PurchaseEntryItem(
        productId: 'prod_1',
        productName: 'Thermal Printer',
        sku: 'PRN-1',
        unit: 'pcs',
        quantity: 1,
        unitCost: 1000,
        lineTotal: 1000,
      ),
    ],
    notes: '',
    totalAmount: totalAmount,
    amountPaid: amountPaid,
    paymentHistory: const [],
    status: amountPaid <= 0
        ? PurchasePaymentStatus.unpaid
        : amountPaid >= totalAmount
        ? PurchasePaymentStatus.paid
        : PurchasePaymentStatus.partial,
    isActive: true,
    createdAt: purchaseDate,
    updatedAt: purchaseDate,
  );
}
