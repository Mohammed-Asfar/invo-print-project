import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';
import 'package:invo_print/features/customers/domain/services/customer_ledger.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';

void main() {
  group('buildCustomerLedger', () {
    test('summarizes invoices payments credits and outstanding balance', () {
      final customer = _customer(id: 'cust_1', loyaltyPointsBalance: 25);
      final ledger = buildCustomerLedger(
        customer: customer,
        invoices: [
          _invoice(
            id: 'inv_1',
            customerId: 'cust_1',
            grandTotal: 1180,
            amountPaid: 500,
            creditTotal: 100,
            balanceDue: 580,
            pointsEarned: 12,
            paymentHistory: [
              InvoicePaymentRecord(
                amount: 500,
                paidAt: DateTime(2026, 5, 3),
                method: 'UPI',
                reference: 'UTR-1',
              ),
            ],
            creditNotes: [
              InvoiceCreditNote(
                amount: 100,
                issuedAt: DateTime(2026, 5, 4),
                reason: 'Short supply',
                reference: 'CN-1',
              ),
            ],
          ),
          _invoice(
            id: 'inv_2',
            customerId: 'cust_1',
            grandTotal: 500,
            amountPaid: 500,
            balanceDue: 0,
            status: InvoiceStatus.paid,
            pointsEarned: 5,
          ),
        ],
      );

      expect(ledger.totalInvoiced, 1680);
      expect(ledger.totalPaid, 1000);
      expect(ledger.totalCredited, 100);
      expect(ledger.outstandingBalance, 580);
      expect(ledger.creditBalance, 0);
      expect(ledger.loyaltyPoints, 42);
      expect(
        ledger.entries.map((entry) => entry.type),
        containsAll([
          CustomerLedgerEntryType.invoice,
          CustomerLedgerEntryType.payment,
          CustomerLedgerEntryType.credit,
        ]),
      );
    });

    test('excludes draft and cancelled invoices from totals', () {
      final customer = _customer(id: 'cust_1');
      final ledger = buildCustomerLedger(
        customer: customer,
        invoices: [
          _invoice(customerId: 'cust_1', status: InvoiceStatus.draft),
          _invoice(
            id: 'cancelled',
            customerId: 'cust_1',
            status: InvoiceStatus.cancelled,
          ),
        ],
      );

      expect(ledger.invoices, isEmpty);
      expect(ledger.totalInvoiced, 0);
      expect(ledger.entries, isEmpty);
    });

    test('tracks negative balance as customer credit', () {
      final customer = _customer(id: 'cust_1');
      final ledger = buildCustomerLedger(
        customer: customer,
        invoices: [
          _invoice(
            customerId: 'cust_1',
            status: InvoiceStatus.paid,
            grandTotal: 1180,
            amountPaid: 1180,
            creditTotal: 200,
            balanceDue: -200,
          ),
        ],
      );

      expect(ledger.outstandingBalance, 0);
      expect(ledger.creditBalance, 200);
      expect(ledger.totalCredited, 200);
    });

    test(
      'matches older invoices by snapshot phone when customer id is missing',
      () {
        final customer = _customer(id: 'cust_1', phone: '9655246269');
        final ledger = buildCustomerLedger(
          customer: customer,
          invoices: [
            _invoice(
              customerId: '',
              customerSnapshot: const {
                'name': 'Old Name',
                'phone': '9655246269',
              },
            ),
            _invoice(id: 'other', customerId: 'other_customer'),
          ],
        );

        expect(ledger.invoices, hasLength(1));
        expect(ledger.invoices.single.customerId, isEmpty);
      },
    );
  });
}

Customer _customer({
  String id = 'cust_1',
  String phone = '',
  int loyaltyPointsBalance = 0,
}) {
  final now = DateTime(2026, 5, 2);
  return Customer(
    id: id,
    name: 'TBS Enterprises',
    phone: phone,
    email: 'test@example.com',
    billingAddress: '',
    shippingAddress: '',
    gstin: '',
    state: '',
    defaultDiscountType: 'none',
    defaultDiscountValue: 0,
    loyaltyEnabled: true,
    loyaltyPointsBalance: loyaltyPointsBalance,
    lifetimePointsEarned: loyaltyPointsBalance,
    lifetimePointsRedeemed: 0,
    totalBilled: 0,
    totalPaid: 0,
    outstandingAmount: 0,
    notes: '',
    defaultInvoiceTerms: '',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Invoice _invoice({
  String id = 'inv_1',
  String customerId = 'cust_1',
  Map<String, dynamic>? customerSnapshot,
  InvoiceStatus status = InvoiceStatus.unpaid,
  double grandTotal = 1180,
  double amountPaid = 0,
  double creditTotal = 0,
  double balanceDue = 1180,
  int pointsEarned = 0,
  List<InvoicePaymentRecord> paymentHistory = const [],
  List<InvoiceCreditNote> creditNotes = const [],
}) {
  final now = DateTime(2026, 5, 2);
  return Invoice(
    id: id,
    invoiceNumber: 'INV-$id',
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: now,
    dueDate: now.add(const Duration(days: 15)),
    customerId: customerId,
    customerSnapshot:
        customerSnapshot ?? const {'name': 'TBS Enterprises', 'phone': ''},
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
    creditTotal: creditTotal,
    notes: '',
    terms: '',
    paymentHistory: paymentHistory,
    creditNotes: creditNotes,
    loyaltyPointsAwarded: pointsEarned > 0,
    pointsEarned: pointsEarned,
    createdAt: now,
    updatedAt: now,
  );
}
