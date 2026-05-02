import '../../domain/entities/invoice.dart';
import 'invoice_item_model.dart';

class InvoiceModel extends Invoice {
  const InvoiceModel({
    required super.id,
    required super.invoiceNumber,
    required super.invoiceSequence,
    required super.financialYear,
    required super.invoiceDate,
    required super.dueDate,
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
    required super.taxableAmount,
    required super.cgstAmount,
    required super.sgstAmount,
    required super.igstAmount,
    required super.grandTotal,
    required super.amountPaid,
    required super.notes,
    required super.terms,
    required super.loyaltyPointsAwarded,
    required super.pointsEarned,
    required super.createdAt,
    required super.updatedAt,
    super.paidAt,
  });

  factory InvoiceModel.fromEntity(Invoice invoice) {
    return InvoiceModel(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      invoiceSequence: invoice.invoiceSequence,
      financialYear: invoice.financialYear,
      invoiceDate: invoice.invoiceDate,
      dueDate: invoice.dueDate,
      customerId: invoice.customerId,
      customerSnapshot: invoice.customerSnapshot,
      companySnapshot: invoice.companySnapshot,
      items: invoice.items,
      taxMode: invoice.taxMode,
      status: invoice.status,
      subtotal: invoice.subtotal,
      discountType: invoice.discountType,
      discountValue: invoice.discountValue,
      discountTotal: invoice.discountTotal,
      taxableAmount: invoice.taxableAmount,
      cgstAmount: invoice.cgstAmount,
      sgstAmount: invoice.sgstAmount,
      igstAmount: invoice.igstAmount,
      grandTotal: invoice.grandTotal,
      amountPaid: invoice.amountPaid,
      paidAt: invoice.paidAt,
      notes: invoice.notes,
      terms: invoice.terms,
      loyaltyPointsAwarded: invoice.loyaltyPointsAwarded,
      pointsEarned: invoice.pointsEarned,
      createdAt: invoice.createdAt,
      updatedAt: invoice.updatedAt,
    );
  }

  factory InvoiceModel.fromMap(String id, Map<String, dynamic> map) {
    final items = (map['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(InvoiceItemModel.fromMap)
        .toList();
    return InvoiceModel(
      id: id,
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      invoiceSequence: _toInt(map['invoiceSequence']),
      financialYear: map['financialYear'] as String? ?? '',
      invoiceDate: _toDateTime(map['invoiceDate']) ?? DateTime.now(),
      dueDate: _toDateTime(map['dueDate']) ?? DateTime.now(),
      customerId: map['customerId'] as String? ?? '',
      customerSnapshot: _toMap(map['customerSnapshot']),
      companySnapshot: _toMap(map['companySnapshot']),
      items: items,
      taxMode: TaxMode.fromValue(map['taxMode'] as String? ?? 'none'),
      status: InvoiceStatus.fromValue(map['status'] as String? ?? 'unpaid'),
      subtotal: _toDouble(map['subtotal']),
      discountType: map['discountType'] as String? ?? 'none',
      discountValue: _toDouble(map['discountValue']),
      discountTotal: _toDouble(map['discountTotal']),
      taxableAmount: _toDouble(map['taxableAmount']),
      cgstAmount: _toDouble(map['cgstAmount']),
      sgstAmount: _toDouble(map['sgstAmount']),
      igstAmount: _toDouble(map['igstAmount']),
      grandTotal: _toDouble(map['grandTotal']),
      amountPaid: _toDouble(map['amountPaid']),
      paidAt: _toDateTime(map['paidAt']),
      notes: map['notes'] as String? ?? '',
      terms: map['terms'] as String? ?? '',
      loyaltyPointsAwarded: map['loyaltyPointsAwarded'] as bool? ?? false,
      pointsEarned: _toInt(map['pointsEarned']),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'invoiceSequence': invoiceSequence,
      'financialYear': financialYear,
      'invoiceDate': invoiceDate,
      'dueDate': dueDate,
      'customerId': customerId,
      'customerSnapshot': customerSnapshot,
      'companySnapshot': companySnapshot,
      'items': items
          .map((item) => InvoiceItemModel.fromEntity(item).toMap())
          .toList(),
      'taxMode': taxMode.firestoreValue,
      'status': status.firestoreValue,
      'subtotal': subtotal,
      'discountType': discountType,
      'discountValue': discountValue,
      'discountTotal': discountTotal,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'grandTotal': grandTotal,
      'amountPaid': amountPaid,
      'paidAt': paidAt,
      'notes': notes,
      'terms': terms,
      'loyaltyPointsAwarded': loyaltyPointsAwarded,
      'pointsEarned': pointsEarned,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
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
}
