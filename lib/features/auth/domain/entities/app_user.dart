import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.customerId,
    required this.licenseId,
    required this.displayName,
  });

  final String uid;
  final String email;
  final String customerId;
  final String licenseId;
  final String displayName;

  @override
  List<Object?> get props => [uid, email, customerId, licenseId, displayName];
}
