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
    required super.extraCharges,
    required super.extraChargeTotal,
    required super.taxableAmount,
    required super.cgstAmount,
    required super.sgstAmount,
    required super.igstAmount,
    required super.roundOffEnabled,
    required super.roundOffAmount,
    required super.grandTotal,
    required super.amountPaid,
    required super.balanceDue,
    required super.notes,
    required super.terms,
    required super.paymentHistory,
    required super.loyaltyPointsAwarded,
    required super.pointsEarned,
    required super.createdAt,
    required super.updatedAt,
    super.creditNotes,
    super.creditTotal,
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
      extraCharges: invoice.extraCharges,
      extraChargeTotal: invoice.extraChargeTotal,
      taxableAmount: invoice.taxableAmount,
      cgstAmount: invoice.cgstAmount,
      sgstAmount: invoice.sgstAmount,
      igstAmount: invoice.igstAmount,
      roundOffEnabled: invoice.roundOffEnabled,
      roundOffAmount: invoice.roundOffAmount,
      grandTotal: invoice.grandTotal,
      amountPaid: invoice.amountPaid,
      balanceDue: invoice.balanceDue,
      creditTotal: invoice.creditTotal,
      paidAt: invoice.paidAt,
      notes: invoice.notes,
      terms: invoice.terms,
      paymentHistory: invoice.paymentHistory,
      creditNotes: invoice.creditNotes,
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
      extraCharges: _toChargeList(map['extraCharges']),
      extraChargeTotal: _toDouble(map['extraChargeTotal']),
      taxableAmount: _toDouble(map['taxableAmount']),
      cgstAmount: _toDouble(map['cgstAmount']),
      sgstAmount: _toDouble(map['sgstAmount']),
      igstAmount: _toDouble(map['igstAmount']),
      roundOffEnabled: map['roundOffEnabled'] as bool? ?? false,
      roundOffAmount: _toDouble(map['roundOffAmount']),
      grandTotal: _toDouble(map['grandTotal']),
      amountPaid: _toDouble(map['amountPaid']),
      balanceDue: _toDouble(map['balanceDue']),
      creditTotal: _toDouble(map['creditTotal']),
      paidAt: _toDateTime(map['paidAt']),
      notes: map['notes'] as String? ?? '',
      terms: map['terms'] as String? ?? '',
      paymentHistory: _toPaymentHistory(map['paymentHistory']),
      creditNotes: _toCreditNotes(map['creditNotes']),
      loyaltyPointsAwarded: map['loyaltyPointsAwarded'] as bool? ?? false,
      pointsEarned: _toInt(map['pointsEarned']),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
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
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'roundOffEnabled': roundOffEnabled,
      'roundOffAmount': roundOffAmount,
      'grandTotal': grandTotal,
      'balanceDue': balanceDue,
      'notes': notes,
      'terms': terms,
      'loyaltyPointsAwarded': loyaltyPointsAwarded,
      'pointsEarned': pointsEarned,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (discountType != 'none') {
      map['discountType'] = discountType;
    }
    if (discountValue != 0) {
      map['discountValue'] = discountValue;
    }
    if (discountTotal != 0) {
      map['discountTotal'] = discountTotal;
    }
    if (extraCharges.isNotEmpty) {
      map['extraCharges'] = extraCharges
          .map((charge) => {'label': charge.label, 'amount': charge.amount})
          .toList();
    }
    if (extraChargeTotal != 0) {
      map['extraChargeTotal'] = extraChargeTotal;
    }
    if (amountPaid != 0) {
      map['amountPaid'] = amountPaid;
    }
    if (paidAt != null) {
      map['paidAt'] = paidAt;
    }
    if (paymentHistory.isNotEmpty) {
      map['paymentHistory'] = paymentHistory
          .map(
            (payment) => {
              'amount': payment.amount,
              'paidAt': payment.paidAt,
              'method': payment.method,
              'reference': payment.reference,
              'notes': payment.notes,
            },
          )
          .toList();
    }
    if (creditTotal != 0) {
      map['creditTotal'] = creditTotal;
    }
    if (creditNotes.isNotEmpty) {
      map['creditNotes'] = creditNotes
          .map(
            (credit) => {
              'amount': credit.amount,
              'issuedAt': credit.issuedAt,
              'reason': credit.reason,
              'reference': credit.reference,
            },
          )
          .toList();
    }
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

  static List<InvoicePaymentRecord> _toPaymentHistory(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((entry) {
      final map = Map<String, dynamic>.from(entry);
      return InvoicePaymentRecord(
        amount: _toDouble(map['amount']),
        paidAt: _toDateTime(map['paidAt']) ?? DateTime.now(),
        method: map['method']?.toString() ?? '',
        reference: map['reference']?.toString() ?? '',
        notes: map['notes']?.toString() ?? '',
      );
    }).toList();
  }

  static List<InvoiceCreditNote> _toCreditNotes(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((entry) {
      final map = Map<String, dynamic>.from(entry);
      return InvoiceCreditNote(
        amount: _toDouble(map['amount']),
        issuedAt: _toDateTime(map['issuedAt']) ?? DateTime.now(),
        reason: map['reason']?.toString() ?? '',
        reference: map['reference']?.toString() ?? '',
      );
    }).toList();
  }
}
