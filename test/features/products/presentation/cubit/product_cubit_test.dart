import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/product_inventory_entry_model.dart';
import 'package:invo_print/features/products/data/models/product_service_model.dart';
import 'package:invo_print/features/products/data/repositories/product_inventory_repository.dart';
import 'package:invo_print/features/products/data/repositories/product_repository.dart';
import 'package:invo_print/features/products/domain/entities/product_inventory_entry.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';
import 'package:invo_print/features/products/presentation/cubit/product_cubit.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('ProductCubit', () {
    test('adjustStock saves product stock and history entry', () async {
      final product = _product(stockQuantity: 5);
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
      });
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.adjustStock(
        product,
        quantityDelta: 3,
        reason: 'Physical count',
        note: 'Restocked',
      );

      expect(cubit.state.status, ProductStatus.saved);
      expect(cubit.state.products.single.stockQuantity, 8);

      final historyEntry = ProductInventoryEntryModel.fromMap(
        firestore.documents.entries
            .singleWhere(
              (entry) => entry.key.startsWith('product_inventory_entries/'),
            )
            .key
            .split('/')
            .last,
        firestore.documents.entries
            .singleWhere(
              (entry) => entry.key.startsWith('product_inventory_entries/'),
            )
            .value,
      );
      expect(historyEntry.type, ProductInventoryEntryType.manualAdjustment);
      expect(historyEntry.quantityDelta, 3);
      expect(historyEntry.balanceAfter, 8);
      expect(historyEntry.reason, 'Physical count');
      expect(historyEntry.note, 'Restocked');
    });

    test(
      'adjustStock rejects changes that would send stock below zero',
      () async {
        final product = _product(stockQuantity: 2);
        final firestore = FakeCustomerFirestoreRestClient({
          'products/${product.id}': ProductServiceModel.fromEntity(
            product,
          ).toMap(),
        });
        final cubit = ProductCubit(
          ProductRepository(firestore),
          ProductInventoryRepository(firestore),
        );
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.adjustStock(product, quantityDelta: -3, reason: 'Damage');

        expect(cubit.state.status, ProductStatus.failure);
        expect(cubit.state.message, contains('below zero'));
        expect(
          firestore.documents.keys.where(
            (key) => key.startsWith('product_inventory_entries/'),
          ),
          isEmpty,
        );
      },
    );

    test('loadInventoryEntries returns saved history newest first', () async {
      final product = _product();
      final older = ProductInventoryEntry(
        id: 'stock_older',
        productId: product.id,
        type: ProductInventoryEntryType.invoiceIssued,
        quantityDelta: -1,
        balanceAfter: 9,
        createdAt: DateTime(2026, 6, 3),
      );
      final newer = ProductInventoryEntry(
        id: 'stock_newer',
        productId: product.id,
        type: ProductInventoryEntryType.invoiceUpdated,
        quantityDelta: -2,
        balanceAfter: 7,
        createdAt: DateTime(2026, 6, 4),
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
        'product_inventory_entries/${older.id}':
            ProductInventoryEntryModel.fromEntity(older).toMap(),
        'product_inventory_entries/${newer.id}':
            ProductInventoryEntryModel.fromEntity(newer).toMap(),
      });
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
      );
      addTearDown(cubit.close);

      final entries = await cubit.loadInventoryEntries(product.id);

      expect(entries.map((entry) => entry.id), ['stock_newer', 'stock_older']);
    });
  });
}

ProductService _product({double stockQuantity = 5}) {
  final now = DateTime(2026, 6, 4);
  return ProductService(
    id: 'prod_1',
    name: 'Thermal Printer',
    description: '',
    type: ProductServiceType.product,
    sku: 'PRN-1',
    unit: 'pcs',
    defaultRate: 2500,
    hsnSac: '8443',
    gstRate: 18,
    trackInventory: true,
    stockQuantity: stockQuantity,
    reorderLevel: 2,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
