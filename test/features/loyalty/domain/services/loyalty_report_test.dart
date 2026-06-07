import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/loyalty/domain/services/loyalty_report.dart';

void main() {
  group('buildLoyaltyReport', () {
    test('summarizes active loyalty balances and redeemable value', () {
      final report = buildLoyaltyReport(
        customers: [
          _customer(
            id: 'cust_1',
            name: 'TBS Enterprises',
            points: 120,
            earned: 200,
            redeemed: 80,
          ),
          _customer(
            id: 'cust_2',
            name: 'Acme Stores',
            points: 40,
            earned: 50,
            redeemed: 10,
            loyaltyEnabled: false,
          ),
          _customer(
            id: 'archived',
            name: 'Old Customer',
            points: 999,
            active: false,
          ),
        ],
        invoices: const [],
        pointValue: 0.5,
      );

      expect(report.totalCustomers, 2);
      expect(report.activeMembers, 1);
      expect(report.pointsOutstanding, 160);
      expect(report.lifetimePointsEarned, 250);
      expect(report.lifetimePointsRedeemed, 90);
      expect(report.outstandingValue, 80);
      expect(report.customers.map((row) => row.customer.name), [
        'TBS Enterprises',
        'Acme Stores',
      ]);
    });

    test('builds recent award rows from awarded invoices only', () {
      final report = buildLoyaltyReport(
        customers: [_customer(id: 'cust_1', name: 'TBS Enterprises')],
        invoices: [
          _invoice(
            id: 'inv_old',
            customerId: 'cust_1',
            invoiceNumber: 'INV-OLD',
            date: DateTime(2026, 5, 1),
            points: 5,
          ),
          _invoice(
            id: 'inv_new',
            customerId: 'cust_1',
            invoiceNumber: 'INV-NEW',
            date: DateTime(2026, 5, 3),
            points: 12,
          ),
          _invoice(
            id: 'inv_zero',
            customerId: 'cust_1',
            invoiceNumber: 'INV-ZERO',
            date: DateTime(2026, 5, 4),
            points: 0,
          ),
        ],
        pointValue: 1,
      );

      expect(report.recentAwards.map((row) => row.invoice.invoiceNumber), [
        'INV-NEW',
        'INV-OLD',
      ]);
      expect(report.recentAwards.first.customerName, 'TBS Enterprises');
      expect(report.recentAwards.first.pointsEarned, 12);
    });
  });

  group('filterLoyaltyCustomers', () {
    test('matches name, phone, email, gstin, and points', () {
      final rows = buildLoyaltyReport(
        customers: [
          _customer(
            id: 'cust_1',
            name: 'TBS Enterprises',
            phone: '9655246269',
            email: 'test@example.com',
            gstin: '33AHOPY8219N1ZE',
            points: 120,
          ),
          _customer(id: 'cust_2', name: 'Acme Stores', points: 40),
        ],
        invoices: const [],
        pointValue: 1,
      ).customers;

      expect(filterLoyaltyCustomers(rows, 'tbs').single.customer.id, 'cust_1');
      expect(filterLoyaltyCustomers(rows, '9655').single.customer.id, 'cust_1');
      expect(
        filterLoyaltyCustomers(rows, 'example').single.customer.id,
        'cust_1',
      );
      expect(
        filterLoyaltyCustomers(rows, 'ahopy').single.customer.id,
        'cust_1',
      );
      expect(filterLoyaltyCustomers(rows, '40').single.customer.id, 'cust_2');
    });
  });
}

Customer _customer({
  required String id,
  required String name,
  String phone = '',
  String email = '',
  String gstin = '',
  int points = 0,
  int earned = 0,
  int redeemed = 0,
  bool loyaltyEnabled = true,
  bool active = true,
}) {
  final now = DateTime(2026, 5, 2);
  return Customer(
    id: id,
    name: name,
    phone: phone,
    email: email,
    billingAddress: '',
    shippingAddress: '',
    gstin: gstin,
    state: '',
    defaultDiscountType: 'none',
    defaultDiscountValue: 0,
    loyaltyEnabled: loyaltyEnabled,
    loyaltyPointsBalance: points,
    lifetimePointsEarned: earned,
    lifetimePointsRedeemed: redeemed,
    totalBilled: 0,
    totalPaid: 0,
    outstandingAmount: 0,
    notes: '',
    defaultInvoiceTerms: '',
    isActive: active,
    createdAt: now,
    updatedAt: now,
  );
}

Invoice _invoice({
  required String id,
  required String customerId,
  required String invoiceNumber,
  required DateTime date,
  required int points,
}) {
  return Invoice(
    id: id,
    invoiceNumber: invoiceNumber,
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: date,
    dueDate: date.add(const Duration(days: 15)),
    customerId: customerId,
    customerSnapshot: const {'name': 'TBS Enterprises'},
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: [InvoiceItem.empty()],
    taxMode: TaxMode.none,
    status: InvoiceStatus.paid,
    subtotal: 1000,
    discountType: 'none',
    discountValue: 0,
    discountTotal: 0,
    extraCharges: const [],
    extraChargeTotal: 0,
    taxableAmount: 1000,
    cgstAmount: 0,
    sgstAmount: 0,
    igstAmount: 0,
    roundOffEnabled: false,
    roundOffAmount: 0,
    grandTotal: 1000,
    amountPaid: 1000,
    balanceDue: 0,
    notes: '',
    terms: '',
    paymentHistory: const [],
    loyaltyPointsAwarded: points > 0,
    pointsEarned: points,
    createdAt: date,
    updatedAt: date,
  );
}
