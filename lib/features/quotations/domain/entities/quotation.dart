import 'package:equatable/equatable.dart';

import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/entities/invoice_item.dart';

enum QuotationStatus {
  draft,
  sent,
  accepted,
  rejected,
  converted,
  expired;

  String get label => switch (this) {
    QuotationStatus.draft => 'Draft',
    QuotationStatus.sent => 'Sent',
    QuotationStatus.accepted => 'Accepted',
    QuotationStatus.rejected => 'Rejected',
    QuotationStatus.converted => 'Converted',
    QuotationStatus.expired => 'Expired',
  };

  String get firestoreValue => switch (this) {
    QuotationStatus.draft => 'draft',
    QuotationStatus.sent => 'sent',
    QuotationStatus.accepted => 'accepted',
    QuotationStatus.rejected => 'rejected',
    QuotationStatus.converted => 'converted',
    QuotationStatus.expired => 'expired',
  };

  static QuotationStatus fromValue(String value) => switch (value) {
    'sent' => QuotationStatus.sent,
    'accepted' => QuotationStatus.accepted,
    'rejected' => QuotationStatus.rejected,
    'converted' => QuotationStatus.converted,
    'expired' => QuotationStatus.expired,
    _ => QuotationStatus.draft,
  };
}

class Quotation extends Equatable {
  const Quotation({
    required this.id,
    required this.quotationNumber,
    required this.quotationSequence,
    required this.financialYear,
    required this.quotationDate,
    required this.validUntil,
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
    required this.notes,
    required this.terms,
    required this.createdAt,
    required this.updatedAt,
    this.convertedInvoiceId = '',
    this.convertedAt,
  });

  final String id;
  final String quotationNumber;
  final int quotationSequence;
  final String financialYear;
  final DateTime quotationDate;
  final DateTime validUntil;
  final String customerId;
  final Map<String, dynamic> customerSnapshot;
  final Map<String, dynamic> companySnapshot;
  final List<InvoiceItem> items;
  final TaxMode taxMode;
  final QuotationStatus status;
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
  final String notes;
  final String terms;
  final String convertedInvoiceId;
  final DateTime? convertedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get customerName => customerSnapshot['name']?.toString().trim() ?? '';

  bool get isActive =>
      status != QuotationStatus.rejected && status != QuotationStatus.expired;

  Quotation copyWith({
    String? id,
    String? quotationNumber,
    int? quotationSequence,
    String? financialYear,
    DateTime? quotationDate,
    DateTime? validUntil,
    String? customerId,
    Map<String, dynamic>? customerSnapshot,
    Map<String, dynamic>? companySnapshot,
    List<InvoiceItem>? items,
    TaxMode? taxMode,
    QuotationStatus? status,
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
    String? notes,
    String? terms,
    String? convertedInvoiceId,
    DateTime? convertedAt,
    bool clearConvertedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Quotation(
      id: id ?? this.id,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      quotationSequence: quotationSequence ?? this.quotationSequence,
      financialYear: financialYear ?? this.financialYear,
      quotationDate: quotationDate ?? this.quotationDate,
      validUntil: validUntil ?? this.validUntil,
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
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      convertedInvoiceId: convertedInvoiceId ?? this.convertedInvoiceId,
      convertedAt: clearConvertedAt ? null : convertedAt ?? this.convertedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    quotationNumber,
    quotationSequence,
    financialYear,
    quotationDate,
    validUntil,
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
    notes,
    terms,
    convertedInvoiceId,
    convertedAt,
    createdAt,
    updatedAt,
  ];
}
