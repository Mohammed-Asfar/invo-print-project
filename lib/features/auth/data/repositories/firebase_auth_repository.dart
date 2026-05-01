import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/firebase/control_firestore_rest_client.dart';
import '../../../../core/firebase/firebase_app_manager.dart';
import '../../domain/entities/admin_session.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';
import '../models/customer_firebase_config_model.dart';
import '../models/license_model.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAppManager, this._controlFirestore);

  final FirebaseAppManager _firebaseAppManager;
  final ControlFirestoreRestClient _controlFirestore;

  @override
  Future<AuthResult?> currentSession() async {
    try {
      await _firebaseAppManager.initializeControlApp();
      final user = _firebaseAppManager.controlAuth.currentUser;
      if (user == null || user.email == null) return null;

      return _buildSessionForControlUser(user, user.email!, null);
    } on AppException {
      rethrow;
    } on firebase_auth.FirebaseAuthException {
      return null;
    } on FirebaseException catch (error) {
      throw AppException(_mapFirebaseError(error));
    }
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAppManager.initializeControlApp();
      final credential = await _firebaseAppManager.controlAuth
          .signInWithEmailAndPassword(email: email, password: password);

      final controlUser = credential.user;
      if (controlUser == null) {
        throw const AppException('Control login failed. Please try again.');
      }

      return _buildSessionForControlUser(controlUser, email, password);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AppException(_mapAuthError(error));
    } on FirebaseException catch (error) {
      throw AppException(_mapFirebaseError(error));
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAppManager.controlAuth.signOut(),
      _tryCustomerSignOut(),
    ]);
  }

  Future<AuthResult> _buildSessionForControlUser(
    firebase_auth.User controlUser,
    String email,
    String? customerPassword,
  ) async {
    final adminData = await _controlFirestore.getDocument(
      'admins',
      controlUser.uid,
    );
    if (adminData != null) {
      return AdminAuthResult(
        AdminSession(
          uid: controlUser.uid,
          email: email,
          displayName:
              adminData['displayName'] as String? ??
              controlUser.displayName ??
              'Admin',
        ),
      );
    }

    final userData = await _controlFirestore.getDocument(
      'users',
      controlUser.uid,
    );
    if (userData == null) {
      throw const SetupRequiredException(
        'Your account exists, but setup is not completed. Please contact support.',
      );
    }

    final appUser = AppUserModel.fromFirestore(
      uid: controlUser.uid,
      email: email,
      data: userData,
    );

    final licenseData = await _controlFirestore.getDocument(
      'licenses',
      appUser.licenseId,
    );
    if (licenseData == null) {
      throw const SetupRequiredException(
        'Your license setup is not completed. Please contact support.',
      );
    }

    final license = LicenseModel.fromFirestore(
      id: appUser.licenseId,
      data: licenseData,
    );

    if (!license.isActive) {
      throw const AppException('License is inactive. Please contact support.');
    }

    if (!license.hasDeviceSlot) {
      throw const AppException(
        'Device limit reached. Remove an old device or contact support.',
      );
    }

    final configData = await _controlFirestore.getDocument(
      'customerConfigs',
      appUser.customerId,
    );
    if (configData == null) {
      throw const SetupRequiredException(
        'Customer cloud configuration is missing. Please contact support.',
      );
    }

    final customerConfig = CustomerFirebaseConfigModel.fromFirestore(
      configData,
    );

    if (!customerConfig.enabled) {
      throw const AppException(
        'Customer cloud configuration is disabled. Please contact support.',
      );
    }

    await _firebaseAppManager.initializeCustomerApp(customerConfig);

    if (customerPassword != null) {
      await _signInToCustomerFirebase(email, customerPassword);
    }

    return CustomerAuthResult(
      AuthSession(
        user: appUser,
        license: license,
        customerConfig: customerConfig,
      ),
    );
  }

  Future<void> _signInToCustomerFirebase(String email, String password) async {
    try {
      await _firebaseAppManager.customerAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException {
      throw const AppException(
        'Business cloud login failed. Your app password may be out of sync. Please contact support.',
      );
    }
  }

  Future<void> _tryCustomerSignOut() async {
    try {
      await _firebaseAppManager.customerAuth.signOut();
    } catch (_) {
      return;
    }
  }

  String _mapAuthError(firebase_auth.FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'operation-not-allowed':
        return 'Email/password login is not enabled in Firebase Authentication.';
      case 'internal-error':
        return 'Firebase Auth returned an internal error. Check that Email/password sign-in is enabled and this user exists in Firebase Authentication.';
      default:
        return error.message == null
            ? 'Login failed. Firebase Auth error: ${error.code}.'
            : '${error.message} (${error.code})';
    }
  }

  String _mapFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore permission denied. Check Control Firebase security rules for users, licenses, customerConfigs, and admins.';
      case 'not-found':
        return 'Control Firestore database or setup document was not found.';
      case 'unavailable':
        return 'Firebase is unavailable. Please check your internet connection and try again.';
      default:
        return error.message ?? 'Firebase setup failed: ${error.code}.';
    }
  }
}
