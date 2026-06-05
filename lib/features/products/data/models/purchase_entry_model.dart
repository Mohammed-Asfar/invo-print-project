import '../../domain/entities/purchase_entry.dart';

class PurchaseEntryModel extends PurchaseEntry {
  const PurchaseEntryModel({
    required super.id,
    required super.entryNumber,
    required super.supplierId,
    required super.supplierName,
    required super.billReference,
    required super.purchaseDate,
    super.dueDate,
    required super.items,
    required super.notes,
    required super.totalAmount,
    required super.amountPaid,
    required super.paymentHistory,
    required super.returnHistory,
    required super.status,
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
      dueDate: entry.dueDate,
      items: entry.items,
      notes: entry.notes,
      totalAmount: entry.totalAmount,
      amountPaid: entry.amountPaid,
      paymentHistory: entry.paymentHistory,
      returnHistory: entry.returnHistory,
      status: entry.status,
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
      dueDate: _toDateTime(map['dueDate']),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => _itemFromMap(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
      notes: map['notes'] as String? ?? '',
      totalAmount: _toDouble(map['totalAmount']),
      amountPaid: _toDouble(map['amountPaid']),
      paymentHistory: _paymentsFromMap(map['paymentHistory']),
      returnHistory: _returnsFromMap(map['returnHistory']),
      status: PurchasePaymentStatus.fromValue(map['status'] as String? ?? ''),
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
      'amountPaid': amountPaid,
      'paymentHistory': paymentHistory.map(_paymentToMap).toList(),
      'returnHistory': returnHistory.map(_returnToMap).toList(),
      'status': status.firestoreValue,
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
    if (dueDate != null) {
      map['dueDate'] = dueDate;
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

  static List<PurchasePayment> _paymentsFromMap(dynamic rawPayments) {
    if (rawPayments is! List) return const [];
    return rawPayments
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (map) => PurchasePayment(
            amount: _toDouble(map['amount']),
            paidAt: _toDateTime(map['paidAt']) ?? DateTime.now(),
            method: map['method'] as String? ?? '',
            reference: map['reference'] as String? ?? '',
            notes: map['notes'] as String? ?? '',
          ),
        )
        .toList();
  }

  static List<PurchaseReturn> _returnsFromMap(dynamic rawReturns) {
    if (rawReturns is! List) return const [];
    return rawReturns
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (map) => PurchaseReturn(
            returnedAt: _toDateTime(map['returnedAt']) ?? DateTime.now(),
            items: _returnItemsFromMap(map['items']),
            reference: map['reference'] as String? ?? '',
            notes: map['notes'] as String? ?? '',
            reducesPayable: map['reducesPayable'] as bool? ?? true,
          ),
        )
        .toList();
  }

  static List<PurchaseReturnItem> _returnItemsFromMap(dynamic rawItems) {
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (map) => PurchaseReturnItem(
            productId: map['productId'] as String? ?? '',
            productName: map['productName'] as String? ?? '',
            quantity: _toDouble(map['quantity']),
            unitCost: _toDouble(map['unitCost']),
            lineTotal: _toDouble(map['lineTotal']),
          ),
        )
        .toList();
  }

  static Map<String, dynamic> _paymentToMap(PurchasePayment payment) {
    final map = <String, dynamic>{
      'amount': payment.amount,
      'paidAt': payment.paidAt,
    };
    if (payment.method.trim().isNotEmpty) {
      map['method'] = payment.method.trim();
    }
    if (payment.reference.trim().isNotEmpty) {
      map['reference'] = payment.reference.trim();
    }
    if (payment.notes.trim().isNotEmpty) {
      map['notes'] = payment.notes.trim();
    }
    return map;
  }

  static Map<String, dynamic> _returnToMap(PurchaseReturn purchaseReturn) {
    final map = <String, dynamic>{
      'returnedAt': purchaseReturn.returnedAt,
      'items': purchaseReturn.items
          .map(
            (item) => {
              'productId': item.productId,
              'productName': item.productName,
              'quantity': item.quantity,
              'unitCost': item.unitCost,
              'lineTotal': item.lineTotal,
            },
          )
          .toList(),
      'reducesPayable': purchaseReturn.reducesPayable,
    };
    if (purchaseReturn.reference.trim().isNotEmpty) {
      map['reference'] = purchaseReturn.reference.trim();
    }
    if (purchaseReturn.notes.trim().isNotEmpty) {
      map['notes'] = purchaseReturn.notes.trim();
    }
    return map;
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
