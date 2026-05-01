import 'package:equatable/equatable.dart';

enum LicenseStatus { active, inactive, suspended, expired }

class License extends Equatable {
  const License({
    required this.id,
    required this.customerId,
    required this.status,
    required this.allowedDevices,
    required this.activatedDevices,
    required this.supportStatus,
  });

  final String id;
  final String customerId;
  final LicenseStatus status;
  final int allowedDevices;
  final int activatedDevices;
  final String supportStatus;

  bool get isActive => status == LicenseStatus.active;
  bool get hasDeviceSlot => activatedDevices < allowedDevices;

  @override
  List<Object?> get props => [
    id,
    customerId,
    status,
    allowedDevices,
    activatedDevices,
    supportStatus,
  ];
}
