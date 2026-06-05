import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/purchase_entry_model.dart';
import 'package:invo_print/features/products/domain/entities/purchase_entry.dart';

void main() {
  group('PurchaseEntryModel', () {
    test('round-trips purchase entry items and optional fields', () {
      final date = DateTime(2026, 6, 5, 11, 30);
      final model = PurchaseEntryModel(
        id: 'pur_1',
        entryNumber: 'PUR-202606-001',
        supplierId: 'sup_1',
        supplierName: 'Supply Hub',
        billReference: 'BILL-44',
        purchaseDate: date,
        items: const [
          PurchaseEntryItem(
            productId: 'prod_1',
            productName: 'Thermal Printer',
            sku: 'PRN-1',
            unit: 'pcs',
            quantity: 2,
            unitCost: 2000,
            lineTotal: 4000,
          ),
        ],
        notes: 'Monthly restock',
        totalAmount: 4000,
        isActive: true,
        createdAt: date,
        updatedAt: date,
      );

      final map = model.toMap();
      final restored = PurchaseEntryModel.fromMap('pur_1', map);

      expect(restored, model);
      expect((map['items'] as List).single['productId'], 'prod_1');
    });

    test('reads sparse legacy purchase entry maps safely', () {
      final model = PurchaseEntryModel.fromMap('pur_1', {
        'entryNumber': 'PUR-1',
        'supplierName': 'Supply Hub',
        'purchaseDate': '2026-06-05T00:00:00.000',
        'createdAt': '2026-06-05T00:00:00.000',
        'updatedAt': '2026-06-05T00:00:00.000',
      });

      expect(model.entryNumber, 'PUR-1');
      expect(model.items, isEmpty);
      expect(model.totalAmount, 0);
      expect(model.billReference, isEmpty);
    });
  });
}
