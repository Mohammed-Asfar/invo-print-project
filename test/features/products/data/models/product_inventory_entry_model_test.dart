import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/product_inventory_entry_model.dart';
import 'package:invo_print/features/products/domain/entities/product_inventory_entry.dart';

void main() {
  group('ProductInventoryEntryModel', () {
    test('round-trips required and optional fields', () {
      final createdAt = DateTime(2026, 6, 4, 10, 30);
      final model = ProductInventoryEntryModel(
        id: 'stock_1',
        productId: 'prod_1',
        type: ProductInventoryEntryType.invoiceIssued,
        quantityDelta: -2,
        balanceAfter: 8,
        createdAt: createdAt,
        reference: 'INV-001',
        reason: 'Invoice issued',
        note: 'First issue',
      );

      final map = model.toMap();
      final restored = ProductInventoryEntryModel.fromMap('stock_1', map);

      expect(restored, model);
      expect(map['type'], 'invoice_issued');
    });

    test('omits empty optional strings from map', () {
      final map = ProductInventoryEntryModel(
        id: 'stock_1',
        productId: 'prod_1',
        type: ProductInventoryEntryType.manualAdjustment,
        quantityDelta: 3,
        balanceAfter: 11,
        createdAt: DateTime(2026, 6, 4),
      ).toMap();

      expect(map.containsKey('reference'), isFalse);
      expect(map.containsKey('reason'), isFalse);
      expect(map.containsKey('note'), isFalse);
    });

    test('reads sparse legacy maps safely', () {
      final model = ProductInventoryEntryModel.fromMap('stock_1', {
        'productId': 'prod_1',
        'type': 'invoice_cancelled',
        'quantityDelta': '2',
        'balanceAfter': 10,
        'createdAt': '2026-06-04T10:30:00.000',
      });

      expect(model.productId, 'prod_1');
      expect(model.type, ProductInventoryEntryType.invoiceCancelled);
      expect(model.quantityDelta, 2);
      expect(model.balanceAfter, 10);
      expect(model.reference, isEmpty);
      expect(model.reason, isEmpty);
      expect(model.note, isEmpty);
    });
  });
}
