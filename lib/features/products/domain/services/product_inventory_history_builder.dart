import '../entities/product_inventory_entry.dart';
import '../entities/product_service.dart';

List<ProductInventoryEntry> buildInventoryEntries({
  required Map<String, double> quantityDeltas,
  required List<ProductService> products,
  required ProductInventoryEntryType type,
  required DateTime createdAt,
  String reference = '',
  String reason = '',
  String note = '',
}) {
  final productsById = {for (final product in products) product.id: product};
  final entries = <ProductInventoryEntry>[];

  for (final entry in quantityDeltas.entries) {
    if (entry.value == 0) continue;
    final product = productsById[entry.key];
    if (product == null) continue;
    entries.add(
      ProductInventoryEntry(
        id: 'stock_${createdAt.microsecondsSinceEpoch}_${entry.key}',
        productId: entry.key,
        type: type,
        quantityDelta: entry.value,
        balanceAfter: product.stockQuantity,
        createdAt: createdAt,
        reference: reference,
        reason: reason,
        note: note,
      ),
    );
  }

  return entries;
}
