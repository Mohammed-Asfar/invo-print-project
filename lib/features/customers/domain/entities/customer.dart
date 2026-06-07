import 'package:equatable/equatable.dart';

enum CustomerFollowUpStatus {
  none,
  pending,
  waiting,
  resolved;

  String get label => switch (this) {
    CustomerFollowUpStatus.none => 'No follow-up',
    CustomerFollowUpStatus.pending => 'Needs follow-up',
    CustomerFollowUpStatus.waiting => 'Waiting on customer',
    CustomerFollowUpStatus.resolved => 'Resolved',
  };

  String get firestoreValue => switch (this) {
    CustomerFollowUpStatus.none => 'none',
    CustomerFollowUpStatus.pending => 'pending',
    CustomerFollowUpStatus.waiting => 'waiting',
    CustomerFollowUpStatus.resolved => 'resolved',
  };

  static CustomerFollowUpStatus fromValue(String value) => switch (value) {
    'pending' => CustomerFollowUpStatus.pending,
    'waiting' => CustomerFollowUpStatus.waiting,
    'resolved' => CustomerFollowUpStatus.resolved,
    _ => CustomerFollowUpStatus.none,
  };
}

class CustomerFollowUpHistoryEntry extends Equatable {
  const CustomerFollowUpHistoryEntry({
    required this.status,
    required this.contactedAt,
    this.outcome = '',
    this.note = '',
    this.nextFollowUpDate,
    this.promisedPaymentDate,
  });

  final CustomerFollowUpStatus status;
  final DateTime contactedAt;
  final String outcome;
  final String note;
  final DateTime? nextFollowUpDate;
  final DateTime? promisedPaymentDate;

  @override
  List<Object?> get props => [
    status,
    contactedAt,
    outcome,
    note,
    nextFollowUpDate,
    promisedPaymentDate,
  ];
}

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
    required this.defaultInvoiceTerms,
    this.followUpStatus = CustomerFollowUpStatus.none,
    this.lastContactedAt,
    this.nextFollowUpDate,
    this.promisedPaymentDate,
    this.followUpNotes = '',
    this.followUpHistory = const [],
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.customFields = const {},
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
      defaultInvoiceTerms: '',
      followUpStatus: CustomerFollowUpStatus.none,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      customFields: {},
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
  final String defaultInvoiceTerms;
  final CustomerFollowUpStatus followUpStatus;
  final DateTime? lastContactedAt;
  final DateTime? nextFollowUpDate;
  final DateTime? promisedPaymentDate;
  final String followUpNotes;
  final List<CustomerFollowUpHistoryEntry> followUpHistory;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, String> customFields;

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? billingAddress,
    String? shippingAddress,
    String? gstin,
    String? state,
    String? defaultDiscountType,
    double? defaultDiscountValue,
    bool? loyaltyEnabled,
    int? loyaltyPointsBalance,
    int? lifetimePointsEarned,
    int? lifetimePointsRedeemed,
    double? totalBilled,
    double? totalPaid,
    double? outstandingAmount,
    DateTime? lastInvoiceAt,
    bool clearLastInvoiceAt = false,
    String? notes,
    String? defaultInvoiceTerms,
    CustomerFollowUpStatus? followUpStatus,
    DateTime? lastContactedAt,
    bool clearLastContactedAt = false,
    DateTime? nextFollowUpDate,
    bool clearNextFollowUpDate = false,
    DateTime? promisedPaymentDate,
    bool clearPromisedPaymentDate = false,
    String? followUpNotes,
    List<CustomerFollowUpHistoryEntry>? followUpHistory,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? customFields,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      gstin: gstin ?? this.gstin,
      state: state ?? this.state,
      defaultDiscountType: defaultDiscountType ?? this.defaultDiscountType,
      defaultDiscountValue: defaultDiscountValue ?? this.defaultDiscountValue,
      loyaltyEnabled: loyaltyEnabled ?? this.loyaltyEnabled,
      loyaltyPointsBalance: loyaltyPointsBalance ?? this.loyaltyPointsBalance,
      lifetimePointsEarned: lifetimePointsEarned ?? this.lifetimePointsEarned,
      lifetimePointsRedeemed:
          lifetimePointsRedeemed ?? this.lifetimePointsRedeemed,
      totalBilled: totalBilled ?? this.totalBilled,
      totalPaid: totalPaid ?? this.totalPaid,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      lastInvoiceAt: clearLastInvoiceAt
          ? null
          : lastInvoiceAt ?? this.lastInvoiceAt,
      notes: notes ?? this.notes,
      defaultInvoiceTerms: defaultInvoiceTerms ?? this.defaultInvoiceTerms,
      followUpStatus: followUpStatus ?? this.followUpStatus,
      lastContactedAt: clearLastContactedAt
          ? null
          : lastContactedAt ?? this.lastContactedAt,
      nextFollowUpDate: clearNextFollowUpDate
          ? null
          : nextFollowUpDate ?? this.nextFollowUpDate,
      promisedPaymentDate: clearPromisedPaymentDate
          ? null
          : promisedPaymentDate ?? this.promisedPaymentDate,
      followUpNotes: followUpNotes ?? this.followUpNotes,
      followUpHistory: followUpHistory ?? this.followUpHistory,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customFields: customFields ?? this.customFields,
    );
  }

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
    defaultInvoiceTerms,
    followUpStatus,
    lastContactedAt,
    nextFollowUpDate,
    promisedPaymentDate,
    followUpNotes,
    followUpHistory,
    isActive,
    createdAt,
    updatedAt,
    customFields,
  ];
}
