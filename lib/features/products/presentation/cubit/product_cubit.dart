import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/product_inventory_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/purchase_entry_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/entities/product_inventory_entry.dart';
import '../../domain/entities/purchase_entry.dart';
import '../../domain/entities/product_service.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/services/product_inventory_history_builder.dart';
import '../../domain/services/supplier_ledger.dart';

part 'product_state.dart';

class ProductCubit extends Cubit<ProductState> {
  ProductCubit(
    this._repository,
    this._inventoryRepository,
    this._purchaseEntryRepository,
    this._supplierRepository,
  ) : super(const ProductState());

  final ProductRepository _repository;
  final ProductInventoryRepository _inventoryRepository;
  final PurchaseEntryRepository _purchaseEntryRepository;
  final SupplierRepository _supplierRepository;

  Future<void> load() async {
    emit(state.copyWith(status: ProductStatus.loading, clearMessage: true));
    try {
      final results = await Future.wait<Object>([
        _repository.fetchProducts(),
        _inventoryRepository.fetchAllEntries(),
        _purchaseEntryRepository.fetchPurchaseEntries(),
        _supplierRepository.fetchSuppliers(),
      ]);
      final products = results[0] as List<ProductService>;
      final inventoryEntries = results[1] as List<ProductInventoryEntry>;
      final purchaseEntries = results[2] as List<PurchaseEntry>;
      final suppliers = results[3] as List<Supplier>;
      emit(
        state.copyWith(
          status: ProductStatus.loaded,
          products: products,
          inventoryEntries: inventoryEntries,
          purchaseEntries: purchaseEntries,
          suppliers: suppliers,
          clearMessage: true,
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: ProductStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Unable to load products: $error',
        ),
      );
    }
  }

  void search(String value) {
    emit(state.copyWith(searchQuery: value));
  }

  Future<void> save(ProductService product) async {
    emit(state.copyWith(status: ProductStatus.saving));
    try {
      await _repository.saveProduct(product);
      final products = await _repository.fetchProducts();
      emit(
        state.copyWith(
          status: ProductStatus.saved,
          products: products,
          message: 'Product saved.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: ProductStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Unable to save product: $error',
        ),
      );
    }
  }

  Future<void> archive(ProductService product) async {
    emit(state.copyWith(status: ProductStatus.saving));
    try {
      await _repository.archiveProduct(product);
      final products = await _repository.fetchProducts();
      emit(
        state.copyWith(
          status: ProductStatus.saved,
          products: products,
          message: 'Product archived.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: ProductStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Unable to archive product: $error',
        ),
      );
    }
  }

  void searchSuppliers(String value) {
    emit(state.copyWith(supplierSearchQuery: value));
  }

  void searchPurchases(String value) {
    emit(state.copyWith(purchaseSearchQuery: value));
  }

  void setPurchaseStatusFilter(PurchaseStatusFilter value) {
    emit(state.copyWith(purchaseStatusFilter: value));
  }

  void setPurchaseSupplierFilter(String supplierId) {
    emit(state.copyWith(purchaseSupplierId: supplierId));
  }

  Future<void> saveSupplier(Supplier supplier) async {
    emit(state.copyWith(status: ProductStatus.saving));
    try {
      await _supplierRepository.saveSupplier(supplier);
      final suppliers = await _supplierRepository.fetchSuppliers();
      emit(
        state.copyWith(
          status: ProductStatus.saved,
          suppliers: suppliers,
          message: 'Supplier saved.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: ProductStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Unable to save supplier: $error',
        ),
      );
    }
  }

  Future<void> archiveSupplier(Supplier supplier) async {
    emit(state.copyWith(status: ProductStatus.saving));
    try {
      await _supplierRepository.archiveSupplier(supplier);
      final suppliers = await _supplierRepository.fetchSuppliers();
      emit(
        state.copyWith(
          status: ProductStatus.saved,
          suppliers: suppliers,
          message: 'Supplier archived.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: ProductStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Unable to archive supplier: $error',
        ),
      );
    }
  }

  Future<void> savePurchaseEntry(PurchaseEntry purchaseEntry) async {
    final trimmedEntryNumber = purchaseEntry.entryNumber.trim();
    final trimmedSupplierName = purchaseEntry.supplierName.trim();
    if (trimmedEntryNumber.isEmpty) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Enter a purchase entry number.',
        ),
      );
      return;
    }
    if (trimmedSupplierName.isEmpty) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Select or enter a supplier name.',
        ),
      );
      return;
    }
    if (purchaseEntry.items.isEmpty) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Add at least one purchase item.',
        ),
      );
      return;
    }
    if (purchaseEntry.dueDate != null &&
        purchaseEntry.dueDate!.isBefore(purchaseEntry.purchaseDate)) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Purchase due date cannot be earlier than purchase date.',
        ),
      );
      return;
    }

    final productsById = {
      for (final product in state.products) product.id: product,
    };
    final updatedProducts = <ProductService>[];
    final originalProducts = <ProductService>[];
    final quantityTotals = <String, double>{};
    final latestUnitCostByProductId = <String, double>{};

    for (final item in purchaseEntry.items) {
      final product = productsById[item.productId];
      if (product == null || !product.trackInventory) {
        emit(
          state.copyWith(
            status: ProductStatus.failure,
            message:
                'Purchase items must reference tracked inventory products.',
          ),
        );
        return;
      }
      if (item.quantity <= 0) {
        emit(
          state.copyWith(
            status: ProductStatus.failure,
            message: 'Purchase quantities must be greater than zero.',
          ),
        );
        return;
      }
      quantityTotals[item.productId] = _roundQuantity(
        (quantityTotals[item.productId] ?? 0) + item.quantity,
      );
      if (item.unitCost > 0) {
        latestUnitCostByProductId[item.productId] = item.unitCost;
      }
    }

    for (final entry in quantityTotals.entries) {
      final product = productsById[entry.key]!;
      originalProducts.add(product);
      updatedProducts.add(
        product.copyWith(
          stockQuantity: _roundQuantity(product.stockQuantity + entry.value),
          costPrice: latestUnitCostByProductId[entry.key] ?? product.costPrice,
          updatedAt: DateTime.now(),
        ),
      );
    }

    emit(state.copyWith(status: ProductStatus.saving));
    final historyEntries = <ProductInventoryEntry>[
      for (final item in purchaseEntry.items)
        buildInventoryEntries(
          quantityDeltas: {item.productId: item.quantity},
          products: updatedProducts
              .where((product) => product.id == item.productId)
              .toList(),
          type: ProductInventoryEntryType.purchaseReceived,
          createdAt: purchaseEntry.purchaseDate,
          reference: trimmedEntryNumber,
          secondaryReference: purchaseEntry.billReference.trim(),
          supplierName: trimmedSupplierName,
          unitCost: item.unitCost,
          reason: 'Purchase',
          note: purchaseEntry.notes.trim(),
        ).single,
    ];

    try {
      await _repository.saveProducts(updatedProducts);
      try {
        await _inventoryRepository.saveEntries(historyEntries);
      } catch (_) {
        await _repository.saveProducts(originalProducts);
        rethrow;
      }
      try {
        await _purchaseEntryRepository.savePurchaseEntry(
          purchaseEntry.copyWith(
            totalAmount: _roundQuantity(
              purchaseEntry.items.fold<double>(
                0,
                (sum, item) => sum + item.lineTotal,
              ),
            ),
            amountPaid: 0,
            paymentHistory: const [],
            status: PurchasePaymentStatus.unpaid,
          ),
        );
      } catch (_) {
        await _inventoryRepository.deleteEntries(
          historyEntries.map((entry) => entry.id),
        );
        await _repository.saveProducts(originalProducts);
        rethrow;
      }

      final results = await Future.wait<Object>([
        _repository.fetchProducts(),
        _inventoryRepository.fetchAllEntries(),
        _purchaseEntryRepository.fetchPurchaseEntries(),
        _supplierRepository.fetchSuppliers(),
      ]);
      emit(
        state.copyWith(
          status: ProductStatus.saved,
          products: results[0] as List<ProductService>,
          inventoryEntries: results[1] as List<ProductInventoryEntry>,
          purchaseEntries: results[2] as List<PurchaseEntry>,
          suppliers: results[3] as List<Supplier>,
          message: 'Purchase entry saved.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: ProductStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Unable to save purchase entry: $error',
        ),
      );
    }
  }

  Future<void> adjustStock(
    ProductService product, {
    required double quantityDelta,
    required String reason,
    DateTime? effectiveAt,
    String reference = '',
    String secondaryReference = '',
    String supplierName = '',
    double unitCost = 0,
    bool updateCostPriceFromUnitCost = false,
    String note = '',
  }) async {
    final normalizedDelta = _roundQuantity(quantityDelta);
    if (normalizedDelta == 0) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Enter a stock change other than zero.',
        ),
      );
      return;
    }
    if (reason.trim().isEmpty) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Enter a reason for the stock adjustment.',
        ),
      );
      return;
    }
    final nextStock = _roundQuantity(product.stockQuantity + normalizedDelta);
    if (nextStock < 0) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Stock cannot go below zero.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ProductStatus.saving));
    final now = effectiveAt ?? DateTime.now();
    final updatedProduct = product.copyWith(
      costPrice:
          updateCostPriceFromUnitCost && normalizedDelta > 0 && unitCost > 0
          ? unitCost
          : product.costPrice,
      stockQuantity: nextStock,
      updatedAt: DateTime.now(),
    );
    final entries = buildInventoryEntries(
      quantityDeltas: {product.id: normalizedDelta},
      products: [updatedProduct],
      type: ProductInventoryEntryType.manualAdjustment,
      createdAt: now,
      reference: reference.trim(),
      secondaryReference: secondaryReference.trim(),
      supplierName: supplierName.trim(),
      unitCost: unitCost > 0 ? unitCost : 0,
      reason: reason.trim(),
      note: note.trim(),
    );

    try {
      await _inventoryRepository.saveEntries(entries);
      try {
        await _repository.saveProduct(updatedProduct);
      } catch (_) {
        await _inventoryRepository.deleteEntries(
          entries.map((entry) => entry.id),
        );
        rethrow;
      }
      final results = await Future.wait<Object>([
        _repository.fetchProducts(),
        _inventoryRepository.fetchAllEntries(),
        _purchaseEntryRepository.fetchPurchaseEntries(),
        _supplierRepository.fetchSuppliers(),
      ]);
      final products = results[0] as List<ProductService>;
      final inventoryEntries = results[1] as List<ProductInventoryEntry>;
      final purchaseEntries = results[2] as List<PurchaseEntry>;
      final suppliers = results[3] as List<Supplier>;
      emit(
        state.copyWith(
          status: ProductStatus.saved,
          products: products,
          inventoryEntries: inventoryEntries,
          purchaseEntries: purchaseEntries,
          suppliers: suppliers,
          message: 'Stock adjusted.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(status: ProductStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Unable to adjust stock: $error',
        ),
      );
    }
  }

  Future<List<ProductInventoryEntry>> loadInventoryEntries(String productId) {
    return _inventoryRepository.fetchEntries(productId);
  }

  SupplierLedger supplierLedgerFor(Supplier supplier) {
    return buildSupplierLedger(
      supplier: supplier,
      purchaseEntries: state.purchaseEntries,
    );
  }

  Future<void> voidPurchaseEntry(PurchaseEntry purchaseEntry) async {
    if (purchaseEntry.amountPaid > 0 ||
        purchaseEntry.paymentHistory.isNotEmpty) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Remove supplier payments before voiding this bill.',
        ),
      );
      return;
    }
    final quantityTotals = <String, double>{};
    final currentProductsById = {
      for (final product in state.products) product.id: product,
    };
    final originalProducts = <ProductService>[];
    final updatedProducts = <ProductService>[];

    for (final item in purchaseEntry.items) {
      final product = currentProductsById[item.productId];
      if (product == null || !product.trackInventory) {
        emit(
          state.copyWith(
            status: ProductStatus.failure,
            message:
                'Unable to void this bill because an inventory item is missing.',
          ),
        );
        return;
      }
      quantityTotals[item.productId] = _roundQuantity(
        (quantityTotals[item.productId] ?? 0) + item.quantity,
      );
    }

    for (final item in quantityTotals.entries) {
      final product = currentProductsById[item.key]!;
      final nextStock = _roundQuantity(product.stockQuantity - item.value);
      if (nextStock < 0) {
        emit(
          state.copyWith(
            status: ProductStatus.failure,
            message:
                'Cannot void ${purchaseEntry.entryNumber} because ${product.name} stock would go below zero.',
          ),
        );
        return;
      }
      originalProducts.add(product);
      updatedProducts.add(
        product.copyWith(stockQuantity: nextStock, updatedAt: DateTime.now()),
      );
    }

    final historyEntries = buildInventoryEntries(
      quantityDeltas: {
        for (final item in quantityTotals.entries) item.key: -item.value,
      },
      products: updatedProducts,
      type: ProductInventoryEntryType.manualAdjustment,
      createdAt: DateTime.now(),
      reference: purchaseEntry.entryNumber,
      secondaryReference: purchaseEntry.billReference.trim(),
      supplierName: purchaseEntry.supplierName.trim(),
      reason: 'Purchase voided',
      note: purchaseEntry.notes.trim(),
    );

    emit(state.copyWith(status: ProductStatus.saving));
    try {
      await _repository.saveProducts(updatedProducts);
      try {
        await _inventoryRepository.saveEntries(historyEntries);
      } catch (_) {
        await _repository.saveProducts(originalProducts);
        rethrow;
      }
      try {
        await _purchaseEntryRepository.archivePurchaseEntry(purchaseEntry);
      } catch (_) {
        await _inventoryRepository.deleteEntries(
          historyEntries.map((entry) => entry.id),
        );
        await _repository.saveProducts(originalProducts);
        rethrow;
      }
      await _reloadState(message: 'Purchase bill voided.');
    } on AppException catch (error) {
      emit(
        state.copyWith(status: ProductStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Unable to void purchase bill: $error',
        ),
      );
    }
  }

  Future<void> recordPurchasePayment(
    PurchaseEntry purchaseEntry, {
    required double amount,
    required DateTime paidAt,
    String method = '',
    String reference = '',
    String notes = '',
  }) async {
    if (amount <= 0) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Enter a payment amount greater than zero.',
        ),
      );
      return;
    }
    if (purchaseEntry.balanceDue <= 0) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'This supplier bill is already fully paid.',
        ),
      );
      return;
    }

    final appliedAmount = amount > purchaseEntry.balanceDue
        ? purchaseEntry.balanceDue
        : amount;
    final updatedEntry = _rebuildPurchasePaymentState(purchaseEntry, [
      ...purchaseEntry.paymentHistory,
      PurchasePayment(
        amount: _roundQuantity(appliedAmount),
        paidAt: paidAt,
        method: method.trim(),
        reference: reference.trim(),
        notes: notes.trim(),
      ),
    ]);

    await _savePurchasePaymentState(
      updatedEntry,
      successMessage: 'Supplier payment recorded.',
      failurePrefix: 'Unable to record supplier payment',
    );
  }

  Future<void> updatePurchasePayment(
    PurchaseEntry purchaseEntry, {
    required int index,
    required double amount,
    required DateTime paidAt,
    String method = '',
    String reference = '',
    String notes = '',
  }) async {
    if (index < 0 || index >= purchaseEntry.paymentHistory.length) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'That payment entry could not be found.',
        ),
      );
      return;
    }
    if (amount <= 0) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'Enter a payment amount greater than zero.',
        ),
      );
      return;
    }
    final paymentHistory = [...purchaseEntry.paymentHistory];
    paymentHistory[index] = PurchasePayment(
      amount: _roundQuantity(amount),
      paidAt: paidAt,
      method: method.trim(),
      reference: reference.trim(),
      notes: notes.trim(),
    );
    final updatedEntry = _rebuildPurchasePaymentState(
      purchaseEntry,
      paymentHistory,
    );
    if (updatedEntry.amountPaid > purchaseEntry.totalAmount) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message:
              'Edited payment total cannot exceed the supplier bill amount.',
        ),
      );
      return;
    }
    await _savePurchasePaymentState(
      updatedEntry,
      successMessage: 'Supplier payment updated.',
      failurePrefix: 'Unable to update supplier payment',
    );
  }

  Future<void> deletePurchasePayment(
    PurchaseEntry purchaseEntry, {
    required int index,
  }) async {
    if (index < 0 || index >= purchaseEntry.paymentHistory.length) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: 'That payment entry could not be found.',
        ),
      );
      return;
    }
    final paymentHistory = [...purchaseEntry.paymentHistory]..removeAt(index);
    final updatedEntry = _rebuildPurchasePaymentState(
      purchaseEntry,
      paymentHistory,
    );
    await _savePurchasePaymentState(
      updatedEntry,
      successMessage: 'Supplier payment removed.',
      failurePrefix: 'Unable to remove supplier payment',
    );
  }

  Future<void> _savePurchasePaymentState(
    PurchaseEntry purchaseEntry, {
    required String successMessage,
    required String failurePrefix,
  }) async {
    emit(state.copyWith(status: ProductStatus.saving));
    try {
      await _purchaseEntryRepository.savePurchaseEntry(purchaseEntry);
      await _reloadState(message: successMessage);
    } on AppException catch (error) {
      emit(
        state.copyWith(status: ProductStatus.failure, message: error.message),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          message: '$failurePrefix: $error',
        ),
      );
    }
  }

  PurchaseEntry _rebuildPurchasePaymentState(
    PurchaseEntry purchaseEntry,
    List<PurchasePayment> paymentHistory,
  ) {
    paymentHistory.sort((a, b) => a.paidAt.compareTo(b.paidAt));
    final amountPaid = _roundQuantity(
      paymentHistory.fold<double>(0, (sum, payment) => sum + payment.amount),
    );
    final status = amountPaid <= 0
        ? PurchasePaymentStatus.unpaid
        : amountPaid >= purchaseEntry.totalAmount
        ? PurchasePaymentStatus.paid
        : PurchasePaymentStatus.partial;
    return purchaseEntry.copyWith(
      amountPaid: amountPaid,
      paymentHistory: paymentHistory,
      status: status,
    );
  }

  Future<void> _reloadState({required String message}) async {
    final results = await Future.wait<Object>([
      _repository.fetchProducts(),
      _inventoryRepository.fetchAllEntries(),
      _purchaseEntryRepository.fetchPurchaseEntries(),
      _supplierRepository.fetchSuppliers(),
    ]);
    emit(
      state.copyWith(
        status: ProductStatus.saved,
        products: results[0] as List<ProductService>,
        inventoryEntries: results[1] as List<ProductInventoryEntry>,
        purchaseEntries: results[2] as List<PurchaseEntry>,
        suppliers: results[3] as List<Supplier>,
        message: message,
      ),
    );
  }

  double _roundQuantity(double value) {
    return double.parse(value.toStringAsFixed(4));
  }
}
