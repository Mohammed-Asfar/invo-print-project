import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/product_inventory_entry_model.dart';
import 'package:invo_print/features/products/data/repositories/product_inventory_repository.dart';
import 'package:invo_print/features/products/domain/entities/product_inventory_entry.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('ProductInventoryRepository', () {
    test('fetchEntries filters by product and sorts newest first', () async {
      final older = _entry(
        id: 'stock_older',
        productId: 'prod_1',
        createdAt: DateTime(2026, 6, 3),
      );
      final newer = _entry(
        id: 'stock_newer',
        productId: 'prod_1',
        createdAt: DateTime(2026, 6, 4),
      );
      final otherProduct = _entry(
        id: 'stock_other',
        productId: 'prod_2',
        createdAt: DateTime(2026, 6, 5),
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'product_inventory_entries/${older.id}':
            ProductInventoryEntryModel.fromEntity(older).toMap(),
        'product_inventory_entries/${newer.id}':
            ProductInventoryEntryModel.fromEntity(newer).toMap(),
        'product_inventory_entries/${otherProduct.id}':
            ProductInventoryEntryModel.fromEntity(otherProduct).toMap(),
      });

      final entries = await ProductInventoryRepository(
        firestore,
      ).fetchEntries('prod_1');

      expect(entries.map((entry) => entry.id), ['stock_newer', 'stock_older']);
    });

    test('saveEntries persists generated and explicit ids', () async {
      final firestore = FakeCustomerFirestoreRestClient();
      final repository = ProductInventoryRepository(firestore);

      await repository.saveEntries([
        _entry(id: '', productId: 'prod_1'),
        _entry(id: 'stock_fixed', productId: 'prod_1'),
      ]);

      expect(
        firestore.documents.keys.where(
          (key) => key.startsWith('product_inventory_entries/'),
        ),
        hasLength(2),
      );
      expect(
        firestore.documents.containsKey(
          'product_inventory_entries/stock_fixed',
        ),
        isTrue,
      );
    });

    test('deleteEntries removes each targeted document', () async {
      final first = _entry(id: 'stock_1', productId: 'prod_1');
      final second = _entry(id: 'stock_2', productId: 'prod_1');
      final firestore = FakeCustomerFirestoreRestClient({
        'product_inventory_entries/${first.id}':
            ProductInventoryEntryModel.fromEntity(first).toMap(),
        'product_inventory_entries/${second.id}':
            ProductInventoryEntryModel.fromEntity(second).toMap(),
      });

      await ProductInventoryRepository(
        firestore,
      ).deleteEntries([first.id, second.id]);

      expect(firestore.documents, isEmpty);
    });
  });
}

ProductInventoryEntry _entry({
  required String id,
  required String productId,
  DateTime? createdAt,
}) {
  return ProductInventoryEntry(
    id: id,
    productId: productId,
    type: ProductInventoryEntryType.manualAdjustment,
    quantityDelta: 2,
    balanceAfter: 10,
    createdAt: createdAt ?? DateTime(2026, 6, 4, 10, 30),
    reason: 'Manual fix',
  );
}
