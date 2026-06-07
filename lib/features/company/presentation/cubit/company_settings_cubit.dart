import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/company_settings_repository.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/company_profile.dart';

part 'company_settings_state.dart';

class CompanySettingsCubit extends Cubit<CompanySettingsState> {
  CompanySettingsCubit(this._repository)
    : super(
        CompanySettingsState(
          profile: CompanyProfile.empty(),
          settings: AppSettings.initial(),
        ),
      );

  final CompanySettingsRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: CompanySettingsStatus.loading));
    try {
      final profile = await _repository.fetchCompanyProfile();
      final settings = await _repository.fetchAppSettings();
      emit(
        state.copyWith(
          status: CompanySettingsStatus.loaded,
          profile: profile,
          settings: settings,
          clearMessage: true,
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: CompanySettingsStatus.failure,
          message: error.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: CompanySettingsStatus.failure,
          message: 'Unable to load company settings: $error',
        ),
      );
    }
  }

  Future<void> save({
    required CompanyProfile profile,
    required AppSettings settings,
  }) async {
    emit(state.copyWith(status: CompanySettingsStatus.saving));
    try {
      final latestSettings = await _repository.fetchAppSettings();
      final userChangedInvoiceCounter =
          settings.invoiceNextNumber != state.settings.invoiceNextNumber;
      final now = DateTime.now();
      final savedProfile = CompanyProfile(
        businessName: profile.businessName,
        legalName: profile.legalName,
        gstin: profile.gstin,
        pan: profile.pan,
        email: profile.email,
        phone: profile.phone,
        website: profile.website,
        addressLine1: profile.addressLine1,
        addressLine2: profile.addressLine2,
        city: profile.city,
        state: profile.state,
        pincode: profile.pincode,
        country: profile.country,
        bankName: profile.bankName,
        bankAccountName: profile.bankAccountName,
        bankAccountNumber: profile.bankAccountNumber,
        ifscCode: profile.ifscCode,
        upiId: profile.upiId,
        defaultInvoiceTerms: profile.defaultInvoiceTerms,
        defaultQuotationTerms: profile.defaultQuotationTerms,
        logoBase64: profile.logoBase64,
        paymentQrBase64: profile.paymentQrBase64,
        updatedAt: now,
      );
      final savedSettings = settings.copyWith(
        invoiceNextNumber: userChangedInvoiceCounter
            ? settings.invoiceNextNumber
            : latestSettings.invoiceNextNumber,
        updatedAt: now,
      );

      await _repository.saveCompanyProfile(savedProfile);
      await _repository.saveAppSettings(savedSettings);
      emit(
        state.copyWith(
          status: CompanySettingsStatus.saved,
          profile: savedProfile,
          settings: savedSettings,
          message: 'Company profile and settings saved.',
        ),
      );
    } on AppException catch (error) {
      emit(
        state.copyWith(
          status: CompanySettingsStatus.failure,
          message: error.message,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: CompanySettingsStatus.failure,
          message: 'Unable to save company settings: $error',
        ),
      );
    }
  }
}
