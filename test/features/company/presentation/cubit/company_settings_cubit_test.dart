import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/company/data/models/app_settings_model.dart';
import 'package:invo_print/features/company/data/models/company_profile_model.dart';
import 'package:invo_print/features/company/data/repositories/company_settings_repository.dart';
import 'package:invo_print/features/company/domain/entities/app_settings.dart';
import 'package:invo_print/features/company/domain/entities/company_profile.dart';
import 'package:invo_print/features/company/presentation/cubit/company_settings_cubit.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('CompanySettingsCubit', () {
    test(
      'preserves the latest invoice counter when saving unrelated settings',
      () async {
        final initialSettings = _settings(invoiceNextNumber: 12);
        final updatedServerSettings = _settings(invoiceNextNumber: 13);
        final profile = CompanyProfile.empty();
        final firestore = FakeCustomerFirestoreRestClient({
          'settings/app': AppSettingsModel.fromEntity(initialSettings).toMap(),
          'company/profile': CompanyProfileModel.fromEntity(profile).toMap(),
        });
        final repository = CompanySettingsRepository(firestore);
        final cubit = CompanySettingsCubit(repository);
        addTearDown(cubit.close);

        await cubit.load();

        await repository.saveAppSettings(updatedServerSettings);

        await cubit.save(
          profile: profile,
          settings: AppSettings(
            gstEnabled: cubit.state.settings.gstEnabled,
            defaultGstRate: cubit.state.settings.defaultGstRate,
            invoicePrefix: 'BILL',
            invoiceSeparator: cubit.state.settings.invoiceSeparator,
            invoiceDateFormat: cubit.state.settings.invoiceDateFormat,
            invoiceNextNumber: cubit.state.settings.invoiceNextNumber,
            invoiceNumberPadding: cubit.state.settings.invoiceNumberPadding,
            quotationPrefix: cubit.state.settings.quotationPrefix,
            quotationSeparator: cubit.state.settings.quotationSeparator,
            quotationDateFormat: cubit.state.settings.quotationDateFormat,
            quotationNextNumber: cubit.state.settings.quotationNextNumber,
            quotationNumberPadding: cubit.state.settings.quotationNumberPadding,
            loyaltyEnabled: cubit.state.settings.loyaltyEnabled,
            pointsPerRupee: cubit.state.settings.pointsPerRupee,
            pointsRedemptionValue: cubit.state.settings.pointsRedemptionValue,
            currencyCode: cubit.state.settings.currencyCode,
            currencySymbol: cubit.state.settings.currencySymbol,
            themeMode: cubit.state.settings.themeMode,
            primaryColorHex: cubit.state.settings.primaryColorHex,
            showLineItemHsn: cubit.state.settings.showLineItemHsn,
            showCustomerStateCode: cubit.state.settings.showCustomerStateCode,
            gstinLookupEnabled: cubit.state.settings.gstinLookupEnabled,
            gstinLookupApiKey: cubit.state.settings.gstinLookupApiKey,
            gstinLookupApiHost: cubit.state.settings.gstinLookupApiHost,
            gstinValidationApiPath: cubit.state.settings.gstinValidationApiPath,
            gstinLookupApiPath: cubit.state.settings.gstinLookupApiPath,
            defaultCustomerState: cubit.state.settings.defaultCustomerState,
            defaultShippingState: cubit.state.settings.defaultShippingState,
            defaultLineItemUnit: cubit.state.settings.defaultLineItemUnit,
            customCustomerFields: cubit.state.settings.customCustomerFields,
            customShippingFields: cubit.state.settings.customShippingFields,
            customLineItemFields: cubit.state.settings.customLineItemFields,
            updatedAt: DateTime(2026, 6, 2),
          ),
        );

        final savedSettings = await repository.fetchAppSettings();
        expect(savedSettings.invoicePrefix, 'BILL');
        expect(savedSettings.invoiceNextNumber, 13);
      },
    );
  });
}

AppSettings _settings({required int invoiceNextNumber}) {
  final initial = AppSettings.initial();
  return AppSettings(
    gstEnabled: initial.gstEnabled,
    defaultGstRate: initial.defaultGstRate,
    invoicePrefix: initial.invoicePrefix,
    invoiceSeparator: initial.invoiceSeparator,
    invoiceDateFormat: initial.invoiceDateFormat,
    invoiceNextNumber: invoiceNextNumber,
    invoiceNumberPadding: initial.invoiceNumberPadding,
    quotationPrefix: initial.quotationPrefix,
    quotationSeparator: initial.quotationSeparator,
    quotationDateFormat: initial.quotationDateFormat,
    quotationNextNumber: initial.quotationNextNumber,
    quotationNumberPadding: initial.quotationNumberPadding,
    loyaltyEnabled: initial.loyaltyEnabled,
    pointsPerRupee: initial.pointsPerRupee,
    pointsRedemptionValue: initial.pointsRedemptionValue,
    currencyCode: initial.currencyCode,
    currencySymbol: initial.currencySymbol,
    themeMode: initial.themeMode,
    primaryColorHex: initial.primaryColorHex,
    showLineItemHsn: initial.showLineItemHsn,
    showCustomerStateCode: initial.showCustomerStateCode,
    gstinLookupEnabled: initial.gstinLookupEnabled,
    gstinLookupApiKey: initial.gstinLookupApiKey,
    gstinLookupApiHost: initial.gstinLookupApiHost,
    gstinValidationApiPath: initial.gstinValidationApiPath,
    gstinLookupApiPath: initial.gstinLookupApiPath,
    defaultCustomerState: initial.defaultCustomerState,
    defaultShippingState: initial.defaultShippingState,
    defaultLineItemUnit: initial.defaultLineItemUnit,
    customCustomerFields: initial.customCustomerFields,
    customShippingFields: initial.customShippingFields,
    customLineItemFields: initial.customLineItemFields,
    updatedAt: DateTime(2026, 6, 1),
  );
}
