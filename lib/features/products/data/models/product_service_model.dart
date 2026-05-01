import '../../domain/entities/product_service.dart';

class ProductServiceModel extends ProductService {
  const ProductServiceModel({
    required super.id,
    required super.name,
    required super.description,
    required super.type,
    required super.unit,
    required super.defaultRate,
    required super.hsnSac,
    required super.gstRate,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductServiceModel.fromEntity(ProductService product) {
    return ProductServiceModel(
      id: product.id,
      name: product.name,
      description: product.description,
      type: product.type,
      unit: product.unit,
      defaultRate: product.defaultRate,
      hsnSac: product.hsnSac,
      gstRate: product.gstRate,
      isActive: product.isActive,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
    );
  }

  factory ProductServiceModel.fromMap(String id, Map<String, dynamic> map) {
    final defaults = ProductService.empty();
    return ProductServiceModel(
      id: id,
      name: map['name'] as String? ?? defaults.name,
      description: map['description'] as String? ?? defaults.description,
      type: ProductServiceType.fromValue(
        map['type'] as String? ?? defaults.type.firestoreValue,
      ),
      unit: map['unit'] as String? ?? defaults.unit,
      defaultRate: _toDouble(map['defaultRate'], defaults.defaultRate),
      hsnSac: map['hsnSac'] as String? ?? defaults.hsnSac,
      gstRate: _toDouble(map['gstRate'], defaults.gstRate),
      isActive: map['isActive'] as bool? ?? defaults.isActive,
      createdAt: _toDateTime(map['createdAt']) ?? defaults.createdAt,
      updatedAt: _toDateTime(map['updatedAt']) ?? defaults.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type.firestoreValue,
      'unit': unit,
      'defaultRate': defaultRate,
      'hsnSac': hsnSac,
      'gstRate': gstRate,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
