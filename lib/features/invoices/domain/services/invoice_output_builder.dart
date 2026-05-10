import 'dart:convert';
import 'dart:typed_data';

import '../../../company/domain/entities/company_profile.dart';

class InvoiceOutputBuilder {
  const InvoiceOutputBuilder();

  InvoicePaymentData? buildPaymentData({
    required CompanyProfile? companyProfile,
    required String invoiceNumber,
    required double grandTotal,
  }) {
    if (companyProfile == null) return null;
    if (grandTotal <= 0) return null;

    final upiUri = buildUpiUri(
      upiId: companyProfile.upiId,
      invoiceNumber: invoiceNumber,
      amount: grandTotal,
    );
    if (upiUri != null) {
      return InvoicePaymentData.dynamic(
        qrPayload: upiUri,
        label: companyProfile.upiId.trim(),
        helperText: 'Scan to pay the exact invoice amount.',
        amount: grandTotal,
      );
    }

    final staticQrBytes = _decodeBase64Image(companyProfile.paymentQrBase64);
    if (staticQrBytes != null) {
      return InvoicePaymentData.staticQr(
        qrPayload: companyProfile.paymentQrBase64.trim(),
        label: 'Uploaded payment QR',
        helperText: 'Static payment QR from company settings.',
        amount: grandTotal,
        imageBytes: staticQrBytes,
      );
    }

    return null;
  }

  InvoicePaymentData? buildPaymentDataFromSnapshot({
    required Map<String, dynamic> companySnapshot,
    required String invoiceNumber,
    required double grandTotal,
    CompanyProfile? fallbackProfile,
  }) {
    if (grandTotal <= 0) return null;
    final upiId = _readString(companySnapshot['upiId']).isNotEmpty
        ? _readString(companySnapshot['upiId'])
        : fallbackProfile?.upiId ?? '';
    final upiUri = buildUpiUri(
      upiId: upiId,
      invoiceNumber: invoiceNumber,
      amount: grandTotal,
    );
    if (upiUri != null) {
      return InvoicePaymentData.dynamic(
        qrPayload: upiUri,
        label: upiId.trim(),
        helperText: 'Scan to pay the exact invoice amount.',
        amount: grandTotal,
      );
    }

    final paymentQrBase64 =
        _readString(companySnapshot['paymentQrBase64']).isNotEmpty
        ? _readString(companySnapshot['paymentQrBase64'])
        : fallbackProfile?.paymentQrBase64 ?? '';
    final staticQrBytes = _decodeBase64Image(paymentQrBase64);
    if (staticQrBytes != null) {
      return InvoicePaymentData.staticQr(
        qrPayload: paymentQrBase64.trim(),
        label: 'Uploaded payment QR',
        helperText: 'Static payment QR from company settings.',
        amount: grandTotal,
        imageBytes: staticQrBytes,
      );
    }

    return null;
  }

  List<InvoiceOutputField> visibleFields(
    Map<String, dynamic> source,
    Map<String, String> labels,
  ) {
    return labels.entries
        .map(
          (entry) => InvoiceOutputField(
            label: entry.value,
            value: _readVisibleValue(source[entry.key]),
          ),
        )
        .where((field) => field.value.isNotEmpty)
        .toList();
  }

  String? buildUpiUri({
    required String upiId,
    required String invoiceNumber,
    required double amount,
  }) {
    final normalizedUpi = upiId.trim();
    if (normalizedUpi.isEmpty || amount <= 0) return null;

    final parameters = <String, String>{
      'pa': normalizedUpi,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      if (invoiceNumber.trim().isNotEmpty) 'tn': invoiceNumber.trim(),
    };

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: parameters,
    ).toString();
  }

  String _readVisibleValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  Uint8List? _decodeBase64Image(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return null;
    try {
      final normalized = value.contains(',')
          ? value.substring(value.indexOf(',') + 1)
          : value;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }
}

class InvoiceOutputField {
  const InvoiceOutputField({required this.label, required this.value});

  final String label;
  final String value;
}

class InvoicePaymentData {
  const InvoicePaymentData._({
    required this.qrPayload,
    required this.label,
    required this.helperText,
    required this.amount,
    required this.isDynamic,
    this.imageBytes,
  });

  const InvoicePaymentData.dynamic({
    required String qrPayload,
    required String label,
    required String helperText,
    required double amount,
  }) : this._(
         qrPayload: qrPayload,
         label: label,
         helperText: helperText,
         amount: amount,
         isDynamic: true,
       );

  const InvoicePaymentData.staticQr({
    required String qrPayload,
    required String label,
    required String helperText,
    required double amount,
    required Uint8List imageBytes,
  }) : this._(
         qrPayload: qrPayload,
         label: label,
         helperText: helperText,
         amount: amount,
         isDynamic: false,
         imageBytes: imageBytes,
       );

  final String qrPayload;
  final String label;
  final String helperText;
  final double amount;
  final bool isDynamic;
  final Uint8List? imageBytes;
}
