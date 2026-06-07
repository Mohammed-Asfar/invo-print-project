import '../../../products/domain/entities/product_service.dart';

class InventoryValuationReport {
  const InventoryValuationReport({
    required this.rows,
    required this.productCount,
    required this.lowStockCount,
    required this.totalQuantity,
    required this.totalValue,
    required this.restockValue,
  });

  final List<InventoryValuationRow> rows;
  final int productCount;
  final int lowStockCount;
  final double totalQuantity;
  final double totalValue;
  final double restockValue;
}

class InventoryValuationRow {
  const InventoryValuationRow({
    required this.productId,
    required this.name,
    required this.sku,
    required this.unit,
    required this.quantity,
    required this.costPrice,
    required this.stockValue,
    required this.reorderLevel,
    required this.lowStock,
    required this.restockQuantity,
    required this.restockValue,
  });

  final String productId;
  final String name;
  final String sku;
  final String unit;
  final double quantity;
  final double costPrice;
  final double stockValue;
  final double reorderLevel;
  final bool lowStock;
  final double restockQuantity;
  final double restockValue;
}

InventoryValuationReport buildInventoryValuationReport({
  required Iterable<ProductService> products,
}) {
  final rows =
      products
          .where((product) => product.isActive && product.trackInventory)
          .map(
            (product) => InventoryValuationRow(
              productId: product.id,
              name: product.name,
              sku: product.sku,
              unit: product.unit,
              quantity: product.stockQuantity,
              costPrice: product.costPrice,
              stockValue: _money(product.stockValue),
              reorderLevel: product.reorderLevel,
              lowStock: product.isLowStock,
              restockQuantity: product.recommendedRestockQuantity,
              restockValue: _money(
                product.recommendedRestockQuantity * product.costPrice,
              ),
            ),
          )
          .toList()
        ..sort((a, b) {
          final valueCompare = b.stockValue.compareTo(a.stockValue);
          if (valueCompare != 0) return valueCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

  return InventoryValuationReport(
    rows: rows,
    productCount: rows.length,
    lowStockCount: rows.where((row) => row.lowStock).length,
    totalQuantity: _money(
      rows.fold<double>(0, (sum, row) => sum + row.quantity),
    ),
    totalValue: _money(
      rows.fold<double>(0, (sum, row) => sum + row.stockValue),
    ),
    restockValue: _money(
      rows.fold<double>(0, (sum, row) => sum + row.restockValue),
    ),
  );
}

String buildInventoryValuationCsv(InventoryValuationReport report) {
  final rows = [
    [
      'Product',
      'SKU',
      'Unit',
      'Quantity',
      'Cost Price',
      'Stock Value',
      'Reorder Level',
      'Low Stock',
      'Restock Quantity',
      'Restock Value',
    ],
    for (final row in report.rows)
      [
        row.name,
        row.sku,
        row.unit,
        _formatNumber(row.quantity),
        _formatMoney(row.costPrice),
        _formatMoney(row.stockValue),
        _formatNumber(row.reorderLevel),
        row.lowStock ? 'Yes' : 'No',
        _formatNumber(row.restockQuantity),
        _formatMoney(row.restockValue),
      ],
    [],
    ['Summary'],
    ['Products', report.productCount.toString()],
    ['Low Stock Products', report.lowStockCount.toString()],
    ['Total Quantity', _formatNumber(report.totalQuantity)],
    ['Total Value', _formatMoney(report.totalValue)],
    ['Restock Value', _formatMoney(report.restockValue)],
  ];

  return rows
      .map((row) => row.map((cell) => _csvCell(cell.toString())).join(','))
      .join('\n');
}

String _csvCell(String value) {
  if (!value.contains(',') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}

String _formatMoney(double value) => value.toStringAsFixed(2);

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

double _money(double value) => double.parse(value.toStringAsFixed(2));
