import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/domain/entities/product_inventory_entry.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';
import 'package:invo_print/features/products/domain/services/inventory_activity_report.dart';

void main() {
  group('buildInventoryActivityReport', () {
    test('builds metrics from tracked products and all movements', () {
      final report = buildInventoryActivityReport(
        products: [
          _product(
            id: 'prod_1',
            stockQuantity: 2,
            reorderLevel: 3,
            costPrice: 12,
          ),
          _product(
            id: 'prod_2',
            stockQuantity: 8,
            reorderLevel: 2,
            costPrice: 7.5,
          ),
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
      expect(report.totalStockValue, 84);
      expect(report.totalRecommendedRestockQuantity, 1);
      expect(
        report.reasonBreakdown.map((summary) => summary.reason),
        containsAll(['Manual adjustment', 'Invoice issued']),
      );
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

    test('summarizes reason breakdown by count and net quantity', () {
      final report = buildInventoryActivityReport(
        products: [_product(id: 'prod_1')],
        entries: [
          _entry(id: 'one', productId: 'prod_1', reason: 'Purchase'),
          _entry(
            id: 'two',
            productId: 'prod_1',
            reason: 'Purchase',
            type: ProductInventoryEntryType.manualAdjustment,
          ),
          _entry(id: 'three', productId: 'prod_1', reason: 'Damage', delta: -2),
        ],
      );

      expect(report.reasonBreakdown, hasLength(2));
      expect(report.reasonBreakdown.first.reason, 'Purchase');
      expect(report.reasonBreakdown.first.count, 2);
      expect(report.reasonBreakdown.first.netQuantityDelta, 2);
      expect(report.reasonBreakdown.last.reason, 'Damage');
      expect(report.reasonBreakdown.last.netQuantityDelta, -2);
    });
  });

  group('buildInventoryActivityCsv', () {
    test('exports rows summary and reason breakdown with escaping', () {
      final report = buildInventoryActivityReport(
        products: [_product(id: 'prod_1', name: 'Printer, "A"')],
        entries: [
          _entry(
            id: 'one',
            productId: 'prod_1',
            reason: 'Purchase',
            note: 'Batch\n1',
          ),
        ],
      );

      final csv = buildInventoryActivityCsv(report);

      expect(csv, contains('"Printer, ""A"""'));
      expect(csv, contains('"Batch\n1"'));
      expect(csv, contains('Summary,Value'));
      expect(csv, contains('Inventory Value,25.00'));
      expect(csv, contains('Recommended Restock Qty,0.00'));
      expect(csv, contains('Reason,Count,Net Delta'));
      expect(csv, contains('Purchase,1,1.00'));
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
  double costPrice = 5,
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
    costPrice: costPrice,
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
  String note = '',
  double delta = 1,
}) {
  return ProductInventoryEntry(
    id: id,
    productId: productId,
    type: type,
    quantityDelta: delta,
    balanceAfter: 5,
    createdAt: createdAt ?? DateTime(2026, 6, 4),
    reference: reference,
    reason: reason,
    note: note,
  );
}
