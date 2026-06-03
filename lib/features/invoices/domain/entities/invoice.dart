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
    required this.extraCharges,
    required this.extraChargeTotal,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.roundOffEnabled,
    required this.roundOffAmount,
    required this.grandTotal,
    required this.amountPaid,
    required this.balanceDue,
    required this.notes,
    required this.terms,
    required this.paymentHistory,
    required this.loyaltyPointsAwarded,
    required this.pointsEarned,
    required this.createdAt,
    required this.updatedAt,
    this.creditNotes = const [],
    this.creditTotal = 0,
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
  final List<InvoiceCharge> extraCharges;
  final double extraChargeTotal;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final bool roundOffEnabled;
  final double roundOffAmount;
  final double grandTotal;
  final double amountPaid;
  final double balanceDue;
  final double creditTotal;
  final DateTime? paidAt;
  final String notes;
  final String terms;
  final List<InvoicePaymentRecord> paymentHistory;
  final List<InvoiceCreditNote> creditNotes;
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
    List<InvoiceCharge>? extraCharges,
    double? extraChargeTotal,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    bool? roundOffEnabled,
    double? roundOffAmount,
    double? grandTotal,
    double? amountPaid,
    double? balanceDue,
    double? creditTotal,
    DateTime? paidAt,
    bool clearPaidAt = false,
    String? notes,
    String? terms,
    List<InvoicePaymentRecord>? paymentHistory,
    List<InvoiceCreditNote>? creditNotes,
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
      extraCharges: extraCharges ?? this.extraCharges,
      extraChargeTotal: extraChargeTotal ?? this.extraChargeTotal,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      roundOffEnabled: roundOffEnabled ?? this.roundOffEnabled,
      roundOffAmount: roundOffAmount ?? this.roundOffAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      amountPaid: amountPaid ?? this.amountPaid,
      balanceDue: balanceDue ?? this.balanceDue,
      creditTotal: creditTotal ?? this.creditTotal,
      paidAt: clearPaidAt ? null : paidAt ?? this.paidAt,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      creditNotes: creditNotes ?? this.creditNotes,
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
    extraCharges,
    extraChargeTotal,
    taxableAmount,
    cgstAmount,
    sgstAmount,
    igstAmount,
    roundOffEnabled,
    roundOffAmount,
    grandTotal,
    amountPaid,
    balanceDue,
    creditTotal,
    paidAt,
    notes,
    terms,
    paymentHistory,
    creditNotes,
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
  partialPaid,
  paid,
  cancelled;

  String get label => switch (this) {
    InvoiceStatus.draft => 'Draft',
    InvoiceStatus.unpaid => 'Unpaid',
    InvoiceStatus.partialPaid => 'Partial Paid',
    InvoiceStatus.paid => 'Paid',
    InvoiceStatus.cancelled => 'Cancelled',
  };

  String get firestoreValue => switch (this) {
    InvoiceStatus.draft => 'draft',
    InvoiceStatus.unpaid => 'unpaid',
    InvoiceStatus.partialPaid => 'partial_paid',
    InvoiceStatus.paid => 'paid',
    InvoiceStatus.cancelled => 'cancelled',
  };

  static InvoiceStatus fromValue(String value) {
    return switch (value) {
      'paid' => InvoiceStatus.paid,
      'partial_paid' => InvoiceStatus.partialPaid,
      'cancelled' => InvoiceStatus.cancelled,
      'draft' => InvoiceStatus.draft,
      _ => InvoiceStatus.unpaid,
    };
  }
}

class InvoiceCharge extends Equatable {
  const InvoiceCharge({required this.label, required this.amount});

  final String label;
  final double amount;

  InvoiceCharge copyWith({String? label, double? amount}) {
    return InvoiceCharge(
      label: label ?? this.label,
      amount: amount ?? this.amount,
    );
  }

  @override
  List<Object?> get props => [label, amount];
}

class InvoicePaymentRecord extends Equatable {
  const InvoicePaymentRecord({
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

  InvoicePaymentRecord copyWith({
    double? amount,
    DateTime? paidAt,
    String? method,
    String? reference,
    String? notes,
  }) {
    return InvoicePaymentRecord(
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

class InvoiceCreditNote extends Equatable {
  const InvoiceCreditNote({
    required this.amount,
    required this.issuedAt,
    required this.reason,
    this.reference = '',
  });

  final double amount;
  final DateTime issuedAt;
  final String reason;
  final String reference;

  InvoiceCreditNote copyWith({
    double? amount,
    DateTime? issuedAt,
    String? reason,
    String? reference,
  }) {
    return InvoiceCreditNote(
      amount: amount ?? this.amount,
      issuedAt: issuedAt ?? this.issuedAt,
      reason: reason ?? this.reason,
      reference: reference ?? this.reference,
    );
  }

  @override
  List<Object?> get props => [amount, issuedAt, reason, reference];
}
