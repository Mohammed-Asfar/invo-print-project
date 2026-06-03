import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/invoices/presentation/pages/invoice_export_file_names.dart';

void main() {
  group('buildBulkInvoicePdfFileNames', () {
    test('adds numeric suffixes when invoice numbers collide', () {
      final invoices = [
        _invoice(invoiceNumber: 'INV-001'),
        _invoice(id: 'inv_2', invoiceNumber: 'INV-001'),
        _invoice(id: 'inv_3', invoiceNumber: 'INV-001'),
      ];

      expect(buildBulkInvoicePdfFileNames(invoices), [
        'INV-001.pdf',
        'INV-001 (2).pdf',
        'INV-001 (3).pdf',
      ]);
    });

    test('dedupes sanitized invoice names that land on the same base name', () {
      final invoices = [
        _invoice(invoiceNumber: 'INV/001'),
        _invoice(id: 'inv_2', invoiceNumber: 'INV:001'),
        _invoice(id: 'inv_3', invoiceNumber: 'INV?001'),
      ];

      expect(buildBulkInvoicePdfFileNames(invoices), [
        'INV-001.pdf',
        'INV-001 (2).pdf',
        'INV-001 (3).pdf',
      ]);
    });

    test('falls back to invoice when the number is blank or invalid', () {
      final invoices = [
        _invoice(invoiceNumber: ''),
        _invoice(id: 'inv_2', invoiceNumber: '  <>:"/\\\\|?*  '),
      ];

      expect(buildBulkInvoicePdfFileNames(invoices), [
        'invoice.pdf',
        'invoice (2).pdf',
      ]);
    });
  });
}

Invoice _invoice({
  String id = 'inv_1',
  required String invoiceNumber,
}) {
  return Invoice(
    id: id,
    invoiceNumber: invoiceNumber,
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: DateTime(2026, 5, 2),
    dueDate: DateTime(2026, 5, 17),
    customerId: 'cust_1',
    customerSnapshot: const {'name': 'TBS Enterprises'},
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: [InvoiceItem.empty()],
    taxMode: TaxMode.cgstSgst,
    status: InvoiceStatus.unpaid,
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
    amountPaid: 0,
    balanceDue: 1180,
    notes: '',
    terms: '',
    paymentHistory: const [],
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: DateTime(2026, 5, 2, 10),
    updatedAt: DateTime(2026, 5, 2, 10),
  );
}
