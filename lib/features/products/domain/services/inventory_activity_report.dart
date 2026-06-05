import '../entities/product_inventory_entry.dart';
import '../entities/product_service.dart';

class InventoryActivityReport {
  const InventoryActivityReport({
    required this.rows,
    required this.trackedProductCount,
    required this.lowStockCount,
    required this.movementCount,
    required this.manualAdjustmentCount,
    required this.totalStockValue,
    required this.totalRecommendedRestockQuantity,
    required this.reasonBreakdown,
  });

  final List<InventoryActivityRow> rows;
  final int trackedProductCount;
  final int lowStockCount;
  final int movementCount;
  final int manualAdjustmentCount;
  final double totalStockValue;
  final double totalRecommendedRestockQuantity;
  final List<InventoryReasonSummary> reasonBreakdown;
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

class InventoryReasonSummary {
  const InventoryReasonSummary({
    required this.reason,
    required this.count,
    required this.netQuantityDelta,
  });

  final String reason;
  final int count;
  final double netQuantityDelta;
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
              entry.secondaryReference,
              entry.supplierName,
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

  final reasonMap = <String, InventoryReasonSummary>{};
  for (final row in rows) {
    final reason = row.entry.reason.trim().isEmpty
        ? row.entry.type.label
        : row.entry.reason.trim();
    final previous = reasonMap[reason];
    reasonMap[reason] = InventoryReasonSummary(
      reason: reason,
      count: (previous?.count ?? 0) + 1,
      netQuantityDelta: _roundQuantity(
        (previous?.netQuantityDelta ?? 0) + row.entry.quantityDelta,
      ),
    );
  }
  final reasonBreakdown = reasonMap.values.toList()
    ..sort((a, b) {
      final countCompare = b.count.compareTo(a.count);
      if (countCompare != 0) return countCompare;
      return a.reason.compareTo(b.reason);
    });

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
    totalStockValue: _roundQuantity(
      trackedProducts.fold<double>(
        0,
        (sum, product) => sum + product.stockValue,
      ),
    ),
    totalRecommendedRestockQuantity: _roundQuantity(
      trackedProducts.fold<double>(
        0,
        (sum, product) => sum + product.recommendedRestockQuantity,
      ),
    ),
    reasonBreakdown: reasonBreakdown,
  );
}

String buildInventoryActivityCsv(InventoryActivityReport report) {
  final buffer = StringBuffer()
    ..writeln(
      'Product,SKU,Type,Reference,Bill Reference,Supplier,Reason,Note,Date,Delta,Unit Cost,Total Cost,Balance',
    );

  for (final row in report.rows) {
    buffer.writeln(
      [
        row.productName,
        row.sku,
        row.entry.type.label,
        row.entry.reference,
        row.entry.secondaryReference,
        row.entry.supplierName,
        row.entry.reason,
        row.entry.note,
        row.entry.createdAt.toIso8601String(),
        row.entry.quantityDelta.toStringAsFixed(2),
        row.entry.unitCost.toStringAsFixed(2),
        row.entry.totalCost.toStringAsFixed(2),
        row.entry.balanceAfter.toStringAsFixed(2),
      ].map(_csvCell).join(','),
    );
  }

  buffer
    ..writeln()
    ..writeln('Summary,Value')
    ..writeln('Tracked Products,${report.trackedProductCount}')
    ..writeln('Low Stock,${report.lowStockCount}')
    ..writeln('Movements,${report.movementCount}')
    ..writeln('Manual Adjustments,${report.manualAdjustmentCount}')
    ..writeln('Inventory Value,${report.totalStockValue.toStringAsFixed(2)}')
    ..writeln(
      'Recommended Restock Qty,${report.totalRecommendedRestockQuantity.toStringAsFixed(2)}',
    )
    ..writeln()
    ..writeln('Reason,Count,Net Delta');

  for (final summary in report.reasonBreakdown) {
    buffer.writeln(
      [
        summary.reason,
        summary.count.toString(),
        summary.netQuantityDelta.toStringAsFixed(2),
      ].map(_csvCell).join(','),
    );
  }

  return buffer.toString();
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  if (escaped.contains(',') ||
      escaped.contains('"') ||
      escaped.contains('\n')) {
    return '"$escaped"';
  }
  return escaped;
}

double _roundQuantity(double value) {
  return double.parse(value.toStringAsFixed(4));
}
