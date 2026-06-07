import '../../../../core/errors/app_exception.dart';
import '../../../../core/firebase/customer_firestore_rest_client.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/company_profile.dart';
import '../models/app_settings_model.dart';
import '../models/company_profile_model.dart';

class CompanySettingsRepository {
  CompanySettingsRepository(this._firestore);

  final CustomerFirestoreRestClient _firestore;
  static const int _invoiceReservationAttempts = 5;

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
    return saveAppSettingsWithPrecondition(settings);
  }

  Future<void> saveAppSettingsWithPrecondition(
    AppSettings settings, {
    FirestoreWritePrecondition? precondition,
  }) {
    final model = AppSettingsModel.fromEntity(settings);
    return _firestore.setDocument(
      'settings',
      'app',
      model.toMap(),
      precondition: precondition,
    );
  }

  Future<InvoiceNumberReservation> reserveNextInvoiceNumber({
    AppSettings? fallbackSettings,
  }) async {
    for (var attempt = 0; attempt < _invoiceReservationAttempts; attempt++) {
      final snapshot = await _firestore.getDocumentSnapshot('settings', 'app');
      final currentSettings = snapshot == null
          ? (fallbackSettings ?? AppSettings.initial())
          : AppSettingsModel.fromMap(snapshot.data);
      final updatedSettings = _incrementInvoiceNumber(currentSettings);
      final precondition = snapshot == null
          ? const FirestoreWritePrecondition.mustNotExist()
          : FirestoreWritePrecondition(updateTime: snapshot.updateTime);
      try {
        await saveAppSettingsWithPrecondition(
          updatedSettings,
          precondition: precondition,
        );
        return InvoiceNumberReservation(
          reservedSequence: currentSettings.invoiceNextNumber,
          settingsBeforeReservation: currentSettings,
          updatedSettings: updatedSettings,
        );
      } on AppException catch (error) {
        if (_isWriteConflict(error) &&
            attempt < _invoiceReservationAttempts - 1) {
          continue;
        }
        rethrow;
      }
    }
    throw const AppException(
      'Invoice number could not be reserved right now. Please try again.',
    );
  }

  Future<QuotationNumberReservation> reserveNextQuotationNumber({
    AppSettings? fallbackSettings,
  }) async {
    for (var attempt = 0; attempt < _invoiceReservationAttempts; attempt++) {
      final snapshot = await _firestore.getDocumentSnapshot('settings', 'app');
      final currentSettings = snapshot == null
          ? (fallbackSettings ?? AppSettings.initial())
          : AppSettingsModel.fromMap(snapshot.data);
      final updatedSettings = _incrementQuotationNumber(currentSettings);
      final precondition = snapshot == null
          ? const FirestoreWritePrecondition.mustNotExist()
          : FirestoreWritePrecondition(updateTime: snapshot.updateTime);
      try {
        await saveAppSettingsWithPrecondition(
          updatedSettings,
          precondition: precondition,
        );
        return QuotationNumberReservation(
          reservedSequence: currentSettings.quotationNextNumber,
          settingsBeforeReservation: currentSettings,
          updatedSettings: updatedSettings,
        );
      } on AppException catch (error) {
        if (_isWriteConflict(error) &&
            attempt < _invoiceReservationAttempts - 1) {
          continue;
        }
        rethrow;
      }
    }
    throw const AppException(
      'Quotation number could not be reserved right now. Please try again.',
    );
  }

  bool _isWriteConflict(AppException error) {
    final message = error.message.toUpperCase();
    return message.contains('FAILED_PRECONDITION') ||
        message.contains('ABORTED') ||
        message.contains('409') ||
        message.contains('412');
  }

  AppSettings _incrementInvoiceNumber(AppSettings settings) {
    return settings.copyWith(
      invoiceNextNumber: settings.invoiceNextNumber + 1,
      updatedAt: DateTime.now(),
    );
  }

  AppSettings _incrementQuotationNumber(AppSettings settings) {
    return settings.copyWith(
      quotationNextNumber: settings.quotationNextNumber + 1,
      updatedAt: DateTime.now(),
    );
  }
}

class InvoiceNumberReservation {
  const InvoiceNumberReservation({
    required this.reservedSequence,
    required this.settingsBeforeReservation,
    required this.updatedSettings,
  });

  final int reservedSequence;
  final AppSettings settingsBeforeReservation;
  final AppSettings updatedSettings;
}

class QuotationNumberReservation {
  const QuotationNumberReservation({
    required this.reservedSequence,
    required this.settingsBeforeReservation,
    required this.updatedSettings,
  });

  final int reservedSequence;
  final AppSettings settingsBeforeReservation;
  final AppSettings updatedSettings;
}
