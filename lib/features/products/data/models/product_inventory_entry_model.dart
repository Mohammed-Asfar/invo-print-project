import '../../domain/entities/product_inventory_entry.dart';

class ProductInventoryEntryModel extends ProductInventoryEntry {
  const ProductInventoryEntryModel({
    required super.id,
    required super.productId,
    required super.type,
    required super.quantityDelta,
    required super.balanceAfter,
    required super.createdAt,
    super.reference,
    super.reason,
    super.note,
  });

  factory ProductInventoryEntryModel.fromEntity(ProductInventoryEntry entry) {
    return ProductInventoryEntryModel(
      id: entry.id,
      productId: entry.productId,
      type: entry.type,
      quantityDelta: entry.quantityDelta,
      balanceAfter: entry.balanceAfter,
      createdAt: entry.createdAt,
      reference: entry.reference,
      reason: entry.reason,
      note: entry.note,
    );
  }

  factory ProductInventoryEntryModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return ProductInventoryEntryModel(
      id: id,
      productId: map['productId'] as String? ?? '',
      type: ProductInventoryEntryType.fromValue(map['type'] as String? ?? ''),
      quantityDelta: _toDouble(map['quantityDelta']),
      balanceAfter: _toDouble(map['balanceAfter']),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
      reference: map['reference'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      note: map['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'productId': productId,
      'type': type.firestoreValue,
      'quantityDelta': quantityDelta,
      'balanceAfter': balanceAfter,
      'createdAt': createdAt,
    };
    if (reference.trim().isNotEmpty) {
      map['reference'] = reference.trim();
    }
    if (reason.trim().isNotEmpty) {
      map['reason'] = reason.trim();
    }
    if (note.trim().isNotEmpty) {
      map['note'] = note.trim();
    }
    return map;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
