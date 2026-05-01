import '../../domain/entities/license.dart';

class LicenseModel extends License {
  const LicenseModel({
    required super.id,
    required super.customerId,
    required super.status,
    required super.allowedDevices,
    required super.activatedDevices,
    required super.supportStatus,
  });

  factory LicenseModel.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return LicenseModel(
      id: id,
      customerId: data['customerId'] as String? ?? '',
      status: _parseStatus(data['status'] as String?),
      allowedDevices: (data['allowedDevices'] as num?)?.toInt() ?? 1,
      activatedDevices: (data['activatedDevices'] as num?)?.toInt() ?? 0,
      supportStatus: data['supportStatus'] as String? ?? 'unknown',
    );
  }

  static LicenseStatus _parseStatus(String? value) {
    return LicenseStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => LicenseStatus.inactive,
    );
  }
}
