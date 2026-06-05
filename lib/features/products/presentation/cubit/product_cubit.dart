import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/product_inventory_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/entities/product_inventory_entry.dart';
import '../../domain/entities/product_service.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/services/product_inventory_history_builder.dart';

part 'product_state.dart';

class ProductCubit extends Cubit<ProductState> {
  ProductCubit(
    this._repository,
    this._inventoryRepository,
    this._supplierRepository,
  ) : super(const ProductState());

  final ProductRepository _repository;
  final ProductInventoryRepository _inventoryRepository;
  final SupplierRepository _supplierRepository;

  Future<void> load() async {
    emit(state.copyWith(status: ProductStatus.loading, clearMessage: true));
    try {
      final results = await Future.wait<Object>([
        _repository.fetchProducts(),
        _inventoryRepository.fetchAllEntries(),
        _supplierRepository.fetchSuppliers(),
      ]);
      final products = results[0] as List<ProductService>;
      final inventoryEntries = results[1] as List<ProductInventoryEntry>;
      final suppliers = results[2] as List<Supplier>;
      emit(
        state.copyWith(
          status: ProductStatus.loaded,
          products: products,
          inventoryEntries: inventoryEntries,
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
        _supplierRepository.fetchSuppliers(),
      ]);
      final products = results[0] as List<ProductService>;
      final inventoryEntries = results[1] as List<ProductInventoryEntry>;
      final suppliers = results[2] as List<Supplier>;
      emit(
        state.copyWith(
          status: ProductStatus.saved,
          products: products,
          inventoryEntries: inventoryEntries,
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

  double _roundQuantity(double value) {
    return double.parse(value.toStringAsFixed(4));
  }
}
