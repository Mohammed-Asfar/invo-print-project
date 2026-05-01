import '../entities/auth_result.dart';

abstract class AuthRepository {
  Future<AuthResult?> currentSession();
  Future<AuthResult> signIn({required String email, required String password});
  Future<void> signOut();
}
