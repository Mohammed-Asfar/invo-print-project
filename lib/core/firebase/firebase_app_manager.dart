import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import '../../features/auth/domain/entities/customer_firebase_config.dart';
import '../errors/app_exception.dart';

class FirebaseAppManager {
  FirebaseApp? _controlApp;
  FirebaseApp? _customerApp;
  CustomerFirebaseConfig? _customerConfig;

  Future<void> initializeControlApp() async {
    if (_controlApp != null) return;

    try {
      _controlApp = Firebase.app();
    } on FirebaseException {
      _controlApp = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<void> initializeCustomerApp(CustomerFirebaseConfig config) async {
    final appName = 'customer_${config.projectId}';
    _customerConfig = config;

    try {
      _customerApp = Firebase.app(appName);
      return;
    } on FirebaseException {
      _customerApp = await Firebase.initializeApp(
        name: appName,
        options: FirebaseOptions(
          apiKey: config.apiKey,
          authDomain: config.authDomain,
          projectId: config.projectId,
          storageBucket: config.storageBucket,
          messagingSenderId: config.messagingSenderId,
          appId: config.appId,
        ),
      );
    }
  }

  FirebaseAuth get controlAuth =>
      FirebaseAuth.instanceFor(app: _requireControlApp());

  FirebaseAuth get customerAuth =>
      FirebaseAuth.instanceFor(app: _requireCustomerApp());

  String get customerProjectId {
    final projectId = _customerConfig?.projectId;
    if (projectId == null || projectId.isEmpty) {
      throw const AppException('Customer Firebase project is not available.');
    }
    return projectId;
  }

  FirebaseApp _requireControlApp() {
    final app = _controlApp;
    if (app == null) {
      throw const AppException('Control Firebase has not been initialized.');
    }
    return app;
  }

  FirebaseApp _requireCustomerApp() {
    final app = _customerApp;
    if (app == null) {
      throw const AppException('Customer Firebase has not been initialized.');
    }
    return app;
  }
}
