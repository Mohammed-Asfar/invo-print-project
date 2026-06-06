part of 'product_cubit.dart';

enum ProductStatus { initial, loading, loaded, saving, saved, failure }

enum PurchaseStatusFilter { all, open, overdue, unpaid, partial, paid }

extension PurchaseStatusFilterX on PurchaseStatusFilter {
  String get label => switch (this) {
    PurchaseStatusFilter.all => 'All bills',
    PurchaseStatusFilter.open => 'Open bills',
    PurchaseStatusFilter.overdue => 'Overdue',
    PurchaseStatusFilter.unpaid => 'Unpaid',
    PurchaseStatusFilter.partial => 'Partial',
    PurchaseStatusFilter.paid => 'Paid',
  };
}

class ProductState extends Equatable {
  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.inventoryEntries = const [],
    this.suppliers = const [],
    this.purchaseEntries = const [],
    this.searchQuery = '',
    this.supplierSearchQuery = '',
    this.purchaseSearchQuery = '',
    this.purchaseStatusFilter = PurchaseStatusFilter.all,
    this.purchaseSupplierId = '',
    this.message,
  });

  final ProductStatus status;
  final List<ProductService> products;
  final List<ProductInventoryEntry> inventoryEntries;
  final List<Supplier> suppliers;
  final List<PurchaseEntry> purchaseEntries;
  final String searchQuery;
  final String supplierSearchQuery;
  final String purchaseSearchQuery;
  final PurchaseStatusFilter purchaseStatusFilter;
  final String purchaseSupplierId;
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
          supplier.notes.toLowerCase().contains(query) ||
          supplier.followUpNotes.toLowerCase().contains(query) ||
          supplier.followUpStatus.label.toLowerCase().contains(query);
    }).toList();
  }

  List<PurchaseEntry> get filteredPurchaseEntries {
    final query = purchaseSearchQuery.trim().toLowerCase();
    return purchaseEntries.where((entry) {
      final matchesQuery =
          query.isEmpty ||
          entry.entryNumber.toLowerCase().contains(query) ||
          entry.supplierName.toLowerCase().contains(query) ||
          entry.billReference.toLowerCase().contains(query) ||
          entry.notes.toLowerCase().contains(query) ||
          entry.items.any(
            (item) =>
                item.productName.toLowerCase().contains(query) ||
                item.sku.toLowerCase().contains(query),
          );
      final matchesStatus = switch (purchaseStatusFilter) {
        PurchaseStatusFilter.all => true,
        PurchaseStatusFilter.open => entry.balanceDue > 0,
        PurchaseStatusFilter.overdue => isPurchaseOverdue(entry),
        PurchaseStatusFilter.unpaid =>
          entry.status == PurchasePaymentStatus.unpaid,
        PurchaseStatusFilter.partial =>
          entry.status == PurchasePaymentStatus.partial,
        PurchaseStatusFilter.paid => entry.status == PurchasePaymentStatus.paid,
      };
      final matchesSupplier =
          purchaseSupplierId.isEmpty ||
          entry.supplierId == purchaseSupplierId ||
          (entry.supplierId.isEmpty &&
              suppliers.any(
                (supplier) =>
                    supplier.id == purchaseSupplierId &&
                    supplier.name.trim().toLowerCase() ==
                        entry.supplierName.trim().toLowerCase(),
              ));
      return matchesQuery && matchesStatus && matchesSupplier;
    }).toList();
  }

  int get openPurchaseCount =>
      purchaseEntries.where((entry) => entry.balanceDue > 0).length;

  int get unpaidPurchaseCount => purchaseEntries
      .where((entry) => entry.status == PurchasePaymentStatus.unpaid)
      .length;

  int get overduePurchaseCount =>
      purchaseEntries.where(isPurchaseOverdue).length;

  int get partialPurchaseCount => purchaseEntries
      .where((entry) => entry.status == PurchasePaymentStatus.partial)
      .length;

  double get totalPurchaseOutstanding => double.parse(
    purchaseEntries
        .fold<double>(0, (sum, entry) => sum + entry.balanceDue)
        .toStringAsFixed(2),
  );

  double get overduePurchaseAmount => double.parse(
    purchaseEntries
        .where(isPurchaseOverdue)
        .fold<double>(0, (sum, entry) => sum + entry.balanceDue)
        .toStringAsFixed(2),
  );

  ProductState copyWith({
    ProductStatus? status,
    List<ProductService>? products,
    List<ProductInventoryEntry>? inventoryEntries,
    List<Supplier>? suppliers,
    List<PurchaseEntry>? purchaseEntries,
    String? searchQuery,
    String? supplierSearchQuery,
    String? purchaseSearchQuery,
    PurchaseStatusFilter? purchaseStatusFilter,
    String? purchaseSupplierId,
    String? message,
    bool clearMessage = false,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      inventoryEntries: inventoryEntries ?? this.inventoryEntries,
      suppliers: suppliers ?? this.suppliers,
      purchaseEntries: purchaseEntries ?? this.purchaseEntries,
      searchQuery: searchQuery ?? this.searchQuery,
      supplierSearchQuery: supplierSearchQuery ?? this.supplierSearchQuery,
      purchaseSearchQuery: purchaseSearchQuery ?? this.purchaseSearchQuery,
      purchaseStatusFilter: purchaseStatusFilter ?? this.purchaseStatusFilter,
      purchaseSupplierId: purchaseSupplierId ?? this.purchaseSupplierId,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    products,
    inventoryEntries,
    suppliers,
    purchaseEntries,
    searchQuery,
    supplierSearchQuery,
    purchaseSearchQuery,
    purchaseStatusFilter,
    purchaseSupplierId,
    message,
  ];
}

bool isPurchaseOverdue(PurchaseEntry entry, {DateTime? today}) =>
    entry.isOverdue(today: today);
