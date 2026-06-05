import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/domain/entities/purchase_entry.dart';
import 'package:invo_print/features/products/domain/entities/supplier.dart';
import 'package:invo_print/features/products/presentation/cubit/product_cubit.dart';

void main() {
  group('ProductState purchase filters', () {
    test('filters by search status and supplier together', () {
      final supplyHub = _supplier(id: 'sup_1', name: 'Supply Hub');
      final metro = _supplier(id: 'sup_2', name: 'Metro Traders');
      final state = ProductState(
        suppliers: [supplyHub, metro],
        purchaseEntries: [
          _purchaseEntry(
            id: 'pur_1',
            supplierId: supplyHub.id,
            supplierName: supplyHub.name,
            status: PurchasePaymentStatus.unpaid,
            balanceDue: 2500,
            productName: 'Thermal Printer',
          ),
          _purchaseEntry(
            id: 'pur_2',
            supplierId: metro.id,
            supplierName: metro.name,
            status: PurchasePaymentStatus.partial,
            balanceDue: 500,
            productName: 'Barcode Scanner',
          ),
          _purchaseEntry(
            id: 'pur_3',
            supplierId: supplyHub.id,
            supplierName: supplyHub.name,
            status: PurchasePaymentStatus.paid,
            balanceDue: 0,
            productName: 'Label Roll',
          ),
        ],
        purchaseSearchQuery: 'thermal',
        purchaseStatusFilter: PurchaseStatusFilter.unpaid,
        purchaseSupplierId: supplyHub.id,
      );

      expect(state.filteredPurchaseEntries.map((entry) => entry.id), ['pur_1']);
      expect(state.openPurchaseCount, 2);
      expect(state.unpaidPurchaseCount, 1);
      expect(state.partialPurchaseCount, 1);
      expect(state.totalPurchaseOutstanding, 3000);
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

PurchaseEntry _purchaseEntry({
  required String id,
  required String supplierId,
  required String supplierName,
  required PurchasePaymentStatus status,
  required double balanceDue,
  required String productName,
}) {
  final totalAmount = balanceDue == 0 ? 1000.0 : 3000.0;
  final amountPaid = totalAmount - balanceDue;
  final now = DateTime(2026, 6, 5);
  return PurchaseEntry(
    id: id,
    entryNumber: 'PUR-${id.split('_').last}',
    supplierId: supplierId,
    supplierName: supplierName,
    billReference: '',
    purchaseDate: now,
    items: [
      PurchaseEntryItem(
        productId: 'prod_$id',
        productName: productName,
        sku: 'SKU-$id',
        unit: 'pcs',
        quantity: 1,
        unitCost: totalAmount,
        lineTotal: totalAmount,
      ),
    ],
    notes: '',
    totalAmount: totalAmount,
    amountPaid: amountPaid,
    paymentHistory: const [],
    status: status,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
