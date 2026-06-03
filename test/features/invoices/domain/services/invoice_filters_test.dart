import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_filters.dart';

void main() {
  group('invoice filters', () {
    test('matches search without paid false positives', () {
      final paid = _invoice(
        id: 'paid',
        status: InvoiceStatus.paid,
        customerName: 'Paid Customer',
      );
      final partial = _invoice(
        id: 'partial',
        status: InvoiceStatus.partialPaid,
      );
      final unpaid = _invoice(id: 'unpaid', status: InvoiceStatus.unpaid);

      expect(matchesInvoiceSearch(paid, 'paid'), isTrue);
      expect(matchesInvoiceSearch(partial, 'paid'), isFalse);
      expect(matchesInvoiceSearch(unpaid, 'paid'), isFalse);
      expect(matchesInvoiceSearch(partial, 'partial paid'), isTrue);
      expect(matchesInvoiceSearch(partial, 'partial'), isTrue);
    });

    test('matches overdue token only for overdue invoices', () {
      final today = DateTime(2026, 6, 3);
      final overdue = _invoice(dueDate: DateTime(2026, 6, 2), balanceDue: 100);
      final futureDue = _invoice(
        id: 'future',
        dueDate: DateTime(2026, 6, 4),
        balanceDue: 100,
      );

      expect(matchesInvoiceSearch(overdue, 'overdue', today: today), isTrue);
      expect(matchesInvoiceSearch(futureDue, 'overdue', today: today), isFalse);
    });

    test(
      'overdue helper excludes paid cancelled and zero-balance invoices',
      () {
        final today = DateTime(2026, 6, 3);
        expect(
          isInvoiceOverdue(
            _invoice(status: InvoiceStatus.paid, dueDate: DateTime(2026, 6, 2)),
            today: today,
          ),
          isFalse,
        );
        expect(
          isInvoiceOverdue(
            _invoice(
              status: InvoiceStatus.cancelled,
              dueDate: DateTime(2026, 6, 2),
            ),
            today: today,
          ),
          isFalse,
        );
        expect(
          isInvoiceOverdue(
            _invoice(dueDate: DateTime(2026, 6, 2), balanceDue: 0),
            today: today,
          ),
          isFalse,
        );
        expect(
          isInvoiceOverdue(
            _invoice(dueDate: DateTime(2026, 6, 2), balanceDue: 100),
            today: today,
          ),
          isTrue,
        );
        expect(
          isInvoiceOverdue(
            _invoice(dueDate: DateTime(2026, 6, 3), balanceDue: 100),
            today: today,
          ),
          isFalse,
        );
      },
    );

    test(
      'due this week uses inclusive date bounds and ignores settled invoices',
      () {
        final today = DateTime(2026, 1, 28);
        expect(
          isInvoiceDueThisWeek(
            _invoice(dueDate: today, balanceDue: 100),
            today: today,
          ),
          isTrue,
        );
        expect(
          isInvoiceDueThisWeek(
            _invoice(
              dueDate: today.add(const Duration(days: 7)),
              balanceDue: 100,
            ),
            today: today,
          ),
          isTrue,
        );
        expect(
          isInvoiceDueThisWeek(
            _invoice(
              dueDate: today.subtract(const Duration(days: 1)),
              balanceDue: 100,
            ),
            today: today,
          ),
          isFalse,
        );
        expect(
          isInvoiceDueThisWeek(
            _invoice(
              dueDate: today.add(const Duration(days: 8)),
              balanceDue: 100,
            ),
            today: today,
          ),
          isFalse,
        );
        expect(
          isInvoiceDueThisWeek(
            _invoice(
              dueDate: today.add(const Duration(days: 2)),
              balanceDue: 0,
              status: InvoiceStatus.paid,
            ),
            today: today,
          ),
          isFalse,
        );
      },
    );

    test('last month handles january rollover', () {
      expect(
        isInvoiceFromLastMonth(
          DateTime(2025, 12, 15),
          today: DateTime(2026, 1, 10),
        ),
        isTrue,
      );
      expect(
        isInvoiceFromLastMonth(
          DateTime(2026, 1, 1),
          today: DateTime(2026, 1, 10),
        ),
        isFalse,
      );
    });
  });
}

Invoice _invoice({
  String id = 'inv_1',
  String customerName = 'TBS Enterprises',
  InvoiceStatus status = InvoiceStatus.unpaid,
  DateTime? dueDate,
  double balanceDue = 1180,
}) {
  final now = DateTime(2026, 5, 2);
  return Invoice(
    id: id,
    invoiceNumber: 'INV-001',
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: now,
    dueDate: dueDate ?? now.add(const Duration(days: 15)),
    customerId: 'cust_1',
    customerSnapshot: {'name': customerName},
    companySnapshot: const {'businessName': 'CompanyTest'},
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
    status: status,
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
    amountPaid: balanceDue <= 0 ? 1180 : 0,
    balanceDue: balanceDue,
    notes: '',
    terms: '',
    paymentHistory: const [],
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: now,
    updatedAt: now,
  );
}
