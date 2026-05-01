part of 'product_cubit.dart';

enum ProductStatus { initial, loading, loaded, saving, saved, failure }

class ProductState extends Equatable {
  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.searchQuery = '',
    this.message,
  });

  final ProductStatus status;
  final List<ProductService> products;
  final String searchQuery;
  final String? message;

  bool get isBusy =>
      status == ProductStatus.loading || status == ProductStatus.saving;

  List<ProductService> get filteredProducts {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          product.unit.toLowerCase().contains(query) ||
          product.hsnSac.toLowerCase().contains(query) ||
          product.type.label.toLowerCase().contains(query);
    }).toList();
  }

  ProductState copyWith({
    ProductStatus? status,
    List<ProductService>? products,
    String? searchQuery,
    String? message,
    bool clearMessage = false,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [status, products, searchQuery, message];
}
