import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/company/domain/entities/company_profile.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_output_builder.dart';

void main() {
  const builder = InvoiceOutputBuilder();

  group('InvoiceOutputBuilder', () {
    test('builds dynamic UPI URI without payee name parameter', () {
      final uri = builder.buildUpiUri(
        upiId: 'merchant@upi',
        invoiceNumber: 'INV-001',
        amount: 3068,
      );

      expect(uri, isNotNull);
      final parsed = Uri.parse(uri!);
      expect(parsed.scheme, 'upi');
      expect(parsed.host, 'pay');
      expect(parsed.queryParameters['pa'], 'merchant@upi');
      expect(parsed.queryParameters['am'], '3068.00');
      expect(parsed.queryParameters['cu'], 'INR');
      expect(parsed.queryParameters['tn'], 'INV-001');
      expect(parsed.queryParameters.containsKey('pn'), isFalse);
    });

    test(
      'does not build payment data for missing UPI/static QR or zero amount',
      () {
        expect(
          builder.buildPaymentData(
            companyProfile: CompanyProfile.empty(),
            invoiceNumber: 'INV-001',
            grandTotal: 0,
          ),
          isNull,
        );
        expect(
          builder.buildPaymentData(
            companyProfile: CompanyProfile.empty(),
            invoiceNumber: 'INV-001',
            grandTotal: 100,
          ),
          isNull,
        );
      },
    );

    test('prefers dynamic UPI over uploaded static QR', () {
      final profile = _profile(
        upiId: 'merchant@upi',
        paymentQrBase64: base64Encode([1, 2, 3]),
      );

      final data = builder.buildPaymentData(
        companyProfile: profile,
        invoiceNumber: 'INV-001',
        grandTotal: 100,
      );

      expect(data, isNotNull);
      expect(data!.isDynamic, isTrue);
      expect(data.label, 'merchant@upi');
      expect(data.qrPayload, contains('pa=merchant%40upi'));
    });

    test('falls back to uploaded static QR when UPI ID is empty', () {
      final bytes = [1, 2, 3, 4];
      final profile = _profile(paymentQrBase64: base64Encode(bytes));

      final data = builder.buildPaymentData(
        companyProfile: profile,
        invoiceNumber: 'INV-001',
        grandTotal: 100,
      );

      expect(data, isNotNull);
      expect(data!.isDynamic, isFalse);
      expect(data.imageBytes, bytes);
    });

    test('returns only non-empty output fields', () {
      final fields = builder.visibleFields(
        {
          'name': ' TBS Enterprises ',
          'email': '',
          'phone': null,
          'state': 'Tamil Nadu',
        },
        {'name': 'Name', 'email': 'Email', 'phone': 'Phone', 'state': 'State'},
      );

      expect(fields.map((field) => field.label), ['Name', 'State']);
      expect(fields.map((field) => field.value), [
        'TBS Enterprises',
        'Tamil Nadu',
      ]);
    });
  });
}

CompanyProfile _profile({String upiId = '', String paymentQrBase64 = ''}) {
  final empty = CompanyProfile.empty();
  return CompanyProfile(
    businessName: 'TBS Enterprises',
    legalName: empty.legalName,
    gstin: empty.gstin,
    pan: empty.pan,
    email: empty.email,
    phone: empty.phone,
    website: empty.website,
    addressLine1: empty.addressLine1,
    addressLine2: empty.addressLine2,
    city: empty.city,
    state: empty.state,
    pincode: empty.pincode,
    country: empty.country,
    bankName: empty.bankName,
    bankAccountName: empty.bankAccountName,
    bankAccountNumber: empty.bankAccountNumber,
    ifscCode: empty.ifscCode,
    upiId: upiId,
    defaultInvoiceTerms: empty.defaultInvoiceTerms,
    defaultQuotationTerms: empty.defaultQuotationTerms,
    logoBase64: empty.logoBase64,
    paymentQrBase64: paymentQrBase64,
    updatedAt: empty.updatedAt,
  );
}
