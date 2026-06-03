import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/reports/domain/services/sales_report.dart';

void main() {
  group('buildSalesReport', () {
    test('summarizes sales tax payments credits and balances', () {
      final report = buildSalesReport(
        invoices: [
          _invoice(
            id: 'one',
            grandTotal: 1180,
            amountPaid: 500,
            creditTotal: 100,
            balanceDue: 580,
            cgstAmount: 90,
            sgstAmount: 90,
            roundOffAmount: 0.12,
          ),
          _invoice(
            id: 'two',
            grandTotal: 2360,
            amountPaid: 2360,
            balanceDue: 0,
            cgstAmount: 0,
            sgstAmount: 0,
            igstAmount: 360,
            taxMode: TaxMode.igst,
          ),
        ],
      );

      expect(report.invoiceCount, 2);
      expect(report.totalInvoiced, 3540);
      expect(report.totalPaid, 2860);
      expect(report.totalCredited, 100);
      expect(report.outstandingBalance, 580);
      expect(report.customerCredit, 0);
      expect(report.cgstTotal, 90);
      expect(report.sgstTotal, 90);
      expect(report.igstTotal, 360);
      expect(report.roundOffTotal, 0.12);
    });

    test('excludes draft and cancelled invoices', () {
      final report = buildSalesReport(
        invoices: [
          _invoice(status: InvoiceStatus.draft),
          _invoice(id: 'cancelled', status: InvoiceStatus.cancelled),
        ],
      );

      expect(report.rows, isEmpty);
      expect(report.totalInvoiced, 0);
    });

    test('uses inclusive date bounds', () {
      final report = buildSalesReport(
        invoices: [
          _invoice(id: 'before', invoiceDate: DateTime(2026, 4, 30)),
          _invoice(id: 'from', invoiceDate: DateTime(2026, 5, 1)),
          _invoice(id: 'to', invoiceDate: DateTime(2026, 5, 31)),
          _invoice(id: 'after', invoiceDate: DateTime(2026, 6, 1)),
        ],
        from: DateTime(2026, 5),
        to: DateTime(2026, 5, 31),
      );

      expect(report.rows.map((row) => row.invoiceNumber), [
        'INV-to',
        'INV-from',
      ]);
    });

    test('falls back to payment history when amount paid is missing', () {
      final report = buildSalesReport(
        invoices: [
          _invoice(
            amountPaid: 0,
            paymentHistory: [
              InvoicePaymentRecord(amount: 400, paidAt: DateTime(2026, 5, 3)),
              InvoicePaymentRecord(amount: 200, paidAt: DateTime(2026, 5, 4)),
            ],
          ),
        ],
      );

      expect(report.totalPaid, 600);
      expect(report.rows.single.amountPaid, 600);
    });

    test('tracks negative balance as customer credit', () {
      final report = buildSalesReport(
        invoices: [
          _invoice(
            status: InvoiceStatus.paid,
            grandTotal: 1000,
            amountPaid: 1200,
            balanceDue: -200,
          ),
        ],
      );

      expect(report.outstandingBalance, 0);
      expect(report.customerCredit, 200);
    });
  });

  group('buildSalesReportCsv', () {
    test('escapes commas quotes and line breaks', () {
      final report = buildSalesReport(
        invoices: [
          _invoice(customerSnapshot: const {'name': 'ACME, "South"\nBranch'}),
        ],
      );

      final csv = buildSalesReportCsv(report);

      expect(csv, contains('"ACME, ""South""\nBranch"'));
      expect(csv, contains('Total Invoiced,1180.00'));
    });
  });
}

Invoice _invoice({
  String id = 'one',
  DateTime? invoiceDate,
  Map<String, dynamic>? customerSnapshot,
  InvoiceStatus status = InvoiceStatus.unpaid,
  TaxMode taxMode = TaxMode.cgstSgst,
  double grandTotal = 1180,
  double amountPaid = 0,
  double creditTotal = 0,
  double balanceDue = 1180,
  double cgstAmount = 90,
  double sgstAmount = 90,
  double igstAmount = 0,
  double roundOffAmount = 0,
  List<InvoicePaymentRecord> paymentHistory = const [],
}) {
  final date = invoiceDate ?? DateTime(2026, 5, 2);
  return Invoice(
    id: id,
    invoiceNumber: 'INV-$id',
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: date,
    dueDate: date.add(const Duration(days: 15)),
    customerId: 'cust_1',
    customerSnapshot: customerSnapshot ?? const {'name': 'TBS Enterprises'},
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: [
      InvoiceItem.empty().copyWith(
        name: 'Service',
        quantity: 1,
        rate: grandTotal,
        total: grandTotal,
      ),
    ],
    taxMode: taxMode,
    status: status,
    subtotal: grandTotal,
    discountType: 'none',
    discountValue: 0,
    discountTotal: 0,
    extraCharges: const [],
    extraChargeTotal: 0,
    taxableAmount: grandTotal - cgstAmount - sgstAmount - igstAmount,
    cgstAmount: cgstAmount,
    sgstAmount: sgstAmount,
    igstAmount: igstAmount,
    roundOffEnabled: roundOffAmount != 0,
    roundOffAmount: roundOffAmount,
    grandTotal: grandTotal,
    amountPaid: amountPaid,
    balanceDue: balanceDue,
    creditTotal: creditTotal,
    notes: '',
    terms: '',
    paymentHistory: paymentHistory,
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: date,
    updatedAt: date,
  );
}
