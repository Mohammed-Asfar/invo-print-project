import 'package:equatable/equatable.dart';

class PurchaseEntry extends Equatable {
  const PurchaseEntry({
    required this.id,
    required this.entryNumber,
    required this.supplierId,
    required this.supplierName,
    required this.billReference,
    required this.purchaseDate,
    required this.items,
    required this.notes,
    required this.totalAmount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String entryNumber;
  final String supplierId;
  final String supplierName;
  final String billReference;
  final DateTime purchaseDate;
  final List<PurchaseEntryItem> items;
  final String notes;
  final double totalAmount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  PurchaseEntry copyWith({
    String? id,
    String? entryNumber,
    String? supplierId,
    String? supplierName,
    String? billReference,
    DateTime? purchaseDate,
    List<PurchaseEntryItem>? items,
    String? notes,
    double? totalAmount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchaseEntry(
      id: id ?? this.id,
      entryNumber: entryNumber ?? this.entryNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      billReference: billReference ?? this.billReference,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      totalAmount: totalAmount ?? this.totalAmount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    entryNumber,
    supplierId,
    supplierName,
    billReference,
    purchaseDate,
    items,
    notes,
    totalAmount,
    isActive,
    createdAt,
    updatedAt,
  ];
}

class PurchaseEntryItem extends Equatable {
  const PurchaseEntryItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unit,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
  });

  final String productId;
  final String productName;
  final String sku;
  final String unit;
  final double quantity;
  final double unitCost;
  final double lineTotal;

  PurchaseEntryItem copyWith({
    String? productId,
    String? productName,
    String? sku,
    String? unit,
    double? quantity,
    double? unitCost,
    double? lineTotal,
  }) {
    return PurchaseEntryItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }

  @override
  List<Object?> get props => [
    productId,
    productName,
    sku,
    unit,
    quantity,
    unitCost,
    lineTotal,
  ];
}
