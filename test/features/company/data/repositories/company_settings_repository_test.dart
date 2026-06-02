import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/core/errors/app_exception.dart';
import 'package:invo_print/core/firebase/customer_firestore_rest_client.dart';
import 'package:invo_print/features/company/data/models/app_settings_model.dart';
import 'package:invo_print/features/company/data/repositories/company_settings_repository.dart';
import 'package:invo_print/features/company/domain/entities/app_settings.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('CompanySettingsRepository', () {
    test(
      'reserves next invoice number from fallback when settings document is missing',
      () async {
        final firestore = FakeCustomerFirestoreRestClient();
        final repository = CompanySettingsRepository(firestore);
        final fallback = _settings(invoiceNextNumber: 11);

        final reservation = await repository.reserveNextInvoiceNumber(
          fallbackSettings: fallback,
        );

        expect(reservation.reservedSequence, 11);
        expect(reservation.updatedSettings.invoiceNextNumber, 12);

        final savedSettings = await repository.fetchAppSettings();
        expect(savedSettings.invoiceNextNumber, 12);
      },
    );

    test(
      'retries reservation after a write conflict and returns the next free number',
      () async {
        final firestore = _ConflictOnceFirestore({
          'settings/app': AppSettingsModel.fromEntity(
            _settings(invoiceNextNumber: 7),
          ).toMap(),
        });
        final repository = CompanySettingsRepository(firestore);

        final reservation = await repository.reserveNextInvoiceNumber(
          fallbackSettings: _settings(invoiceNextNumber: 7),
        );

        expect(reservation.reservedSequence, 8);
        expect(reservation.updatedSettings.invoiceNextNumber, 9);

        final savedSettings = await repository.fetchAppSettings();
        expect(savedSettings.invoiceNextNumber, 9);
      },
    );
  });
}

class _ConflictOnceFirestore extends FakeCustomerFirestoreRestClient {
  _ConflictOnceFirestore(super.seed);

  bool _conflicted = false;

  @override
  Future<void> setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data, {
    FirestoreWritePrecondition? precondition,
  }) async {
    if (!_conflicted &&
        collection == 'settings' &&
        documentId == 'app' &&
        precondition?.updateTime != null) {
      _conflicted = true;
      documents['settings/app'] = {'invoiceNextNumber': 8};
      throw const AppException(
        'Document update conflict. (FAILED_PRECONDITION)',
      );
    }
    await super.setDocument(
      collection,
      documentId,
      data,
      precondition: precondition,
    );
  }
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
    updatedAt: DateTime(2026, 6, 2),
  );
}
