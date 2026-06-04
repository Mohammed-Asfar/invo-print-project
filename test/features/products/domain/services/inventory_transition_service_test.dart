import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/core/errors/app_exception.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';
import 'package:invo_print/features/products/domain/services/inventory_transition_service.dart';

void main() {
  group('InventoryTransitionService', () {
    const service = InventoryTransitionService();

    test('consumes tracked product stock for final invoices', () {
      final result = service.applyInvoiceTransition(
        products: [_product(stockQuantity: 10)],
        previousItems: const [],
        previousStatus: InvoiceStatus.draft,
        nextItems: [_item(productId: 'prod_1', quantity: 3)],
        nextStatus: InvoiceStatus.unpaid,
      );

      expect(result.updatedProductIds, {'prod_1'});
      expect(result.products.single.stockQuantity, 7);
    });

    test('ignores drafts and services without inventory tracking', () {
      final result = service.applyInvoiceTransition(
        products: [
          _product(type: ProductServiceType.service, trackInventory: false),
        ],
        previousItems: const [],
        previousStatus: InvoiceStatus.draft,
        nextItems: [_item(productId: 'prod_1', quantity: 3)],
        nextStatus: InvoiceStatus.draft,
      );

      expect(result.updatedProductIds, isEmpty);
      expect(result.products.single.stockQuantity, 10);
    });

    test('applies net delta when editing an already final invoice', () {
      final result = service.applyInvoiceTransition(
        products: [_product(stockQuantity: 5)],
        previousItems: [_item(productId: 'prod_1', quantity: 2)],
        previousStatus: InvoiceStatus.unpaid,
        nextItems: [_item(productId: 'prod_1', quantity: 4)],
        nextStatus: InvoiceStatus.partialPaid,
      );

      expect(result.products.single.stockQuantity, 3);
    });

    test('restores stock when final invoice is cancelled or archived', () {
      final result = service.applyInvoiceTransition(
        products: [_product(stockQuantity: 1)],
        previousItems: [_item(productId: 'prod_1', quantity: 2)],
        previousStatus: InvoiceStatus.unpaid,
        nextItems: const [],
        nextStatus: InvoiceStatus.cancelled,
      );

      expect(result.products.single.stockQuantity, 3);
    });

    test('rejects insufficient stock', () {
      expect(
        () => service.applyInvoiceTransition(
          products: [_product(stockQuantity: 1)],
          previousItems: const [],
          previousStatus: InvoiceStatus.draft,
          nextItems: [_item(productId: 'prod_1', quantity: 2)],
          nextStatus: InvoiceStatus.unpaid,
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            contains('Not enough stock'),
          ),
        ),
      );
    });

    test('rejects missing referenced product', () {
      expect(
        () => service.applyInvoiceTransition(
          products: const [],
          previousItems: const [],
          previousStatus: InvoiceStatus.draft,
          nextItems: [_item(productId: 'missing', quantity: 1)],
          nextStatus: InvoiceStatus.unpaid,
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            contains('no longer exists'),
          ),
        ),
      );
    });
  });
}

ProductService _product({
  ProductServiceType type = ProductServiceType.product,
  bool trackInventory = true,
  double stockQuantity = 10,
}) {
  final now = DateTime(2026, 6, 4);
  return ProductService(
    id: 'prod_1',
    name: 'Thermal Printer',
    description: '',
    type: type,
    sku: 'PRN-1',
    unit: 'pcs',
    defaultRate: 2500,
    hsnSac: '8443',
    gstRate: 18,
    trackInventory: trackInventory,
    costPrice: 0,
    stockQuantity: stockQuantity,
    reorderLevel: 2,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

InvoiceItem _item({required String productId, required double quantity}) {
  return InvoiceItem.empty().copyWith(
    productId: productId,
    name: 'Thermal Printer',
    quantity: quantity,
    unit: 'pcs',
    rate: 2500,
  );
}
