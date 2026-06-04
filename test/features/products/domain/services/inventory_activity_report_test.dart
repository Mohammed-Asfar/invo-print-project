import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/domain/entities/product_inventory_entry.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';
import 'package:invo_print/features/products/domain/services/inventory_activity_report.dart';

void main() {
  group('buildInventoryActivityReport', () {
    test('builds metrics from tracked products and all movements', () {
      final report = buildInventoryActivityReport(
        products: [
          _product(id: 'prod_1', stockQuantity: 2, reorderLevel: 3),
          _product(id: 'prod_2', stockQuantity: 8, reorderLevel: 2),
          _product(
            id: 'svc_1',
            trackInventory: false,
            type: ProductServiceType.service,
          ),
        ],
        entries: [
          _entry(id: 'one', productId: 'prod_1'),
          _entry(
            id: 'two',
            productId: 'prod_2',
            type: ProductInventoryEntryType.invoiceIssued,
          ),
        ],
      );

      expect(report.trackedProductCount, 2);
      expect(report.lowStockCount, 1);
      expect(report.movementCount, 2);
      expect(report.manualAdjustmentCount, 1);
    });

    test('filters by product type and search query', () {
      final report = buildInventoryActivityReport(
        products: [
          _product(id: 'prod_1', name: 'Thermal Printer', sku: 'PRN-1'),
          _product(id: 'prod_2', name: 'Barcode Scanner', sku: 'SCN-1'),
        ],
        entries: [
          _entry(
            id: 'older',
            productId: 'prod_1',
            createdAt: DateTime(2026, 6, 3),
            reason: 'Purchase',
          ),
          _entry(
            id: 'newer',
            productId: 'prod_2',
            type: ProductInventoryEntryType.invoiceIssued,
            createdAt: DateTime(2026, 6, 4),
            reference: 'INV-001',
          ),
        ],
        productId: 'prod_2',
        type: ProductInventoryEntryType.invoiceIssued,
        searchQuery: 'inv-001',
      );

      expect(report.rows, hasLength(1));
      expect(report.rows.single.entry.id, 'newer');
      expect(report.rows.single.productName, 'Barcode Scanner');
    });

    test('keeps newest rows first and labels missing products', () {
      final report = buildInventoryActivityReport(
        products: [_product(id: 'prod_1')],
        entries: [
          _entry(
            id: 'older',
            productId: 'missing',
            createdAt: DateTime(2026, 6, 3),
          ),
          _entry(
            id: 'newer',
            productId: 'prod_1',
            createdAt: DateTime(2026, 6, 4),
          ),
        ],
      );

      expect(report.rows.map((row) => row.entry.id), ['newer', 'older']);
      expect(report.rows.last.productName, 'Unknown item');
    });
  });
}

ProductService _product({
  required String id,
  String name = 'Thermal Printer',
  String sku = 'PRN-1',
  ProductServiceType type = ProductServiceType.product,
  bool trackInventory = true,
  double stockQuantity = 5,
  double reorderLevel = 2,
}) {
  final now = DateTime(2026, 6, 4);
  return ProductService(
    id: id,
    name: name,
    description: '',
    type: type,
    sku: sku,
    unit: 'pcs',
    defaultRate: 2500,
    hsnSac: '8443',
    gstRate: 18,
    trackInventory: trackInventory,
    stockQuantity: stockQuantity,
    reorderLevel: reorderLevel,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

ProductInventoryEntry _entry({
  required String id,
  required String productId,
  ProductInventoryEntryType type = ProductInventoryEntryType.manualAdjustment,
  DateTime? createdAt,
  String reference = '',
  String reason = '',
}) {
  return ProductInventoryEntry(
    id: id,
    productId: productId,
    type: type,
    quantityDelta: 1,
    balanceAfter: 5,
    createdAt: createdAt ?? DateTime(2026, 6, 4),
    reference: reference,
    reason: reason,
  );
}
