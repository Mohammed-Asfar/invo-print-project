import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/admin_session.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthInitial()) {
    on<AuthSessionRequested>(_onSessionRequested);
    on<AuthSignInSubmitted>(_onSignInSubmitted);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onSessionRequested(
    AuthSessionRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final session = await _authRepository.currentSession();
      if (session == null) {
        emit(const AuthUnauthenticated());
      } else if (session is CustomerAuthResult) {
        emit(AuthAuthenticated(session.session));
      } else if (session is AdminAuthResult) {
        emit(AuthAdminAuthenticated(session.session));
      }
    } on SetupRequiredException catch (error) {
      emit(AuthSetupRequired(error.message));
    } on AppException catch (error) {
      emit(AuthFailure(error.message));
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSignInSubmitted(
    AuthSignInSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      if (result is CustomerAuthResult) {
        emit(AuthAuthenticated(result.session));
      } else if (result is AdminAuthResult) {
        emit(AuthAdminAuthenticated(result.session));
      }
    } on SetupRequiredException catch (error) {
      emit(AuthSetupRequired(error.message));
    } on AppException catch (error) {
      emit(AuthFailure(error.message));
    } catch (error) {
      emit(AuthFailure('Login failed: $error'));
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _authRepository.signOut();
    emit(const AuthUnauthenticated());
  }
}
