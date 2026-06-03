import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/product_service_model.dart';
import 'package:invo_print/features/products/data/repositories/product_repository.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('ProductRepository', () {
    test('fetches active products sorted by updated date descending', () async {
      final older = _product(id: 'older', updatedAt: DateTime(2026, 5, 1));
      final newer = _product(id: 'newer', updatedAt: DateTime(2026, 5, 3));
      final inactive = _product(
        id: 'inactive',
        updatedAt: DateTime(2026, 5, 4),
        isActive: false,
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'products/older': ProductServiceModel.fromEntity(older).toMap(),
        'products/newer': ProductServiceModel.fromEntity(newer).toMap(),
        'products/inactive': ProductServiceModel.fromEntity(inactive).toMap(),
      });

      final products = await ProductRepository(firestore).fetchProducts();

      expect(products.map((product) => product.id), ['newer', 'older']);
    });

    test('saves tracked inventory fields', () async {
      final firestore = FakeCustomerFirestoreRestClient();
      final repository = ProductRepository(firestore);

      await repository.saveProduct(
        _product(
          id: '',
          type: ProductServiceType.product,
          sku: 'PRN-001',
          unit: 'pcs',
          trackInventory: true,
          stockQuantity: 12,
          reorderLevel: 4,
        ),
      );

      final saved = firestore.documents.entries.single;
      expect(saved.key, startsWith('products/prod_'));
      expect(saved.value, containsPair('sku', 'PRN-001'));
      expect(saved.value, containsPair('trackInventory', true));
      expect(saved.value, containsPair('stockQuantity', 12));
      expect(saved.value, containsPair('reorderLevel', 4));
    });

    test('archives product without losing inventory data', () async {
      final product = _product(
        id: 'prod_1',
        trackInventory: true,
        stockQuantity: 3,
        reorderLevel: 5,
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'products/prod_1': ProductServiceModel.fromEntity(product).toMap(),
      });

      await ProductRepository(firestore).archiveProduct(product);

      final archived = firestore.documents['products/prod_1']!;
      expect(archived, containsPair('isActive', false));
      expect(archived, containsPair('trackInventory', true));
      expect(archived, containsPair('stockQuantity', 3));
      expect(archived, containsPair('reorderLevel', 5));
    });
  });
}

ProductService _product({
  String id = 'prod_1',
  ProductServiceType type = ProductServiceType.service,
  String sku = '',
  String unit = 'service',
  bool trackInventory = false,
  double stockQuantity = 0,
  double reorderLevel = 0,
  bool isActive = true,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 5, 1);
  return ProductService(
    id: id,
    name: 'Thermal Printer',
    description: '',
    type: type,
    sku: sku,
    unit: unit,
    defaultRate: 2500,
    hsnSac: '8443',
    gstRate: 18,
    trackInventory: trackInventory,
    stockQuantity: stockQuantity,
    reorderLevel: reorderLevel,
    isActive: isActive,
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}
