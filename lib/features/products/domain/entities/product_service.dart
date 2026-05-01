import 'package:equatable/equatable.dart';

class ProductService extends Equatable {
  const ProductService({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.unit,
    required this.defaultRate,
    required this.hsnSac,
    required this.gstRate,
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
      unit: 'service',
      defaultRate: 0,
      hsnSac: '',
      gstRate: 0,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String name;
  final String description;
  final ProductServiceType type;
  final String unit;
  final double defaultRate;
  final String hsnSac;
  final double gstRate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    type,
    unit,
    defaultRate,
    hsnSac,
    gstRate,
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
