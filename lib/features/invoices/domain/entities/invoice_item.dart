import 'package:equatable/equatable.dart';

class InvoiceItem extends Equatable {
  const InvoiceItem({
    required this.productId,
    required this.name,
    required this.description,
    required this.hsnSac,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.rateIncludingGst,
    required this.gstRate,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.total,
    this.customFields = const {},
  });

  factory InvoiceItem.empty() {
    return const InvoiceItem(
      productId: '',
      name: '',
      description: '',
      hsnSac: '',
      quantity: 1,
      unit: 'service',
      rate: 0,
      rateIncludingGst: 0,
      gstRate: 0,
      taxableAmount: 0,
      cgstAmount: 0,
      sgstAmount: 0,
      igstAmount: 0,
      total: 0,
      customFields: {},
    );
  }

  final String productId;
  final String name;
  final String description;
  final String hsnSac;
  final double quantity;
  final String unit;
  final double rate;
  final double rateIncludingGst;
  final double gstRate;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double total;
  final Map<String, String> customFields;

  InvoiceItem copyWith({
    String? productId,
    String? name,
    String? description,
    String? hsnSac,
    double? quantity,
    String? unit,
    double? rate,
    double? rateIncludingGst,
    double? gstRate,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? total,
    Map<String, String>? customFields,
  }) {
    return InvoiceItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      description: description ?? this.description,
      hsnSac: hsnSac ?? this.hsnSac,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      rateIncludingGst: rateIncludingGst ?? this.rateIncludingGst,
      gstRate: gstRate ?? this.gstRate,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      total: total ?? this.total,
      customFields: customFields ?? this.customFields,
    );
  }

  @override
  List<Object?> get props => [
    productId,
    name,
    description,
    hsnSac,
    quantity,
    unit,
    rate,
    rateIncludingGst,
    gstRate,
    taxableAmount,
    cgstAmount,
    sgstAmount,
    igstAmount,
    total,
    customFields,
  ];
}
