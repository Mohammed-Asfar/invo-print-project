import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.billingAddress,
    required this.shippingAddress,
    required this.gstin,
    required this.state,
    required this.defaultDiscountType,
    required this.defaultDiscountValue,
    required this.loyaltyEnabled,
    required this.loyaltyPointsBalance,
    required this.lifetimePointsEarned,
    required this.lifetimePointsRedeemed,
    required this.totalBilled,
    required this.totalPaid,
    required this.outstandingAmount,
    required this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastInvoiceAt,
  });

  factory Customer.empty() {
    final now = DateTime.now();
    return Customer(
      id: '',
      name: '',
      phone: '',
      email: '',
      billingAddress: '',
      shippingAddress: '',
      gstin: '',
      state: '',
      defaultDiscountType: 'none',
      defaultDiscountValue: 0,
      loyaltyEnabled: true,
      loyaltyPointsBalance: 0,
      lifetimePointsEarned: 0,
      lifetimePointsRedeemed: 0,
      totalBilled: 0,
      totalPaid: 0,
      outstandingAmount: 0,
      notes: '',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String name;
  final String phone;
  final String email;
  final String billingAddress;
  final String shippingAddress;
  final String gstin;
  final String state;
  final String defaultDiscountType;
  final double defaultDiscountValue;
  final bool loyaltyEnabled;
  final int loyaltyPointsBalance;
  final int lifetimePointsEarned;
  final int lifetimePointsRedeemed;
  final double totalBilled;
  final double totalPaid;
  final double outstandingAmount;
  final DateTime? lastInvoiceAt;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    email,
    billingAddress,
    shippingAddress,
    gstin,
    state,
    defaultDiscountType,
    defaultDiscountValue,
    loyaltyEnabled,
    loyaltyPointsBalance,
    lifetimePointsEarned,
    lifetimePointsRedeemed,
    totalBilled,
    totalPaid,
    outstandingAmount,
    lastInvoiceAt,
    notes,
    isActive,
    createdAt,
    updatedAt,
  ];
}
