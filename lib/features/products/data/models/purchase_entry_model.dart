import '../../domain/entities/purchase_entry.dart';

class PurchaseEntryModel extends PurchaseEntry {
  const PurchaseEntryModel({
    required super.id,
    required super.entryNumber,
    required super.supplierId,
    required super.supplierName,
    required super.billReference,
    required super.purchaseDate,
    required super.items,
    required super.notes,
    required super.totalAmount,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PurchaseEntryModel.fromEntity(PurchaseEntry entry) {
    return PurchaseEntryModel(
      id: entry.id,
      entryNumber: entry.entryNumber,
      supplierId: entry.supplierId,
      supplierName: entry.supplierName,
      billReference: entry.billReference,
      purchaseDate: entry.purchaseDate,
      items: entry.items,
      notes: entry.notes,
      totalAmount: entry.totalAmount,
      isActive: entry.isActive,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  factory PurchaseEntryModel.fromMap(String id, Map<String, dynamic> map) {
    final now = DateTime.now();
    final rawItems = map['items'];
    return PurchaseEntryModel(
      id: id,
      entryNumber: map['entryNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String? ?? '',
      billReference: map['billReference'] as String? ?? '',
      purchaseDate: _toDateTime(map['purchaseDate']) ?? now,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => _itemFromMap(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
      notes: map['notes'] as String? ?? '',
      totalAmount: _toDouble(map['totalAmount']),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _toDateTime(map['createdAt']) ?? now,
      updatedAt: _toDateTime(map['updatedAt']) ?? now,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'entryNumber': entryNumber.trim(),
      'supplierName': supplierName.trim(),
      'purchaseDate': purchaseDate,
      'items': items.map(_itemToMap).toList(),
      'totalAmount': totalAmount,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (supplierId.trim().isNotEmpty) {
      map['supplierId'] = supplierId.trim();
    }
    if (billReference.trim().isNotEmpty) {
      map['billReference'] = billReference.trim();
    }
    if (notes.trim().isNotEmpty) {
      map['notes'] = notes.trim();
    }
    return map;
  }

  static PurchaseEntryItem _itemFromMap(Map<String, dynamic> map) {
    return PurchaseEntryItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      quantity: _toDouble(map['quantity']),
      unitCost: _toDouble(map['unitCost']),
      lineTotal: _toDouble(map['lineTotal']),
    );
  }

  static Map<String, dynamic> _itemToMap(PurchaseEntryItem item) {
    return {
      'productId': item.productId,
      'productName': item.productName,
      'sku': item.sku,
      'unit': item.unit,
      'quantity': item.quantity,
      'unitCost': item.unitCost,
      'lineTotal': item.lineTotal,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
