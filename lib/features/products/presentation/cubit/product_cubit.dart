import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/product_inventory_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/entities/product_inventory_entry.dart';
import '../../domain/entities/product_service.dart';
import '../../domain/services/product_inventory_history_builder.dart';

part 'product_state.dart';

class ProductCubit extends Cubit<ProductState> {
  ProductCubit(this._repository, this._inventoryRepository)
    : super(const ProductState());

  final ProductRepository _repository;
  final ProductInventoryRepository _inventoryRepository;

  Future<void> load() async {
    emit(state.copyWith(status: ProductStatus.loading, clearMessage: true));
    try {
      final products = await _repository.fetchProducts();
      emit(
        state.copyWith(
          status: ProductStatus.loaded,
          products: products,
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

  Future<void> adjustStock(
    ProductService product, {
    required double quantityDelta,
    required String reason,
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
    final now = DateTime.now();
    final updatedProduct = product.copyWith(
      stockQuantity: nextStock,
      updatedAt: now,
    );
    final entries = buildInventoryEntries(
      quantityDeltas: {product.id: normalizedDelta},
      products: [updatedProduct],
      type: ProductInventoryEntryType.manualAdjustment,
      createdAt: now,
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
      final products = await _repository.fetchProducts();
      emit(
        state.copyWith(
          status: ProductStatus.saved,
          products: products,
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
