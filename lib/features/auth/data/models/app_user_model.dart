import '../../domain/entities/app_user.dart';

class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.email,
    required super.customerId,
    required super.licenseId,
    required super.displayName,
  });

  factory AppUserModel.fromFirestore({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
  }) {
    return AppUserModel(
      uid: uid,
      email: email,
      customerId: data['customerId'] as String? ?? '',
      licenseId: data['licenseId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
    );
  }
}
