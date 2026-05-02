import '../../domain/entities/customer.dart';

class CustomerModel extends Customer {
  const CustomerModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.email,
    required super.billingAddress,
    required super.shippingAddress,
    required super.gstin,
    required super.state,
    required super.defaultDiscountType,
    required super.defaultDiscountValue,
    required super.loyaltyEnabled,
    required super.loyaltyPointsBalance,
    required super.lifetimePointsEarned,
    required super.lifetimePointsRedeemed,
    required super.totalBilled,
    required super.totalPaid,
    required super.outstandingAmount,
    required super.notes,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
    super.customFields,
    super.lastInvoiceAt,
  });

  factory CustomerModel.fromEntity(Customer customer) {
    return CustomerModel(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      email: customer.email,
      billingAddress: customer.billingAddress,
      shippingAddress: customer.shippingAddress,
      gstin: customer.gstin,
      state: customer.state,
      defaultDiscountType: customer.defaultDiscountType,
      defaultDiscountValue: customer.defaultDiscountValue,
      loyaltyEnabled: customer.loyaltyEnabled,
      loyaltyPointsBalance: customer.loyaltyPointsBalance,
      lifetimePointsEarned: customer.lifetimePointsEarned,
      lifetimePointsRedeemed: customer.lifetimePointsRedeemed,
      totalBilled: customer.totalBilled,
      totalPaid: customer.totalPaid,
      outstandingAmount: customer.outstandingAmount,
      lastInvoiceAt: customer.lastInvoiceAt,
      notes: customer.notes,
      isActive: customer.isActive,
      createdAt: customer.createdAt,
      updatedAt: customer.updatedAt,
      customFields: customer.customFields,
    );
  }

  factory CustomerModel.fromMap(String id, Map<String, dynamic> map) {
    final defaults = Customer.empty();
    return CustomerModel(
      id: id,
      name: map['name'] as String? ?? defaults.name,
      phone: map['phone'] as String? ?? defaults.phone,
      email: map['email'] as String? ?? defaults.email,
      billingAddress:
          map['billingAddress'] as String? ?? defaults.billingAddress,
      shippingAddress:
          map['shippingAddress'] as String? ?? defaults.shippingAddress,
      gstin: map['gstin'] as String? ?? defaults.gstin,
      state: map['state'] as String? ?? defaults.state,
      defaultDiscountType:
          map['defaultDiscountType'] as String? ?? defaults.defaultDiscountType,
      defaultDiscountValue: _toDouble(
        map['defaultDiscountValue'],
        defaults.defaultDiscountValue,
      ),
      loyaltyEnabled: map['loyaltyEnabled'] as bool? ?? defaults.loyaltyEnabled,
      loyaltyPointsBalance:
          map['loyaltyPointsBalance'] as int? ?? defaults.loyaltyPointsBalance,
      lifetimePointsEarned:
          map['lifetimePointsEarned'] as int? ?? defaults.lifetimePointsEarned,
      lifetimePointsRedeemed:
          map['lifetimePointsRedeemed'] as int? ??
          defaults.lifetimePointsRedeemed,
      totalBilled: _toDouble(map['totalBilled'], defaults.totalBilled),
      totalPaid: _toDouble(map['totalPaid'], defaults.totalPaid),
      outstandingAmount: _toDouble(
        map['outstandingAmount'],
        defaults.outstandingAmount,
      ),
      lastInvoiceAt: _toDateTime(map['lastInvoiceAt']),
      notes: map['notes'] as String? ?? defaults.notes,
      isActive: map['isActive'] as bool? ?? defaults.isActive,
      createdAt: _toDateTime(map['createdAt']) ?? defaults.createdAt,
      updatedAt: _toDateTime(map['updatedAt']) ?? defaults.updatedAt,
      customFields: _toStringMap(map['customFields']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'billingAddress': billingAddress,
      'shippingAddress': shippingAddress,
      'gstin': gstin,
      'state': state,
      'defaultDiscountType': defaultDiscountType,
      'defaultDiscountValue': defaultDiscountValue,
      'loyaltyEnabled': loyaltyEnabled,
      'loyaltyPointsBalance': loyaltyPointsBalance,
      'lifetimePointsEarned': lifetimePointsEarned,
      'lifetimePointsRedeemed': lifetimePointsRedeemed,
      'totalBilled': totalBilled,
      'totalPaid': totalPaid,
      'outstandingAmount': outstandingAmount,
      'lastInvoiceAt': lastInvoiceAt,
      'notes': notes,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
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

  static double _toDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
