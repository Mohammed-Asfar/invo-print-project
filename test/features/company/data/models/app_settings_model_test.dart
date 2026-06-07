import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/company/data/models/app_settings_model.dart';
import 'package:invo_print/features/company/domain/entities/app_settings.dart';

void main() {
  group('AppSettingsModel template settings', () {
    test(
      'uses template defaults when older settings documents do not have them',
      () {
        final model = AppSettingsModel.fromMap(const {
          'invoicePrefix': 'INV',
          'invoiceNextNumber': 4,
        });
        final defaults = AppSettings.initial();

        expect(model.documentTemplate, defaults.documentTemplate);
        expect(model.invoiceTitle, defaults.invoiceTitle);
        expect(model.quotationTitle, defaults.quotationTitle);
        expect(model.showOriginalCopyLabelOnPdf, isTrue);
        expect(model.showAmountInWordsOnPdf, isTrue);
        expect(model.showBankDetailsOnPdf, isTrue);
        expect(model.showPaymentQrOnPdf, isTrue);
        expect(model.showSignatureBlockOnPdf, isTrue);
        expect(model.customerSignatureLabel, defaults.customerSignatureLabel);
        expect(
          model.authorizedSignatoryLabel,
          defaults.authorizedSignatoryLabel,
        );
      },
    );

    test('persists advanced template preferences', () {
      final settings = AppSettings.initial().copyWith(
        documentTemplate: 'compact_bill',
        invoiceTitle: 'RETAIL BILL',
        quotationTitle: 'ESTIMATE',
        showOriginalCopyLabelOnPdf: false,
        showAmountInWordsOnPdf: false,
        showBankDetailsOnPdf: false,
        showPaymentQrOnPdf: false,
        showSignatureBlockOnPdf: false,
        customerSignatureLabel: 'Received By',
        authorizedSignatoryLabel: 'Approved By',
      );

      final map = AppSettingsModel.fromEntity(settings).toMap();
      final restored = AppSettingsModel.fromMap(map);

      expect(restored.documentTemplate, 'compact_bill');
      expect(restored.invoiceTitle, 'RETAIL BILL');
      expect(restored.quotationTitle, 'ESTIMATE');
      expect(restored.showOriginalCopyLabelOnPdf, isFalse);
      expect(restored.showAmountInWordsOnPdf, isFalse);
      expect(restored.showBankDetailsOnPdf, isFalse);
      expect(restored.showPaymentQrOnPdf, isFalse);
      expect(restored.showSignatureBlockOnPdf, isFalse);
      expect(restored.customerSignatureLabel, 'Received By');
      expect(restored.authorizedSignatoryLabel, 'Approved By');
    });
  });
}
