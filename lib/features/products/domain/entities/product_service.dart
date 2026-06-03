import 'package:equatable/equatable.dart';

class ProductService extends Equatable {
  const ProductService({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.sku,
    required this.unit,
    required this.defaultRate,
    required this.hsnSac,
    required this.gstRate,
    required this.trackInventory,
    required this.stockQuantity,
    required this.reorderLevel,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductService.empty() {
    final now = DateTime.now();
    return ProductService(
      id: '',
      name: '',
      description: '',
      type: ProductServiceType.service,
      sku: '',
      unit: 'service',
      defaultRate: 0,
      hsnSac: '',
      gstRate: 0,
      trackInventory: false,
      stockQuantity: 0,
      reorderLevel: 0,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String name;
  final String description;
  final ProductServiceType type;
  final String sku;
  final String unit;
  final double defaultRate;
  final String hsnSac;
  final double gstRate;
  final bool trackInventory;
  final double stockQuantity;
  final double reorderLevel;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock =>
      trackInventory && reorderLevel > 0 && stockQuantity <= reorderLevel;

  ProductService copyWith({
    String? id,
    String? name,
    String? description,
    ProductServiceType? type,
    String? sku,
    String? unit,
    double? defaultRate,
    String? hsnSac,
    double? gstRate,
    bool? trackInventory,
    double? stockQuantity,
    double? reorderLevel,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductService(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      defaultRate: defaultRate ?? this.defaultRate,
      hsnSac: hsnSac ?? this.hsnSac,
      gstRate: gstRate ?? this.gstRate,
      trackInventory: trackInventory ?? this.trackInventory,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    type,
    sku,
    unit,
    defaultRate,
    hsnSac,
    gstRate,
    trackInventory,
    stockQuantity,
    reorderLevel,
    isActive,
    createdAt,
    updatedAt,
  ];
}

enum ProductServiceType {
  product,
  service;

  String get label => switch (this) {
    ProductServiceType.product => 'Product',
    ProductServiceType.service => 'Service',
  };

  String get firestoreValue => switch (this) {
    ProductServiceType.product => 'product',
    ProductServiceType.service => 'service',
  };

  static ProductServiceType fromValue(String value) {
    return value == 'product'
        ? ProductServiceType.product
        : ProductServiceType.service;
  }
}
