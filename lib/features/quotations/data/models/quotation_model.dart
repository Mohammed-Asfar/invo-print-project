import '../../../invoices/data/models/invoice_item_model.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../domain/entities/quotation.dart';

class QuotationModel extends Quotation {
  const QuotationModel({
    required super.id,
    required super.quotationNumber,
    required super.quotationSequence,
    required super.financialYear,
    required super.quotationDate,
    required super.validUntil,
    required super.customerId,
    required super.customerSnapshot,
    required super.companySnapshot,
    required super.items,
    required super.taxMode,
    required super.status,
    required super.subtotal,
    required super.discountType,
    required super.discountValue,
    required super.discountTotal,
    required super.extraCharges,
    required super.extraChargeTotal,
    required super.taxableAmount,
    required super.cgstAmount,
    required super.sgstAmount,
    required super.igstAmount,
    required super.roundOffEnabled,
    required super.roundOffAmount,
    required super.grandTotal,
    required super.notes,
    required super.terms,
    required super.createdAt,
    required super.updatedAt,
    super.convertedInvoiceId,
    super.convertedAt,
  });

  factory QuotationModel.fromEntity(Quotation quotation) {
    return QuotationModel(
      id: quotation.id,
      quotationNumber: quotation.quotationNumber,
      quotationSequence: quotation.quotationSequence,
      financialYear: quotation.financialYear,
      quotationDate: quotation.quotationDate,
      validUntil: quotation.validUntil,
      customerId: quotation.customerId,
      customerSnapshot: quotation.customerSnapshot,
      companySnapshot: quotation.companySnapshot,
      items: quotation.items,
      taxMode: quotation.taxMode,
      status: quotation.status,
      subtotal: quotation.subtotal,
      discountType: quotation.discountType,
      discountValue: quotation.discountValue,
      discountTotal: quotation.discountTotal,
      extraCharges: quotation.extraCharges,
      extraChargeTotal: quotation.extraChargeTotal,
      taxableAmount: quotation.taxableAmount,
      cgstAmount: quotation.cgstAmount,
      sgstAmount: quotation.sgstAmount,
      igstAmount: quotation.igstAmount,
      roundOffEnabled: quotation.roundOffEnabled,
      roundOffAmount: quotation.roundOffAmount,
      grandTotal: quotation.grandTotal,
      notes: quotation.notes,
      terms: quotation.terms,
      convertedInvoiceId: quotation.convertedInvoiceId,
      convertedAt: quotation.convertedAt,
      createdAt: quotation.createdAt,
      updatedAt: quotation.updatedAt,
    );
  }

  factory QuotationModel.fromMap(String id, Map<String, dynamic> map) {
    final items = (map['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(InvoiceItemModel.fromMap)
        .toList();
    return QuotationModel(
      id: id,
      quotationNumber: map['quotationNumber'] as String? ?? '',
      quotationSequence: _toInt(map['quotationSequence']),
      financialYear: map['financialYear'] as String? ?? '',
      quotationDate: _toDateTime(map['quotationDate']) ?? DateTime.now(),
      validUntil: _toDateTime(map['validUntil']) ?? DateTime.now(),
      customerId: map['customerId'] as String? ?? '',
      customerSnapshot: _toMap(map['customerSnapshot']),
      companySnapshot: _toMap(map['companySnapshot']),
      items: items,
      taxMode: TaxMode.fromValue(map['taxMode'] as String? ?? 'none'),
      status: QuotationStatus.fromValue(map['status'] as String? ?? 'draft'),
      subtotal: _toDouble(map['subtotal']),
      discountType: map['discountType'] as String? ?? 'none',
      discountValue: _toDouble(map['discountValue']),
      discountTotal: _toDouble(map['discountTotal']),
      extraCharges: _toChargeList(map['extraCharges']),
      extraChargeTotal: _toDouble(map['extraChargeTotal']),
      taxableAmount: _toDouble(map['taxableAmount']),
      cgstAmount: _toDouble(map['cgstAmount']),
      sgstAmount: _toDouble(map['sgstAmount']),
      igstAmount: _toDouble(map['igstAmount']),
      roundOffEnabled: map['roundOffEnabled'] as bool? ?? false,
      roundOffAmount: _toDouble(map['roundOffAmount']),
      grandTotal: _toDouble(map['grandTotal']),
      notes: map['notes'] as String? ?? '',
      terms: map['terms'] as String? ?? '',
      convertedInvoiceId: map['convertedInvoiceId'] as String? ?? '',
      convertedAt: _toDateTime(map['convertedAt']),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'quotationNumber': quotationNumber,
      'quotationSequence': quotationSequence,
      'financialYear': financialYear,
      'quotationDate': quotationDate,
      'validUntil': validUntil,
      'customerId': customerId,
      'customerSnapshot': customerSnapshot,
      'companySnapshot': companySnapshot,
      'items': items
          .map((item) => InvoiceItemModel.fromEntity(item).toMap())
          .toList(),
      'taxMode': taxMode.firestoreValue,
      'status': status.firestoreValue,
      'subtotal': subtotal,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'roundOffEnabled': roundOffEnabled,
      'roundOffAmount': roundOffAmount,
      'grandTotal': grandTotal,
      'notes': notes,
      'terms': terms,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (discountType != 'none') map['discountType'] = discountType;
    if (discountValue != 0) map['discountValue'] = discountValue;
    if (discountTotal != 0) map['discountTotal'] = discountTotal;
    if (extraCharges.isNotEmpty) {
      map['extraCharges'] = extraCharges
          .map((charge) => {'label': charge.label, 'amount': charge.amount})
          .toList();
    }
    if (extraChargeTotal != 0) map['extraChargeTotal'] = extraChargeTotal;
    if (convertedInvoiceId.trim().isNotEmpty) {
      map['convertedInvoiceId'] = convertedInvoiceId;
    }
    if (convertedAt != null) map['convertedAt'] = convertedAt;
    return map;
  }

  Map<String, dynamic> toArchiveMap({required DateTime archivedAt}) {
    return toMap()
      ..['isActive'] = false
      ..['archivedAt'] = archivedAt
      ..['updatedAt'] = archivedAt;
  }

  static bool isDocumentActive(Map<String, dynamic> map) {
    return map['isActive'] as bool? ?? true;
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<InvoiceCharge> _toChargeList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((entry) {
      final map = Map<String, dynamic>.from(entry);
      return InvoiceCharge(
        label: map['label']?.toString() ?? '',
        amount: _toDouble(map['amount']),
      );
    }).toList();
  }
}
