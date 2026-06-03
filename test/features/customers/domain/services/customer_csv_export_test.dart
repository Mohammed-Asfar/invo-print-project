import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';
import 'package:invo_print/features/customers/domain/services/customer_csv_export.dart';

void main() {
  group('buildCustomersCsv', () {
    test('exports customers sorted by name with custom field columns', () {
      final csv = buildCustomersCsv([
        _customer(name: 'Beta Traders', customFields: const {'Route': 'South'}),
        _customer(
          name: 'Alpha, Stores',
          notes: 'Prefers "monthly" billing',
          customFields: const {'State Code': '33'},
        ),
      ]);

      final lines = csv.split('\n');
      expect(lines.first, contains('Custom: Route'));
      expect(lines.first, contains('Custom: State Code'));
      expect(lines[1], startsWith('"Alpha, Stores"'));
      expect(lines[1], contains('"Prefers ""monthly"" billing"'));
      expect(lines[2], startsWith('Beta Traders'));
    });
  });
}

Customer _customer({
  required String name,
  String notes = '',
  Map<String, String> customFields = const {},
}) {
  final now = DateTime(2026, 5, 1);
  return Customer(
    id: name,
    name: name,
    phone: '9655246269',
    email: 'test@example.com',
    billingAddress: 'Billing address',
    shippingAddress: '',
    gstin: '',
    state: 'Tamil Nadu',
    defaultDiscountType: 'none',
    defaultDiscountValue: 0,
    loyaltyEnabled: true,
    loyaltyPointsBalance: 10,
    lifetimePointsEarned: 10,
    lifetimePointsRedeemed: 0,
    totalBilled: 0,
    totalPaid: 0,
    outstandingAmount: 0,
    notes: notes,
    defaultInvoiceTerms: '',
    isActive: true,
    createdAt: now,
    updatedAt: now,
    customFields: customFields,
  );
}
