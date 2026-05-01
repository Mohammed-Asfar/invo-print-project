import '../../../../core/firebase/control_firestore_rest_client.dart';

class CustomerSetupInput {
  const CustomerSetupInput({
    required this.userUid,
    required this.email,
    required this.displayName,
    required this.customerId,
    required this.licenseId,
    required this.allowedDevices,
    required this.projectId,
    required this.apiKey,
    required this.authDomain,
    required this.storageBucket,
    required this.messagingSenderId,
    required this.appId,
  });

  final String userUid;
  final String email;
  final String displayName;
  final String customerId;
  final String licenseId;
  final int allowedDevices;
  final String projectId;
  final String apiKey;
  final String authDomain;
  final String storageBucket;
  final String messagingSenderId;
  final String appId;
}

class AdminSetupRepository {
  AdminSetupRepository(this._controlFirestore);

  final ControlFirestoreRestClient _controlFirestore;

  Future<void> createOrUpdateCustomerSetup(CustomerSetupInput input) async {
    final now = DateTime.now().toUtc();

    await _controlFirestore.setDocument('users', input.userUid, {
      'email': input.email,
      'customerId': input.customerId,
      'licenseId': input.licenseId,
      'displayName': input.displayName,
      'role': 'customer',
      'updatedAt': now,
      'createdAt': now,
    });

    await _controlFirestore.setDocument('licenses', input.licenseId, {
      'customerId': input.customerId,
      'status': 'active',
      'allowedDevices': input.allowedDevices,
      'activatedDevices': 0,
      'purchaseAmount': 6000,
      'currencyCode': 'INR',
      'supportStatus': 'active',
      'updatedAt': now,
      'createdAt': now,
    });

    await _controlFirestore.setDocument('customerConfigs', input.customerId, {
      'projectId': input.projectId,
      'apiKey': input.apiKey,
      'authDomain': input.authDomain,
      'storageBucket': input.storageBucket,
      'messagingSenderId': input.messagingSenderId,
      'appId': input.appId,
      'enabled': true,
      'configVersion': 1,
      'updatedAt': now,
      'createdAt': now,
    });
  }
}
