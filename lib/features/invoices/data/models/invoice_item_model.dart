import '../../domain/entities/invoice_item.dart';

class InvoiceItemModel extends InvoiceItem {
  const InvoiceItemModel({
    required super.productId,
    required super.name,
    required super.description,
    required super.hsnSac,
    required super.quantity,
    required super.unit,
    required super.rate,
    required super.gstRate,
    required super.taxableAmount,
    required super.cgstAmount,
    required super.sgstAmount,
    required super.igstAmount,
    required super.total,
    super.customFields,
  });

  factory InvoiceItemModel.fromEntity(InvoiceItem item) {
    return InvoiceItemModel(
      productId: item.productId,
      name: item.name,
      description: item.description,
      hsnSac: item.hsnSac,
      quantity: item.quantity,
      unit: item.unit,
      rate: item.rate,
      gstRate: item.gstRate,
      taxableAmount: item.taxableAmount,
      cgstAmount: item.cgstAmount,
      sgstAmount: item.sgstAmount,
      igstAmount: item.igstAmount,
      total: item.total,
      customFields: item.customFields,
    );
  }

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      hsnSac: map['hsnSac'] as String? ?? '',
      quantity: _toDouble(map['quantity']),
      unit: map['unit'] as String? ?? '',
      rate: _toDouble(map['rate']),
      gstRate: _toDouble(map['gstRate']),
      taxableAmount: _toDouble(map['taxableAmount']),
      cgstAmount: _toDouble(map['cgstAmount']),
      sgstAmount: _toDouble(map['sgstAmount']),
      igstAmount: _toDouble(map['igstAmount']),
      total: _toDouble(map['total']),
      customFields: _toStringMap(map['customFields']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'description': description,
      'hsnSac': hsnSac,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,
      'gstRate': gstRate,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'total': total,
      'customFields': customFields,
    };
  }

  static Map<String, String> _toStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, fieldValue) {
        return MapEntry(key, fieldValue?.toString() ?? '');
      });
    }
    if (value is Map) {
      return value.map((key, fieldValue) {
        return MapEntry(key.toString(), fieldValue?.toString() ?? '');
      });
    }
    return {};
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
