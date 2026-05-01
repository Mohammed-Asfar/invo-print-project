import 'package:equatable/equatable.dart';

import 'app_user.dart';
import 'customer_firebase_config.dart';
import 'license.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.license,
    required this.customerConfig,
  });

  final AppUser user;
  final License license;
  final CustomerFirebaseConfig customerConfig;

  @override
  List<Object?> get props => [user, license, customerConfig];
}
