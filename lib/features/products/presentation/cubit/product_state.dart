part of 'product_cubit.dart';

enum ProductStatus { initial, loading, loaded, saving, saved, failure }

class ProductState extends Equatable {
  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.inventoryEntries = const [],
    this.suppliers = const [],
    this.searchQuery = '',
    this.supplierSearchQuery = '',
    this.message,
  });

  final ProductStatus status;
  final List<ProductService> products;
  final List<ProductInventoryEntry> inventoryEntries;
  final List<Supplier> suppliers;
  final String searchQuery;
  final String supplierSearchQuery;
  final String? message;

  bool get isBusy =>
      status == ProductStatus.loading || status == ProductStatus.saving;

  List<ProductService> get filteredProducts {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          product.unit.toLowerCase().contains(query) ||
          product.hsnSac.toLowerCase().contains(query) ||
          product.type.label.toLowerCase().contains(query);
    }).toList();
  }

  List<Supplier> get filteredSuppliers {
    final query = supplierSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return suppliers;
    return suppliers.where((supplier) {
      return supplier.name.toLowerCase().contains(query) ||
          supplier.phone.toLowerCase().contains(query) ||
          supplier.email.toLowerCase().contains(query) ||
          supplier.gstin.toLowerCase().contains(query) ||
          supplier.address.toLowerCase().contains(query) ||
          supplier.notes.toLowerCase().contains(query);
    }).toList();
  }

  ProductState copyWith({
    ProductStatus? status,
    List<ProductService>? products,
    List<ProductInventoryEntry>? inventoryEntries,
    List<Supplier>? suppliers,
    String? searchQuery,
    String? supplierSearchQuery,
    String? message,
    bool clearMessage = false,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      inventoryEntries: inventoryEntries ?? this.inventoryEntries,
      suppliers: suppliers ?? this.suppliers,
      searchQuery: searchQuery ?? this.searchQuery,
      supplierSearchQuery: supplierSearchQuery ?? this.supplierSearchQuery,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    products,
    inventoryEntries,
    suppliers,
    searchQuery,
    supplierSearchQuery,
    message,
  ];
}
