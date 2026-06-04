import 'package:equatable/equatable.dart';

class ProductInventoryEntry extends Equatable {
  const ProductInventoryEntry({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantityDelta,
    required this.balanceAfter,
    required this.createdAt,
    this.reference = '',
    this.reason = '',
    this.note = '',
  });

  final String id;
  final String productId;
  final ProductInventoryEntryType type;
  final double quantityDelta;
  final double balanceAfter;
  final DateTime createdAt;
  final String reference;
  final String reason;
  final String note;

  bool get isIncrease => quantityDelta > 0;

  ProductInventoryEntry copyWith({
    String? id,
    String? productId,
    ProductInventoryEntryType? type,
    double? quantityDelta,
    double? balanceAfter,
    DateTime? createdAt,
    String? reference,
    String? reason,
    String? note,
  }) {
    return ProductInventoryEntry(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      type: type ?? this.type,
      quantityDelta: quantityDelta ?? this.quantityDelta,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      createdAt: createdAt ?? this.createdAt,
      reference: reference ?? this.reference,
      reason: reason ?? this.reason,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    type,
    quantityDelta,
    balanceAfter,
    createdAt,
    reference,
    reason,
    note,
  ];
}

enum ProductInventoryEntryType {
  manualAdjustment,
  invoiceIssued,
  invoiceUpdated,
  invoiceCancelled,
  invoiceArchived;

  String get firestoreValue => switch (this) {
    ProductInventoryEntryType.manualAdjustment => 'manual_adjustment',
    ProductInventoryEntryType.invoiceIssued => 'invoice_issued',
    ProductInventoryEntryType.invoiceUpdated => 'invoice_updated',
    ProductInventoryEntryType.invoiceCancelled => 'invoice_cancelled',
    ProductInventoryEntryType.invoiceArchived => 'invoice_archived',
  };

  String get label => switch (this) {
    ProductInventoryEntryType.manualAdjustment => 'Manual adjustment',
    ProductInventoryEntryType.invoiceIssued => 'Invoice issued',
    ProductInventoryEntryType.invoiceUpdated => 'Invoice updated',
    ProductInventoryEntryType.invoiceCancelled => 'Invoice cancelled',
    ProductInventoryEntryType.invoiceArchived => 'Invoice archived',
  };

  static ProductInventoryEntryType fromValue(String value) {
    return switch (value) {
      'invoice_issued' => ProductInventoryEntryType.invoiceIssued,
      'invoice_updated' => ProductInventoryEntryType.invoiceUpdated,
      'invoice_cancelled' => ProductInventoryEntryType.invoiceCancelled,
      'invoice_archived' => ProductInventoryEntryType.invoiceArchived,
      _ => ProductInventoryEntryType.manualAdjustment,
    };
  }
}
