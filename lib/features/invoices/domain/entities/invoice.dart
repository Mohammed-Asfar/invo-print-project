import 'package:equatable/equatable.dart';

import 'invoice_item.dart';

class Invoice extends Equatable {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceSequence,
    required this.financialYear,
    required this.invoiceDate,
    required this.dueDate,
    required this.customerId,
    required this.customerSnapshot,
    required this.companySnapshot,
    required this.items,
    required this.taxMode,
    required this.status,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountTotal,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.roundOffEnabled,
    required this.roundOffAmount,
    required this.grandTotal,
    required this.amountPaid,
    required this.notes,
    required this.terms,
    required this.loyaltyPointsAwarded,
    required this.pointsEarned,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
  });

  final String id;
  final String invoiceNumber;
  final int invoiceSequence;
  final String financialYear;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String customerId;
  final Map<String, dynamic> customerSnapshot;
  final Map<String, dynamic> companySnapshot;
  final List<InvoiceItem> items;
  final TaxMode taxMode;
  final InvoiceStatus status;
  final double subtotal;
  final String discountType;
  final double discountValue;
  final double discountTotal;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final bool roundOffEnabled;
  final double roundOffAmount;
  final double grandTotal;
  final double amountPaid;
  final DateTime? paidAt;
  final String notes;
  final String terms;
  final bool loyaltyPointsAwarded;
  final int pointsEarned;
  final DateTime createdAt;
  final DateTime updatedAt;

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    int? invoiceSequence,
    String? financialYear,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? customerId,
    Map<String, dynamic>? customerSnapshot,
    Map<String, dynamic>? companySnapshot,
    List<InvoiceItem>? items,
    TaxMode? taxMode,
    InvoiceStatus? status,
    double? subtotal,
    String? discountType,
    double? discountValue,
    double? discountTotal,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    bool? roundOffEnabled,
    double? roundOffAmount,
    double? grandTotal,
    double? amountPaid,
    DateTime? paidAt,
    bool clearPaidAt = false,
    String? notes,
    String? terms,
    bool? loyaltyPointsAwarded,
    int? pointsEarned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceSequence: invoiceSequence ?? this.invoiceSequence,
      financialYear: financialYear ?? this.financialYear,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      customerId: customerId ?? this.customerId,
      customerSnapshot: customerSnapshot ?? this.customerSnapshot,
      companySnapshot: companySnapshot ?? this.companySnapshot,
      items: items ?? this.items,
      taxMode: taxMode ?? this.taxMode,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountTotal: discountTotal ?? this.discountTotal,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      roundOffEnabled: roundOffEnabled ?? this.roundOffEnabled,
      roundOffAmount: roundOffAmount ?? this.roundOffAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      amountPaid: amountPaid ?? this.amountPaid,
      paidAt: clearPaidAt ? null : paidAt ?? this.paidAt,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      loyaltyPointsAwarded: loyaltyPointsAwarded ?? this.loyaltyPointsAwarded,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    invoiceSequence,
    financialYear,
    invoiceDate,
    dueDate,
    customerId,
    customerSnapshot,
    companySnapshot,
    items,
    taxMode,
    status,
    subtotal,
    discountType,
    discountValue,
    discountTotal,
    taxableAmount,
    cgstAmount,
    sgstAmount,
    igstAmount,
    roundOffEnabled,
    roundOffAmount,
    grandTotal,
    amountPaid,
    paidAt,
    notes,
    terms,
    loyaltyPointsAwarded,
    pointsEarned,
    createdAt,
    updatedAt,
  ];
}

enum TaxMode {
  none,
  cgstSgst,
  igst;

  String get label => switch (this) {
    TaxMode.none => 'No GST',
    TaxMode.cgstSgst => 'CGST + SGST',
    TaxMode.igst => 'IGST',
  };

  String get firestoreValue => switch (this) {
    TaxMode.none => 'none',
    TaxMode.cgstSgst => 'cgst_sgst',
    TaxMode.igst => 'igst',
  };

  static TaxMode fromValue(String value) {
    return switch (value) {
      'cgst_sgst' => TaxMode.cgstSgst,
      'igst' => TaxMode.igst,
      _ => TaxMode.none,
    };
  }
}

enum InvoiceStatus {
  draft,
  unpaid,
  paid,
  cancelled;

  String get label => switch (this) {
    InvoiceStatus.draft => 'Draft',
    InvoiceStatus.unpaid => 'Unpaid',
    InvoiceStatus.paid => 'Paid',
    InvoiceStatus.cancelled => 'Cancelled',
  };

  String get firestoreValue => switch (this) {
    InvoiceStatus.draft => 'draft',
    InvoiceStatus.unpaid => 'unpaid',
    InvoiceStatus.paid => 'paid',
    InvoiceStatus.cancelled => 'cancelled',
  };

  static InvoiceStatus fromValue(String value) {
    return switch (value) {
      'paid' => InvoiceStatus.paid,
      'cancelled' => InvoiceStatus.cancelled,
      'draft' => InvoiceStatus.draft,
      _ => InvoiceStatus.unpaid,
    };
  }
}
