import '../entities/product_inventory_entry.dart';
import '../entities/product_service.dart';

class InventoryActivityReport {
  const InventoryActivityReport({
    required this.rows,
    required this.trackedProductCount,
    required this.lowStockCount,
    required this.movementCount,
    required this.manualAdjustmentCount,
  });

  final List<InventoryActivityRow> rows;
  final int trackedProductCount;
  final int lowStockCount;
  final int movementCount;
  final int manualAdjustmentCount;
}

class InventoryActivityRow {
  const InventoryActivityRow({
    required this.entry,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.isLowStock,
  });

  final ProductInventoryEntry entry;
  final String productName;
  final String sku;
  final String unit;
  final bool isLowStock;
}

InventoryActivityReport buildInventoryActivityReport({
  required List<ProductService> products,
  required List<ProductInventoryEntry> entries,
  String productId = '',
  ProductInventoryEntryType? type,
  String searchQuery = '',
}) {
  final trackedProducts = products.where((product) => product.trackInventory);
  final productsById = {for (final product in products) product.id: product};
  final normalizedProductId = productId.trim();
  final normalizedQuery = searchQuery.trim().toLowerCase();

  final rows =
      entries
          .where((entry) {
            if (normalizedProductId.isNotEmpty &&
                entry.productId != normalizedProductId) {
              return false;
            }
            if (type != null && entry.type != type) {
              return false;
            }
            if (normalizedQuery.isEmpty) {
              return true;
            }
            final product = productsById[entry.productId];
            final haystack = [
              product?.name ?? 'Unknown item',
              product?.sku ?? '',
              entry.type.label,
              entry.reference,
              entry.reason,
              entry.note,
            ].join(' ').toLowerCase();
            return haystack.contains(normalizedQuery);
          })
          .map((entry) {
            final product = productsById[entry.productId];
            return InventoryActivityRow(
              entry: entry,
              productName: product?.name ?? 'Unknown item',
              sku: product?.sku ?? '',
              unit: product?.unit ?? '',
              isLowStock: product?.isLowStock ?? false,
            );
          })
          .toList()
        ..sort((a, b) => b.entry.createdAt.compareTo(a.entry.createdAt));

  return InventoryActivityReport(
    rows: rows,
    trackedProductCount: trackedProducts.length,
    lowStockCount: trackedProducts
        .where((product) => product.isLowStock)
        .length,
    movementCount: entries.length,
    manualAdjustmentCount: entries
        .where(
          (entry) => entry.type == ProductInventoryEntryType.manualAdjustment,
        )
        .length,
  );
}
