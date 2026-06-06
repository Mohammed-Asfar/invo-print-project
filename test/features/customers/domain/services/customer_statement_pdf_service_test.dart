import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';
import 'package:invo_print/features/customers/domain/services/customer_ledger.dart';
import 'package:invo_print/features/customers/domain/services/customer_statement_pdf_service.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';

void main() {
  test('CustomerStatementPdfService builds readable statement pdf', () async {
    final customer = _customer(name: 'TBS Enterprises');
    final juneInvoice = _invoice(
      id: 'inv_1',
      customerId: customer.id,
      invoiceNumber: 'INV-001',
      grandTotal: 2000,
      amountPaid: 500,
      balanceDue: 1500,
      dueDate: DateTime(2026, 6, 15),
      paymentHistory: [
        InvoicePaymentRecord(
          amount: 500,
          paidAt: DateTime(2026, 6, 6),
          method: 'UPI',
          reference: 'PAY-1',
        ),
      ],
    );
    final ledger = buildCustomerLedger(
      customer: customer,
      invoices: [juneInvoice],
    );

    final bytes = await const CustomerStatementPdfService().buildStatementPdf(
      customer: customer,
      ledger: ledger,
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final decoded = _decodedPdfText(bytes);
    expect(decoded, contains('Customer'));
    expect(decoded, contains('Statement'));
    expect(decoded, contains('TBS'));
    expect(decoded, contains('INV-001'));
    expect(decoded, contains('Outstanding'));
  });

  test(
    'CustomerStatementPdfService filters timeline by selected period',
    () async {
      final customer = _customer(name: 'TBS Enterprises');
      final mayInvoice = _invoice(
        id: 'inv_may',
        customerId: customer.id,
        invoiceNumber: 'INV-MAY',
        invoiceDate: DateTime(2026, 5, 5),
        dueDate: DateTime(2026, 5, 20),
        grandTotal: 1200,
        amountPaid: 1200,
        balanceDue: 0,
        status: InvoiceStatus.paid,
        paymentHistory: [
          InvoicePaymentRecord(
            amount: 1200,
            paidAt: DateTime(2026, 5, 6),
            method: 'Cash',
            reference: 'PAY-MAY',
          ),
        ],
      );
      final juneInvoice = _invoice(
        id: 'inv_june',
        customerId: customer.id,
        invoiceNumber: 'INV-JUNE',
        invoiceDate: DateTime(2026, 6, 5),
        dueDate: DateTime(2026, 6, 20),
        grandTotal: 2000,
        amountPaid: 500,
        balanceDue: 1500,
        paymentHistory: [
          InvoicePaymentRecord(
            amount: 500,
            paidAt: DateTime(2026, 6, 6),
            method: 'UPI',
            reference: 'PAY-JUNE',
          ),
        ],
      );
      final ledger = buildCustomerLedger(
        customer: customer,
        invoices: [juneInvoice, mayInvoice],
      );

      final bytes = await const CustomerStatementPdfService().buildStatementPdf(
        customer: customer,
        ledger: ledger,
        fromDate: DateTime(2026, 6, 1),
        toDate: DateTime(2026, 6, 30),
      );

      final decoded = _decodedPdfText(bytes);
      expect(decoded, contains('Activity'));
      expect(decoded, contains('INV-JUNE'));
      expect(decoded, contains('PAY-JUNE'));
      expect(decoded, isNot(contains('PAY-MAY')));
    },
  );
}

Customer _customer({required String name}) {
  final now = DateTime(2026, 6, 1);
  return Customer(
    id: 'cust_1',
    name: name,
    phone: '9655246269',
    email: 'test@example.com',
    billingAddress: 'No. 22, MMS Complex',
    shippingAddress: '',
    gstin: '33AHOPY8219N1ZE',
    state: 'Tamil Nadu',
    defaultDiscountType: 'none',
    defaultDiscountValue: 0,
    loyaltyEnabled: true,
    loyaltyPointsBalance: 12,
    lifetimePointsEarned: 40,
    lifetimePointsRedeemed: 28,
    totalBilled: 0,
    totalPaid: 0,
    outstandingAmount: 0,
    notes: '',
    defaultInvoiceTerms: 'Net 15',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Invoice _invoice({
  required String id,
  required String customerId,
  required String invoiceNumber,
  DateTime? invoiceDate,
  DateTime? dueDate,
  double grandTotal = 1180,
  double amountPaid = 0,
  double balanceDue = 1180,
  InvoiceStatus status = InvoiceStatus.unpaid,
  List<InvoicePaymentRecord> paymentHistory = const [],
}) {
  final now = invoiceDate ?? DateTime(2026, 6, 2);
  return Invoice(
    id: id,
    invoiceNumber: invoiceNumber,
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: now,
    dueDate: dueDate ?? now.add(const Duration(days: 15)),
    customerId: customerId,
    customerSnapshot: const {
      'name': 'TBS Enterprises',
      'phone': '9655246269',
      'billingAddress': 'No. 22, MMS Complex',
    },
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: [InvoiceItem.empty()],
    taxMode: TaxMode.cgstSgst,
    status: status,
    subtotal: grandTotal,
    discountType: 'none',
    discountValue: 0,
    discountTotal: 0,
    extraCharges: const [],
    extraChargeTotal: 0,
    taxableAmount: grandTotal,
    cgstAmount: 0,
    sgstAmount: 0,
    igstAmount: 0,
    roundOffEnabled: false,
    roundOffAmount: 0,
    grandTotal: grandTotal,
    amountPaid: amountPaid,
    balanceDue: balanceDue,
    creditTotal: 0,
    notes: '',
    terms: '',
    paymentHistory: paymentHistory,
    creditNotes: const [],
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
