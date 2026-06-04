import '../../../../core/errors/app_exception.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/entities/invoice_item.dart';
import '../entities/product_service.dart';

class InventoryTransitionResult {
  const InventoryTransitionResult({
    required this.products,
    required this.updatedProductIds,
  });

  final List<ProductService> products;
  final Set<String> updatedProductIds;
}

class InventoryTransitionService {
  const InventoryTransitionService();

  InventoryTransitionResult applyInvoiceTransition({
    required List<ProductService> products,
    required List<InvoiceItem> previousItems,
    required InvoiceStatus previousStatus,
    required List<InvoiceItem> nextItems,
    required InvoiceStatus nextStatus,
  }) {
    final deltas = <String, double>{};
    final productsById = {for (final product in products) product.id: product};

    _applyItemDeltas(
      deltas: deltas,
      productsById: productsById,
      items: previousItems,
      status: previousStatus,
      multiplier: 1,
    );
    _applyItemDeltas(
      deltas: deltas,
      productsById: productsById,
      items: nextItems,
      status: nextStatus,
      multiplier: -1,
    );

    if (deltas.isEmpty) {
      return InventoryTransitionResult(
        products: products,
        updatedProductIds: const {},
      );
    }

    final updatedProductIds = <String>{};
    final updatedProducts = [
      for (final product in products)
        if (deltas.containsKey(product.id))
          _updatedProduct(
            product: product,
            delta: deltas[product.id]!,
            updatedProductIds: updatedProductIds,
          )
        else
          product,
    ];

    return InventoryTransitionResult(
      products: updatedProducts,
      updatedProductIds: updatedProductIds,
    );
  }

  void _applyItemDeltas({
    required Map<String, double> deltas,
    required Map<String, ProductService> productsById,
    required List<InvoiceItem> items,
    required InvoiceStatus status,
    required int multiplier,
  }) {
    if (!_countsForInventory(status)) return;

    for (final item in items) {
      if (item.productId.trim().isEmpty || item.quantity <= 0) continue;
      final product = productsById[item.productId.trim()];
      if (product == null) {
        throw AppException(
          'Invoice item "${item.name}" is linked to a product that no longer exists.',
        );
      }
      if (!_tracksInventory(product)) continue;
      deltas.update(
        product.id,
        (value) => _roundQuantity(value + (item.quantity * multiplier)),
        ifAbsent: () => _roundQuantity(item.quantity * multiplier),
      );
    }
  }

  ProductService _updatedProduct({
    required ProductService product,
    required double delta,
    required Set<String> updatedProductIds,
  }) {
    if (delta == 0) return product;
    final nextStock = _roundQuantity(product.stockQuantity + delta);
    if (nextStock < 0) {
      final required = _roundQuantity(delta.abs());
      throw AppException(
        'Not enough stock for ${product.name}. Available: ${_formatQuantity(product.stockQuantity)} ${product.unit}, required: ${_formatQuantity(required)} ${product.unit}.',
      );
    }
    updatedProductIds.add(product.id);
    return product.copyWith(
      stockQuantity: nextStock,
      updatedAt: DateTime.now(),
    );
  }

  bool _countsForInventory(InvoiceStatus status) {
    return status != InvoiceStatus.draft && status != InvoiceStatus.cancelled;
  }

  bool _tracksInventory(ProductService product) {
    return product.trackInventory && product.type == ProductServiceType.product;
  }

  double _roundQuantity(double value) {
    return double.parse(value.toStringAsFixed(4));
  }

  String _formatQuantity(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}
