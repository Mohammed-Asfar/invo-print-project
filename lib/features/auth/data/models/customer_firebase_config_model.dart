import '../../domain/entities/customer_firebase_config.dart';

class CustomerFirebaseConfigModel extends CustomerFirebaseConfig {
  const CustomerFirebaseConfigModel({
    required super.projectId,
    required super.apiKey,
    required super.authDomain,
    required super.storageBucket,
    required super.messagingSenderId,
    required super.appId,
    required super.enabled,
  });

  factory CustomerFirebaseConfigModel.fromFirestore(Map<String, dynamic> data) {
    return CustomerFirebaseConfigModel(
      projectId: data['projectId'] as String? ?? '',
      apiKey: data['apiKey'] as String? ?? '',
      authDomain: data['authDomain'] as String? ?? '',
      storageBucket: data['storageBucket'] as String? ?? '',
      messagingSenderId: data['messagingSenderId'] as String? ?? '',
      appId: data['appId'] as String? ?? '',
      enabled: data['enabled'] as bool? ?? false,
    );
  }
}
