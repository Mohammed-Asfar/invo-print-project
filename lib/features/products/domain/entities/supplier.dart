import 'package:equatable/equatable.dart';

enum SupplierFollowUpStatus {
  none,
  pending,
  waiting,
  resolved;

  String get label => switch (this) {
    SupplierFollowUpStatus.none => 'No follow-up',
    SupplierFollowUpStatus.pending => 'Needs follow-up',
    SupplierFollowUpStatus.waiting => 'Waiting on supplier',
    SupplierFollowUpStatus.resolved => 'Resolved',
  };

  String get firestoreValue => switch (this) {
    SupplierFollowUpStatus.none => 'none',
    SupplierFollowUpStatus.pending => 'pending',
    SupplierFollowUpStatus.waiting => 'waiting',
    SupplierFollowUpStatus.resolved => 'resolved',
  };

  static SupplierFollowUpStatus fromValue(String value) => switch (value) {
    'pending' => SupplierFollowUpStatus.pending,
    'waiting' => SupplierFollowUpStatus.waiting,
    'resolved' => SupplierFollowUpStatus.resolved,
    _ => SupplierFollowUpStatus.none,
  };
}

class Supplier extends Equatable {
  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.address,
    required this.notes,
    this.followUpStatus = SupplierFollowUpStatus.none,
    this.lastContactedAt,
    this.nextFollowUpDate,
    this.followUpNotes = '',
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supplier.empty() {
    final now = DateTime.now();
    return Supplier(
      id: '',
      name: '',
      phone: '',
      email: '',
      gstin: '',
      address: '',
      notes: '',
      followUpStatus: SupplierFollowUpStatus.none,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String name;
  final String phone;
  final String email;
  final String gstin;
  final String address;
  final String notes;
  final SupplierFollowUpStatus followUpStatus;
  final DateTime? lastContactedAt;
  final DateTime? nextFollowUpDate;
  final String followUpNotes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? gstin,
    String? address,
    String? notes,
    SupplierFollowUpStatus? followUpStatus,
    DateTime? lastContactedAt,
    bool clearLastContactedAt = false,
    DateTime? nextFollowUpDate,
    bool clearNextFollowUpDate = false,
    String? followUpNotes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      followUpStatus: followUpStatus ?? this.followUpStatus,
      lastContactedAt: clearLastContactedAt
          ? null
          : lastContactedAt ?? this.lastContactedAt,
      nextFollowUpDate: clearNextFollowUpDate
          ? null
          : nextFollowUpDate ?? this.nextFollowUpDate,
      followUpNotes: followUpNotes ?? this.followUpNotes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    email,
    gstin,
    address,
    notes,
    followUpStatus,
    lastContactedAt,
    nextFollowUpDate,
    followUpNotes,
    isActive,
    createdAt,
    updatedAt,
  ];
}
