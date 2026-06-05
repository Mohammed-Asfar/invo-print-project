import '../../domain/entities/supplier.dart';

class SupplierModel extends Supplier {
  const SupplierModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.email,
    required super.gstin,
    required super.address,
    required super.notes,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SupplierModel.fromEntity(Supplier supplier) {
    return SupplierModel(
      id: supplier.id,
      name: supplier.name,
      phone: supplier.phone,
      email: supplier.email,
      gstin: supplier.gstin,
      address: supplier.address,
      notes: supplier.notes,
      isActive: supplier.isActive,
      createdAt: supplier.createdAt,
      updatedAt: supplier.updatedAt,
    );
  }

  factory SupplierModel.fromMap(String id, Map<String, dynamic> map) {
    final now = DateTime.now();
    return SupplierModel(
      id: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      gstin: map['gstin'] as String? ?? '',
      address: map['address'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _toDateTime(map['createdAt']) ?? now,
      updatedAt: _toDateTime(map['updatedAt']) ?? now,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (phone.trim().isNotEmpty) {
      map['phone'] = phone.trim();
    }
    if (email.trim().isNotEmpty) {
      map['email'] = email.trim();
    }
    if (gstin.trim().isNotEmpty) {
      map['gstin'] = gstin.trim();
    }
    if (address.trim().isNotEmpty) {
      map['address'] = address.trim();
    }
    if (notes.trim().isNotEmpty) {
      map['notes'] = notes.trim();
    }
    return map;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
