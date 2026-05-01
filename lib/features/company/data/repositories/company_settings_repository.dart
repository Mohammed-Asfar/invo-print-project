import '../../../../core/firebase/customer_firestore_rest_client.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/company_profile.dart';
import '../models/app_settings_model.dart';
import '../models/company_profile_model.dart';

class CompanySettingsRepository {
  CompanySettingsRepository(this._firestore);

  final CustomerFirestoreRestClient _firestore;

  Future<CompanyProfile> fetchCompanyProfile() async {
    final data = await _firestore.getDocument('company', 'profile');
    if (data == null) return CompanyProfile.empty();
    return CompanyProfileModel.fromMap(data);
  }

  Future<AppSettings> fetchAppSettings() async {
    final data = await _firestore.getDocument('settings', 'app');
    if (data == null) return AppSettings.initial();
    return AppSettingsModel.fromMap(data);
  }

  Future<void> saveCompanyProfile(CompanyProfile profile) {
    final model = CompanyProfileModel.fromEntity(profile);
    return _firestore.setDocument('company', 'profile', model.toMap());
  }

  Future<void> saveAppSettings(AppSettings settings) {
    final model = AppSettingsModel.fromEntity(settings);
    return _firestore.setDocument('settings', 'app', model.toMap());
  }
}
