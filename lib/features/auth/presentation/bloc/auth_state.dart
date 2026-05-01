part of 'auth_bloc.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final AuthSession session;

  @override
  List<Object?> get props => [session];
}

class AuthAdminAuthenticated extends AuthState {
  const AuthAdminAuthenticated(this.session);

  final AdminSession session;

  @override
  List<Object?> get props => [session];
}

class AuthSetupRequired extends AuthState {
  const AuthSetupRequired(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
