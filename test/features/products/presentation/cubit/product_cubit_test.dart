import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/product_inventory_entry_model.dart';
import 'package:invo_print/features/products/data/models/purchase_entry_model.dart';
import 'package:invo_print/features/products/data/models/product_service_model.dart';
import 'package:invo_print/features/products/data/repositories/product_inventory_repository.dart';
import 'package:invo_print/features/products/data/repositories/product_repository.dart';
import 'package:invo_print/features/products/data/repositories/purchase_entry_repository.dart';
import 'package:invo_print/features/products/data/repositories/supplier_repository.dart';
import 'package:invo_print/features/products/domain/entities/product_inventory_entry.dart';
import 'package:invo_print/features/products/domain/entities/purchase_entry.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';
import 'package:invo_print/features/products/domain/entities/supplier.dart';
import 'package:invo_print/features/products/presentation/cubit/product_cubit.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('ProductCubit', () {
    test('adjustStock saves product stock and history entry', () async {
      final product = _product(stockQuantity: 5);
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
      });
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
        PurchaseEntryRepository(firestore),
        SupplierRepository(firestore),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.adjustStock(
        product,
        quantityDelta: 3,
        reason: 'Physical count',
        note: 'Restocked',
      );

      expect(cubit.state.status, ProductStatus.saved);
      expect(cubit.state.products.single.stockQuantity, 8);

      final historyEntry = ProductInventoryEntryModel.fromMap(
        firestore.documents.entries
            .singleWhere(
              (entry) => entry.key.startsWith('product_inventory_entries/'),
            )
            .key
            .split('/')
            .last,
        firestore.documents.entries
            .singleWhere(
              (entry) => entry.key.startsWith('product_inventory_entries/'),
            )
            .value,
      );
      expect(historyEntry.type, ProductInventoryEntryType.manualAdjustment);
      expect(historyEntry.quantityDelta, 3);
      expect(historyEntry.balanceAfter, 8);
      expect(historyEntry.reason, 'Physical count');
      expect(historyEntry.note, 'Restocked');
    });

    test(
      'adjustStock stores restock metadata and updates cost price',
      () async {
        final product = _product(stockQuantity: 5);
        final firestore = FakeCustomerFirestoreRestClient({
          'products/${product.id}': ProductServiceModel.fromEntity(
            product,
          ).toMap(),
        });
        final cubit = ProductCubit(
          ProductRepository(firestore),
          ProductInventoryRepository(firestore),
          PurchaseEntryRepository(firestore),
          SupplierRepository(firestore),
        );
        addTearDown(cubit.close);

        final effectiveAt = DateTime(2026, 6, 5, 14, 30);

        await cubit.load();
        await cubit.adjustStock(
          product,
          quantityDelta: 4,
          reason: 'Purchase',
          effectiveAt: effectiveAt,
          reference: 'RST-20260605',
          secondaryReference: 'BILL-77',
          supplierName: 'Supply Hub',
          unitCost: 1700,
          updateCostPriceFromUnitCost: true,
          note: 'June restock',
        );

        expect(cubit.state.status, ProductStatus.saved);
        final updatedProduct = cubit.state.products.single;
        expect(updatedProduct.stockQuantity, 9);
        expect(updatedProduct.costPrice, 1700);

        final historyEntry = ProductInventoryEntryModel.fromMap(
          firestore.documents.entries
              .singleWhere(
                (entry) => entry.key.startsWith('product_inventory_entries/'),
              )
              .key
              .split('/')
              .last,
          firestore.documents.entries
              .singleWhere(
                (entry) => entry.key.startsWith('product_inventory_entries/'),
              )
              .value,
        );
        expect(historyEntry.reference, 'RST-20260605');
        expect(historyEntry.secondaryReference, 'BILL-77');
        expect(historyEntry.supplierName, 'Supply Hub');
        expect(historyEntry.unitCost, 1700);
        expect(historyEntry.totalCost, 6800);
        expect(historyEntry.createdAt, effectiveAt);
        expect(historyEntry.note, 'June restock');
      },
    );

    test(
      'adjustStock rejects changes that would send stock below zero',
      () async {
        final product = _product(stockQuantity: 2);
        final firestore = FakeCustomerFirestoreRestClient({
          'products/${product.id}': ProductServiceModel.fromEntity(
            product,
          ).toMap(),
        });
        final cubit = ProductCubit(
          ProductRepository(firestore),
          ProductInventoryRepository(firestore),
          PurchaseEntryRepository(firestore),
          SupplierRepository(firestore),
        );
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.adjustStock(product, quantityDelta: -3, reason: 'Damage');

        expect(cubit.state.status, ProductStatus.failure);
        expect(cubit.state.message, contains('below zero'));
        expect(
          firestore.documents.keys.where(
            (key) => key.startsWith('product_inventory_entries/'),
          ),
          isEmpty,
        );
      },
    );

    test('loadInventoryEntries returns saved history newest first', () async {
      final product = _product();
      final older = ProductInventoryEntry(
        id: 'stock_older',
        productId: product.id,
        type: ProductInventoryEntryType.invoiceIssued,
        quantityDelta: -1,
        balanceAfter: 9,
        createdAt: DateTime(2026, 6, 3),
      );
      final newer = ProductInventoryEntry(
        id: 'stock_newer',
        productId: product.id,
        type: ProductInventoryEntryType.invoiceUpdated,
        quantityDelta: -2,
        balanceAfter: 7,
        createdAt: DateTime(2026, 6, 4),
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
        'product_inventory_entries/${older.id}':
            ProductInventoryEntryModel.fromEntity(older).toMap(),
        'product_inventory_entries/${newer.id}':
            ProductInventoryEntryModel.fromEntity(newer).toMap(),
      });
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
        PurchaseEntryRepository(firestore),
        SupplierRepository(firestore),
      );
      addTearDown(cubit.close);

      final entries = await cubit.loadInventoryEntries(product.id);

      expect(entries.map((entry) => entry.id), ['stock_newer', 'stock_older']);
    });

    test('saveSupplier stores supplier and updates filtered results', () async {
      final firestore = FakeCustomerFirestoreRestClient();
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
        PurchaseEntryRepository(firestore),
        SupplierRepository(firestore),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.saveSupplier(
        Supplier(
          id: '',
          name: 'Supply Hub',
          phone: '9876543210',
          email: 'hello@supplyhub.test',
          gstin: '33ABCDE1234F1Z5',
          address: 'No. 12 Market Road',
          notes: 'Preferred vendor',
          isActive: true,
          createdAt: DateTime(2026, 6, 5),
          updatedAt: DateTime(2026, 6, 5),
        ),
      );

      expect(cubit.state.status, ProductStatus.saved);
      expect(cubit.state.suppliers, hasLength(1));
      expect(cubit.state.suppliers.single.name, 'Supply Hub');

      cubit.searchSuppliers('preferred');
      expect(cubit.state.filteredSuppliers, hasLength(1));
      expect(cubit.state.filteredSuppliers.single.gstin, '33ABCDE1234F1Z5');
    });

    test(
      'savePurchaseEntry stores purchase, stock movement, and updated product cost',
      () async {
        final product = _product(stockQuantity: 5, costPrice: 1800);
        final firestore = FakeCustomerFirestoreRestClient({
          'products/${product.id}': ProductServiceModel.fromEntity(
            product,
          ).toMap(),
        });
        final cubit = ProductCubit(
          ProductRepository(firestore),
          ProductInventoryRepository(firestore),
          PurchaseEntryRepository(firestore),
          SupplierRepository(firestore),
        );
        addTearDown(cubit.close);

        await cubit.load();
        await cubit.savePurchaseEntry(
          PurchaseEntry(
            id: '',
            entryNumber: 'PUR-202606-001',
            supplierId: 'sup_1',
            supplierName: 'Supply Hub',
            billReference: 'BILL-44',
            purchaseDate: DateTime(2026, 6, 5),
            items: const [
              PurchaseEntryItem(
                productId: 'prod_1',
                productName: 'Thermal Printer',
                sku: 'PRN-1',
                unit: 'pcs',
                quantity: 3,
                unitCost: 2000,
                lineTotal: 6000,
              ),
            ],
            notes: 'Monthly restock',
            totalAmount: 6000,
            amountPaid: 0,
            paymentHistory: const [],
            status: PurchasePaymentStatus.unpaid,
            isActive: true,
            createdAt: DateTime(2026, 6, 5),
            updatedAt: DateTime(2026, 6, 5),
          ),
        );

        expect(cubit.state.status, ProductStatus.saved);
        expect(cubit.state.products.single.stockQuantity, 8);
        expect(cubit.state.products.single.costPrice, 2000);
        expect(cubit.state.purchaseEntries, hasLength(1));
        expect(cubit.state.purchaseEntries.single.supplierName, 'Supply Hub');

        final inventoryEntry = ProductInventoryEntryModel.fromMap(
          firestore.documents.entries
              .singleWhere(
                (entry) => entry.key.startsWith('product_inventory_entries/'),
              )
              .key
              .split('/')
              .last,
          firestore.documents.entries
              .singleWhere(
                (entry) => entry.key.startsWith('product_inventory_entries/'),
              )
              .value,
        );
        expect(inventoryEntry.type, ProductInventoryEntryType.purchaseReceived);
        expect(inventoryEntry.reference, 'PUR-202606-001');
        expect(inventoryEntry.secondaryReference, 'BILL-44');

        final purchaseDoc = firestore.documents.entries.singleWhere(
          (entry) => entry.key.startsWith('purchase_entries/'),
        );
        final purchaseEntry = PurchaseEntryModel.fromMap(
          purchaseDoc.key.split('/').last,
          purchaseDoc.value,
        );
        expect(purchaseEntry.totalAmount, 6000);
        expect(purchaseEntry.status, PurchasePaymentStatus.unpaid);
        expect(purchaseEntry.items.single.quantity, 3);
      },
    );

    test('recordPurchasePayment updates paid amount and status', () async {
      final purchaseDate = DateTime(2026, 6, 5);
      final entry = PurchaseEntry(
        id: 'pur_1',
        entryNumber: 'PUR-202606-001',
        supplierId: 'sup_1',
        supplierName: 'Supply Hub',
        billReference: 'BILL-44',
        purchaseDate: purchaseDate,
        items: const [
          PurchaseEntryItem(
            productId: 'prod_1',
            productName: 'Thermal Printer',
            sku: 'PRN-1',
            unit: 'pcs',
            quantity: 3,
            unitCost: 2000,
            lineTotal: 6000,
          ),
        ],
        notes: 'Monthly restock',
        totalAmount: 6000,
        amountPaid: 1000,
        paymentHistory: [
          PurchasePayment(
            amount: 1000,
            paidAt: DateTime(2026, 6, 5),
            method: 'Cash',
            reference: 'PAY-1',
          ),
        ],
        status: PurchasePaymentStatus.partial,
        isActive: true,
        createdAt: purchaseDate,
        updatedAt: purchaseDate,
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'purchase_entries/${entry.id}': PurchaseEntryModel.fromEntity(
          entry,
        ).toMap(),
      });
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
        PurchaseEntryRepository(firestore),
        SupplierRepository(firestore),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.recordPurchasePayment(
        entry,
        amount: 5500,
        paidAt: DateTime(2026, 6, 6),
        method: 'Bank transfer',
        reference: 'PAY-2',
        notes: 'Settled in full',
      );

      expect(cubit.state.status, ProductStatus.saved);
      expect(cubit.state.purchaseEntries, hasLength(1));
      final updated = cubit.state.purchaseEntries.single;
      expect(updated.amountPaid, 6000);
      expect(updated.balanceDue, 0);
      expect(updated.status, PurchasePaymentStatus.paid);
      expect(updated.paymentHistory, hasLength(2));
      expect(updated.paymentHistory.last.reference, 'PAY-2');
    });

    test('recordPurchasePayment rejects fully paid bills', () async {
      final purchaseDate = DateTime(2026, 6, 5);
      final entry = PurchaseEntry(
        id: 'pur_1',
        entryNumber: 'PUR-202606-001',
        supplierId: 'sup_1',
        supplierName: 'Supply Hub',
        billReference: 'BILL-44',
        purchaseDate: purchaseDate,
        items: const [],
        notes: '',
        totalAmount: 2000,
        amountPaid: 2000,
        paymentHistory: [
          PurchasePayment(amount: 2000, paidAt: DateTime(2026, 6, 5)),
        ],
        status: PurchasePaymentStatus.paid,
        isActive: true,
        createdAt: purchaseDate,
        updatedAt: purchaseDate,
      );
      final firestore = FakeCustomerFirestoreRestClient();
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
        PurchaseEntryRepository(firestore),
        SupplierRepository(firestore),
      );
      addTearDown(cubit.close);

      await cubit.recordPurchasePayment(
        entry,
        amount: 500,
        paidAt: DateTime(2026, 6, 6),
      );

      expect(cubit.state.status, ProductStatus.failure);
      expect(cubit.state.message, contains('already fully paid'));
    });

    test('updatePurchasePayment recalculates status and amount', () async {
      final purchaseDate = DateTime(2026, 6, 5);
      final entry = PurchaseEntry(
        id: 'pur_1',
        entryNumber: 'PUR-202606-001',
        supplierId: 'sup_1',
        supplierName: 'Supply Hub',
        billReference: 'BILL-44',
        purchaseDate: purchaseDate,
        items: const [],
        notes: '',
        totalAmount: 3000,
        amountPaid: 1000,
        paymentHistory: [
          PurchasePayment(amount: 1000, paidAt: DateTime(2026, 6, 5)),
        ],
        status: PurchasePaymentStatus.partial,
        isActive: true,
        createdAt: purchaseDate,
        updatedAt: purchaseDate,
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'purchase_entries/${entry.id}': PurchaseEntryModel.fromEntity(
          entry,
        ).toMap(),
      });
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
        PurchaseEntryRepository(firestore),
        SupplierRepository(firestore),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.updatePurchasePayment(
        entry,
        index: 0,
        amount: 3000,
        paidAt: DateTime(2026, 6, 5),
        method: 'Bank',
      );

      final updated = cubit.state.purchaseEntries.single;
      expect(updated.amountPaid, 3000);
      expect(updated.balanceDue, 0);
      expect(updated.status, PurchasePaymentStatus.paid);
      expect(updated.paymentHistory.single.method, 'Bank');
    });

    test('deletePurchasePayment can bring bill back to unpaid', () async {
      final purchaseDate = DateTime(2026, 6, 5);
      final entry = PurchaseEntry(
        id: 'pur_1',
        entryNumber: 'PUR-202606-001',
        supplierId: 'sup_1',
        supplierName: 'Supply Hub',
        billReference: 'BILL-44',
        purchaseDate: purchaseDate,
        items: const [],
        notes: '',
        totalAmount: 3000,
        amountPaid: 1000,
        paymentHistory: [
          PurchasePayment(amount: 1000, paidAt: DateTime(2026, 6, 5)),
        ],
        status: PurchasePaymentStatus.partial,
        isActive: true,
        createdAt: purchaseDate,
        updatedAt: purchaseDate,
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'purchase_entries/${entry.id}': PurchaseEntryModel.fromEntity(
          entry,
        ).toMap(),
      });
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
        PurchaseEntryRepository(firestore),
        SupplierRepository(firestore),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.deletePurchasePayment(entry, index: 0);

      final updated = cubit.state.purchaseEntries.single;
      expect(updated.amountPaid, 0);
      expect(updated.status, PurchasePaymentStatus.unpaid);
      expect(updated.paymentHistory, isEmpty);
    });

    test('voidPurchaseEntry reverses stock and archives the bill', () async {
      final product = _product(stockQuantity: 8, costPrice: 1800);
      final entry = PurchaseEntry(
        id: 'pur_1',
        entryNumber: 'PUR-202606-001',
        supplierId: 'sup_1',
        supplierName: 'Supply Hub',
        billReference: 'BILL-44',
        purchaseDate: DateTime(2026, 6, 5),
        items: const [
          PurchaseEntryItem(
            productId: 'prod_1',
            productName: 'Thermal Printer',
            sku: 'PRN-1',
            unit: 'pcs',
            quantity: 3,
            unitCost: 2000,
            lineTotal: 6000,
          ),
        ],
        notes: 'Mistaken duplicate',
        totalAmount: 6000,
        amountPaid: 0,
        paymentHistory: const [],
        status: PurchasePaymentStatus.unpaid,
        isActive: true,
        createdAt: DateTime(2026, 6, 5),
        updatedAt: DateTime(2026, 6, 5),
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'products/${product.id}': ProductServiceModel.fromEntity(
          product,
        ).toMap(),
        'purchase_entries/${entry.id}': PurchaseEntryModel.fromEntity(
          entry,
        ).toMap(),
      });
      final cubit = ProductCubit(
        ProductRepository(firestore),
        ProductInventoryRepository(firestore),
        PurchaseEntryRepository(firestore),
        SupplierRepository(firestore),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.voidPurchaseEntry(entry);

      expect(cubit.state.status, ProductStatus.saved);
      expect(cubit.state.products.single.stockQuantity, 5);
      expect(cubit.state.purchaseEntries, isEmpty);
      final archivedPurchase = PurchaseEntryModel.fromMap(
        entry.id,
        firestore.documents['purchase_entries/${entry.id}']!,
      );
      expect(archivedPurchase.isActive, isFalse);
    });

    test('voidPurchaseEntry rejects bills with payments', () async {
      final entry = PurchaseEntry(
        id: 'pur_1',
        entryNumber: 'PUR-202606-001',
        supplierId: 'sup_1',
        supplierName: 'Supply Hub',
        billReference: 'BILL-44',
        purchaseDate: DateTime(2026, 6, 5),
        items: const [],
        notes: '',
        totalAmount: 1000,
        amountPaid: 1000,
        paymentHistory: [
          PurchasePayment(amount: 1000, paidAt: DateTime(2026, 6, 5)),
        ],
        status: PurchasePaymentStatus.paid,
        isActive: true,
        createdAt: DateTime(2026, 6, 5),
        updatedAt: DateTime(2026, 6, 5),
      );
      final cubit = ProductCubit(
        ProductRepository(FakeCustomerFirestoreRestClient()),
        ProductInventoryRepository(FakeCustomerFirestoreRestClient()),
        PurchaseEntryRepository(FakeCustomerFirestoreRestClient()),
        SupplierRepository(FakeCustomerFirestoreRestClient()),
      );
      addTearDown(cubit.close);

      await cubit.voidPurchaseEntry(entry);

      expect(cubit.state.status, ProductStatus.failure);
      expect(cubit.state.message, contains('Remove supplier payments'));
    });
  });
}

ProductService _product({double stockQuantity = 5, double costPrice = 1800}) {
  final now = DateTime(2026, 6, 4);
  return ProductService(
    id: 'prod_1',
    name: 'Thermal Printer',
    description: '',
    type: ProductServiceType.product,
    sku: 'PRN-1',
    unit: 'pcs',
    defaultRate: 2500,
    hsnSac: '8443',
    gstRate: 18,
    trackInventory: true,
    costPrice: costPrice,
    stockQuantity: stockQuantity,
    reorderLevel: 2,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
