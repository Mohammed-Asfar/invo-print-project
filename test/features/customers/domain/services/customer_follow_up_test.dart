import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';
import 'package:invo_print/features/customers/domain/services/customer_follow_up.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';

void main() {
  group('buildCustomerFollowUpQueue', () {
    test('prioritizes overdue and reminder-due customers', () {
      final today = DateTime(2026, 6, 30);
      final customerA = _customer(
        id: 'cust_1',
        name: 'TBS Enterprises',
        followUpStatus: CustomerFollowUpStatus.pending,
        nextFollowUpDate: DateTime(2026, 6, 25),
      );
      final customerB = _customer(
        id: 'cust_2',
        name: 'Metro Works',
        followUpStatus: CustomerFollowUpStatus.waiting,
      );

      final queue = buildCustomerFollowUpQueue(
        customers: [customerA, customerB],
        invoices: [
          _invoice(
            id: 'inv_1',
            customerId: 'cust_1',
            grandTotal: 2000,
            balanceDue: 2000,
            dueDate: DateTime(2026, 6, 10),
          ),
          _invoice(
            id: 'inv_2',
            customerId: 'cust_2',
            grandTotal: 1500,
            balanceDue: 1500,
            dueDate: DateTime(2026, 7, 15),
          ),
        ],
        today: today,
      );

      expect(queue.rows, hasLength(2));
      expect(queue.rows.first.customer.id, 'cust_1');
      expect(queue.actionCount, 1);
      expect(queue.overdueCustomerCount, 1);
      expect(queue.reminderDueCount, 1);
      expect(queue.totalOverdueAmount, 2000);
    });

    test('skips quiet customers without outstanding balance', () {
      final queue = buildCustomerFollowUpQueue(
        customers: [_customer(id: 'quiet', name: 'Quiet Customer')],
        invoices: [
          _invoice(
            id: 'inv_paid',
            customerId: 'quiet',
            balanceDue: 0,
            status: InvoiceStatus.paid,
          ),
        ],
        today: DateTime(2026, 6, 30),
      );

      expect(queue.rows, isEmpty);
      expect(queue.actionCount, 0);
    });
  });

  group('buildCustomerFollowUpCsv', () {
    test('prints summary and escapes special characters', () {
      final queue = buildCustomerFollowUpQueue(
        customers: [
          _customer(
            id: 'cust_1',
            name: 'ACME, "South"',
            followUpStatus: CustomerFollowUpStatus.pending,
            followUpNotes: 'Needs "urgent" reminder',
            nextFollowUpDate: DateTime(2026, 6, 20),
          ),
        ],
        invoices: [
          _invoice(
            id: 'inv_1',
            customerId: 'cust_1',
            grandTotal: 3500,
            balanceDue: 3500,
            dueDate: DateTime(2026, 6, 10),
          ),
        ],
        today: DateTime(2026, 6, 30),
      );

      final csv = buildCustomerFollowUpCsv(queue);

      expect(csv, contains('Summary'));
      expect(csv, contains('"ACME, ""South"""'));
      expect(csv, contains('"Needs ""urgent"" reminder"'));
      expect(csv, contains('Overdue Amount,3500.00'));
    });
  });
}

Customer _customer({
  required String id,
  required String name,
  CustomerFollowUpStatus followUpStatus = CustomerFollowUpStatus.none,
  DateTime? nextFollowUpDate,
  String followUpNotes = '',
}) {
  final now = DateTime(2026, 6, 1);
  return Customer(
    id: id,
    name: name,
    phone: '9655246269',
    email: 'customer@test.com',
    billingAddress: 'Billing address',
    shippingAddress: '',
    gstin: '',
    state: 'Tamil Nadu',
    defaultDiscountType: 'none',
    defaultDiscountValue: 0,
    loyaltyEnabled: true,
    loyaltyPointsBalance: 0,
    lifetimePointsEarned: 0,
    lifetimePointsRedeemed: 0,
    totalBilled: 0,
    totalPaid: 0,
    outstandingAmount: 0,
    notes: '',
    defaultInvoiceTerms: '',
    followUpStatus: followUpStatus,
    nextFollowUpDate: nextFollowUpDate,
    followUpNotes: followUpNotes,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Invoice _invoice({
  required String id,
  required String customerId,
  double grandTotal = 1180,
  double balanceDue = 1180,
  DateTime? dueDate,
  InvoiceStatus status = InvoiceStatus.unpaid,
}) {
  final now = DateTime(2026, 6, 2);
  return Invoice(
    id: id,
    invoiceNumber: 'INV-$id',
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: now,
    dueDate: dueDate ?? now.add(const Duration(days: 15)),
    customerId: customerId,
    customerSnapshot: const {'name': 'TBS Enterprises', 'phone': '9655246269'},
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
    amountPaid: 0,
    balanceDue: balanceDue,
    creditTotal: 0,
    notes: '',
    terms: '',
    paymentHistory: const [],
    creditNotes: const [],
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: now,
    updatedAt: now,
  );
}
