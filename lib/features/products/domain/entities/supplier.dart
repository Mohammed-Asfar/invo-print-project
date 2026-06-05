import 'package:equatable/equatable.dart';

class Supplier extends Equatable {
  const Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.gstin,
    required this.address,
    required this.notes,
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
    isActive,
    createdAt,
    updatedAt,
  ];
}
