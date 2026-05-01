import 'package:equatable/equatable.dart';

import 'admin_session.dart';
import 'auth_session.dart';

sealed class AuthResult extends Equatable {
  const AuthResult();
}

class CustomerAuthResult extends AuthResult {
  const CustomerAuthResult(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

class AdminAuthResult extends AuthResult {
  const AdminAuthResult(this.session);

  final AdminSession session;

  @override
  List<Object?> get props => [session];
}
