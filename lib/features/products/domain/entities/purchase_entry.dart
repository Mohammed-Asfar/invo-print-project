import 'package:equatable/equatable.dart';

class PurchaseEntry extends Equatable {
  const PurchaseEntry({
    required this.id,
    required this.entryNumber,
    required this.supplierId,
    required this.supplierName,
    required this.billReference,
    required this.purchaseDate,
    this.dueDate,
    required this.items,
    required this.notes,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentHistory,
    this.returnHistory = const [],
    required this.status,
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
  final DateTime? dueDate;
  final List<PurchaseEntryItem> items;
  final String notes;
  final double totalAmount;
  final double amountPaid;
  final List<PurchasePayment> paymentHistory;
  final List<PurchaseReturn> returnHistory;
  final PurchasePaymentStatus status;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get returnedAmount {
    final amount = returnHistory
        .where((entry) => entry.reducesPayable)
        .fold<double>(0, (sum, entry) => sum + entry.totalAmount);
    return double.parse(amount.toStringAsFixed(2));
  }

  double get payableAmount {
    final payable = totalAmount - returnedAmount;
    return payable < 0 ? 0 : double.parse(payable.toStringAsFixed(2));
  }

  double get balanceDue {
    final balance = payableAmount - amountPaid;
    return balance < 0 ? 0 : double.parse(balance.toStringAsFixed(2));
  }

  DateTime get effectiveDueDate => dueDate ?? purchaseDate;

  bool isOverdue({DateTime? today}) {
    if (balanceDue <= 0) return false;
    final compareDay = _dateOnly(today ?? DateTime.now());
    return _dateOnly(effectiveDueDate).isBefore(compareDay);
  }

  int daysOverdue({DateTime? today}) {
    if (!isOverdue(today: today)) return 0;
    return _dateOnly(
      today ?? DateTime.now(),
    ).difference(_dateOnly(effectiveDueDate)).inDays;
  }

  PurchaseEntry copyWith({
    String? id,
    String? entryNumber,
    String? supplierId,
    String? supplierName,
    String? billReference,
    DateTime? purchaseDate,
    DateTime? dueDate,
    List<PurchaseEntryItem>? items,
    String? notes,
    double? totalAmount,
    double? amountPaid,
    List<PurchasePayment>? paymentHistory,
    List<PurchaseReturn>? returnHistory,
    PurchasePaymentStatus? status,
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
      dueDate: dueDate ?? this.dueDate,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      returnHistory: returnHistory ?? this.returnHistory,
      status: status ?? this.status,
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
    dueDate,
    items,
    notes,
    totalAmount,
    amountPaid,
    paymentHistory,
    returnHistory,
    status,
    isActive,
    createdAt,
    updatedAt,
  ];
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class PurchasePayment extends Equatable {
  const PurchasePayment({
    required this.amount,
    required this.paidAt,
    this.method = '',
    this.reference = '',
    this.notes = '',
  });

  final double amount;
  final DateTime paidAt;
  final String method;
  final String reference;
  final String notes;

  PurchasePayment copyWith({
    double? amount,
    DateTime? paidAt,
    String? method,
    String? reference,
    String? notes,
  }) {
    return PurchasePayment(
      amount: amount ?? this.amount,
      paidAt: paidAt ?? this.paidAt,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [amount, paidAt, method, reference, notes];
}

class PurchaseReturn extends Equatable {
  const PurchaseReturn({
    required this.returnedAt,
    required this.items,
    this.reference = '',
    this.notes = '',
    this.reducesPayable = true,
  });

  final DateTime returnedAt;
  final List<PurchaseReturnItem> items;
  final String reference;
  final String notes;
  final bool reducesPayable;

  double get totalAmount => double.parse(
    items.fold<double>(0, (sum, item) => sum + item.lineTotal).toStringAsFixed(2),
  );

  PurchaseReturn copyWith({
    DateTime? returnedAt,
    List<PurchaseReturnItem>? items,
    String? reference,
    String? notes,
    bool? reducesPayable,
  }) {
    return PurchaseReturn(
      returnedAt: returnedAt ?? this.returnedAt,
      items: items ?? this.items,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      reducesPayable: reducesPayable ?? this.reducesPayable,
    );
  }

  @override
  List<Object?> get props => [returnedAt, items, reference, notes, reducesPayable];
}

class PurchaseReturnItem extends Equatable {
  const PurchaseReturnItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
  });

  final String productId;
  final String productName;
  final double quantity;
  final double unitCost;
  final double lineTotal;

  PurchaseReturnItem copyWith({
    String? productId,
    String? productName,
    double? quantity,
    double? unitCost,
    double? lineTotal,
  }) {
    return PurchaseReturnItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }

  @override
  List<Object?> get props => [productId, productName, quantity, unitCost, lineTotal];
}

enum PurchasePaymentStatus {
  unpaid,
  partial,
  paid;

  String get firestoreValue => switch (this) {
    PurchasePaymentStatus.unpaid => 'unpaid',
    PurchasePaymentStatus.partial => 'partial',
    PurchasePaymentStatus.paid => 'paid',
  };

  String get label => switch (this) {
    PurchasePaymentStatus.unpaid => 'Unpaid',
    PurchasePaymentStatus.partial => 'Partial',
    PurchasePaymentStatus.paid => 'Paid',
  };

  static PurchasePaymentStatus fromValue(String value) {
    return switch (value) {
      'paid' => PurchasePaymentStatus.paid,
      'partial' => PurchasePaymentStatus.partial,
      _ => PurchasePaymentStatus.unpaid,
    };
  }
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
