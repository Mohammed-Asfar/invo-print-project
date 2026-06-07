import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/data/models/customer_model.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';

void main() {
  group('CustomerModel', () {
    test('round-trips customer follow-up fields', () {
      final now = DateTime(2026, 6, 5, 10, 45);
      final model = CustomerModel(
        id: 'cust_1',
        name: 'TBS Enterprises',
        phone: '9655246269',
        email: 'hello@tbs.test',
        billingAddress: 'No. 22, MMS Complex',
        shippingAddress: 'Warehouse Gate 2',
        gstin: '33AHOPY8219N1ZE',
        state: 'Tamil Nadu',
        defaultDiscountType: 'none',
        defaultDiscountValue: 0,
        loyaltyEnabled: true,
        loyaltyPointsBalance: 25,
        lifetimePointsEarned: 100,
        lifetimePointsRedeemed: 75,
        totalBilled: 15000,
        totalPaid: 12500,
        outstandingAmount: 2500,
        notes: 'Preferred customer',
        defaultInvoiceTerms: 'Net 15',
        followUpStatus: CustomerFollowUpStatus.pending,
        lastContactedAt: now.subtract(const Duration(days: 2)),
        nextFollowUpDate: now.add(const Duration(days: 3)),
        promisedPaymentDate: now.add(const Duration(days: 5)),
        followUpNotes: 'Call for payment confirmation',
        followUpHistory: [
          CustomerFollowUpHistoryEntry(
            status: CustomerFollowUpStatus.waiting,
            contactedAt: now.subtract(const Duration(days: 1)),
            outcome: 'Customer promised payment',
            note: 'Will pay after bank transfer clears',
            nextFollowUpDate: now.add(const Duration(days: 2)),
            promisedPaymentDate: now.add(const Duration(days: 5)),
          ),
        ],
        isActive: true,
        createdAt: now,
        updatedAt: now,
        customFields: const {'Route': 'South Zone'},
        lastInvoiceAt: now.subtract(const Duration(days: 5)),
      );

      final map = model.toMap();
      final restored = CustomerModel.fromMap('cust_1', map);

      expect(restored, model);
      expect(map['followUpStatus'], 'pending');
      expect(map['followUpNotes'], 'Call for payment confirmation');
      expect(map['promisedPaymentDate'], now.add(const Duration(days: 5)));
      expect(map['followUpHistory'], hasLength(1));
    });
  });
}
