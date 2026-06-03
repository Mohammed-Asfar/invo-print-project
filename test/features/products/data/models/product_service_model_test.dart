import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/product_service_model.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';

void main() {
  group('ProductServiceModel', () {
    test('reads older sparse product maps with inventory defaults', () {
      final product = ProductServiceModel.fromMap('prod_1', {
        'name': 'Installation',
        'type': 'service',
        'createdAt': DateTime(2026, 5, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 5, 2).toIso8601String(),
      });

      expect(product.name, 'Installation');
      expect(product.sku, isEmpty);
      expect(product.trackInventory, isFalse);
      expect(product.stockQuantity, 0);
      expect(product.reorderLevel, 0);
    });

    test('stores inventory fields only when tracking is enabled', () {
      final untracked = ProductServiceModel.fromEntity(
        ProductService.empty().copyWith(name: 'Consulting', sku: 'CONS-1'),
      ).toMap();

      expect(untracked, containsPair('sku', 'CONS-1'));
      expect(untracked, isNot(contains('trackInventory')));
      expect(untracked, isNot(contains('stockQuantity')));
      expect(untracked, isNot(contains('reorderLevel')));

      final tracked = ProductServiceModel.fromEntity(
        ProductService.empty().copyWith(
          name: 'Printer',
          type: ProductServiceType.product,
          sku: 'PRN-1',
          unit: 'pcs',
          trackInventory: true,
          stockQuantity: 5,
          reorderLevel: 10,
        ),
      ).toMap();

      expect(tracked, containsPair('trackInventory', true));
      expect(tracked, containsPair('stockQuantity', 5));
      expect(tracked, containsPair('reorderLevel', 10));
    });

    test('marks tracked products low stock only at or below reorder level', () {
      expect(
        ProductService.empty()
            .copyWith(trackInventory: true, stockQuantity: 5, reorderLevel: 5)
            .isLowStock,
        isTrue,
      );
      expect(
        ProductService.empty()
            .copyWith(trackInventory: true, stockQuantity: 6, reorderLevel: 5)
            .isLowStock,
        isFalse,
      );
      expect(
        ProductService.empty()
            .copyWith(stockQuantity: 0, reorderLevel: 5)
            .isLowStock,
        isFalse,
      );
    });
  });
}
