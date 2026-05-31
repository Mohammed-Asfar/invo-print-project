import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_output_builder.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_pdf_service.dart';

void main() {
  group('InvoicePdfService', () {
    test(
      'builds a PDF for a sparse invoice without empty optional blocks',
      () async {
        final bytes = await const InvoicePdfService(
          InvoiceOutputBuilder(),
        ).buildInvoicePdf(invoice: _invoice(), currencySymbol: 'Rs');

        expect(bytes, isNotEmpty);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      },
    );

    test('builds a PDF with payment history and amount due QR data', () async {
      final bytes = await const InvoicePdfService(InvoiceOutputBuilder())
          .buildInvoicePdf(
            invoice: _invoice(
              companySnapshot: const {
                'businessName': 'CompanyTest',
                'upiId': 'merchant@upi',
              },
              amountPaid: 500,
              balanceDue: 680,
              paymentHistory: [
                InvoicePaymentRecord(
                  amount: 500,
                  paidAt: DateTime(2026, 5, 2),
                  method: 'UPI',
                  reference: 'UTR-1',
                ),
              ],
            ),
            currencySymbol: 'Rs',
          );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('marks draft invoice PDFs with a visible draft label', () async {
      final bytes = await const InvoicePdfService(InvoiceOutputBuilder())
          .buildInvoicePdf(
            invoice: _invoice(status: InvoiceStatus.draft),
            currencySymbol: 'Rs',
          );

      expect(_decodedPdfText(bytes), contains('DRAFT'));
    });

    test('does not mark non-draft invoice PDFs as drafts', () async {
      final bytes = await const InvoicePdfService(
        InvoiceOutputBuilder(),
      ).buildInvoicePdf(invoice: _invoice(), currencySymbol: 'Rs');

      expect(_decodedPdfText(bytes), isNot(contains('DRAFT')));
    });
  });
}

Invoice _invoice({
  Map<String, dynamic> companySnapshot = const {'businessName': 'CompanyTest'},
  double amountPaid = 0,
  double balanceDue = 1180,
  InvoiceStatus? status,
  List<InvoicePaymentRecord> paymentHistory = const [],
}) {
  final now = DateTime(2026, 5, 2);
  return Invoice(
    id: 'inv_1',
    invoiceNumber: 'INV-001',
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: now,
    dueDate: DateTime(2026, 5, 17),
    customerId: 'cust_1',
    customerSnapshot: const {
      'name': 'TBS Enterprises',
      'phone': '9655246269',
      'billingAddress': 'No: 22, MMS Complex',
    },
    companySnapshot: companySnapshot,
    items: [
      InvoiceItem.empty().copyWith(
        name: 'Service',
        quantity: 1,
        rate: 1000,
        gstRate: 18,
        taxableAmount: 1000,
        cgstAmount: 90,
        sgstAmount: 90,
        total: 1180,
      ),
    ],
    taxMode: TaxMode.cgstSgst,
    status:
        status ??
        (amountPaid > 0 ? InvoiceStatus.partialPaid : InvoiceStatus.unpaid),
    subtotal: 1000,
    discountType: 'none',
    discountValue: 0,
    discountTotal: 0,
    extraCharges: const [],
    extraChargeTotal: 0,
    taxableAmount: 1000,
    cgstAmount: 90,
    sgstAmount: 90,
    igstAmount: 0,
    roundOffEnabled: false,
    roundOffAmount: 0,
    grandTotal: 1180,
    amountPaid: amountPaid,
    balanceDue: balanceDue,
    notes: '',
    terms: '',
    paymentHistory: paymentHistory,
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: now,
    updatedAt: now,
  );
}

String _decodedPdfText(Uint8List bytes) {
  final rawPdf = latin1.decode(bytes, allowInvalid: true);
  final decodedStreams = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream')
      .allMatches(rawPdf)
      .map((match) {
        final stream = latin1.encode(match.group(1)!);
        try {
          return latin1.decode(zlib.decode(stream), allowInvalid: true);
        } on FormatException {
          return latin1.decode(stream, allowInvalid: true);
        }
      });

  return [rawPdf, ...decodedStreams].join('\n');
}
