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
  final double grandTotal;
  final double amountPaid;
  final DateTime? paidAt;
  final String notes;
  final String terms;
  final bool loyaltyPointsAwarded;
  final int pointsEarned;
  final DateTime createdAt;
  final DateTime updatedAt;

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
