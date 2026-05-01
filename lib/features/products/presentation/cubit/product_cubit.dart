import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/entities/product_service.dart';

part 'product_state.dart';

class ProductCubit extends Cubit<ProductState> {
  ProductCubit(this._repository) : super(const ProductState());

  final ProductRepository _repository;

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
}
