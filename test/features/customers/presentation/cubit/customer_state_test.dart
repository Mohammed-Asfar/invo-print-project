import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';
import 'package:invo_print/features/customers/presentation/cubit/customer_cubit.dart';

void main() {
  group('CustomerState', () {
    test('searches address terms notes state and custom fields', () {
      final state = CustomerState(
        customers: [
          _customer(id: 'address', billingAddress: 'Warehouse Gate 2'),
          _customer(id: 'terms', defaultInvoiceTerms: 'Net 15'),
          _customer(id: 'custom', customFields: const {'Route': 'South Zone'}),
          _customer(
            id: 'followup',
            followUpStatus: CustomerFollowUpStatus.pending,
            followUpNotes: 'Customer asked for reminder next week',
          ),
        ],
      );

      expect(
        state.copyWith(searchQuery: 'warehouse').filteredCustomers.single.id,
        'address',
      );
      expect(
        state.copyWith(searchQuery: 'net 15').filteredCustomers.single.id,
        'terms',
      );
      expect(
        state.copyWith(searchQuery: 'route').filteredCustomers.single.id,
        'custom',
      );
      expect(
        state.copyWith(searchQuery: 'south zone').filteredCustomers.single.id,
        'custom',
      );
      expect(
        state
            .copyWith(searchQuery: 'needs follow-up')
            .filteredCustomers
            .single
            .id,
        'followup',
      );
      expect(
        state
            .copyWith(searchQuery: 'reminder next week')
            .filteredCustomers
            .single
            .id,
        'followup',
      );
    });
  });
}

Customer _customer({
  required String id,
  String billingAddress = '',
  String defaultInvoiceTerms = '',
  Map<String, String> customFields = const {},
  CustomerFollowUpStatus followUpStatus = CustomerFollowUpStatus.none,
  String followUpNotes = '',
}) {
  final now = DateTime(2026, 5, 1);
  return Customer(
    id: id,
    name: 'TBS Enterprises',
    phone: '9655246269',
    email: 'test@example.com',
    billingAddress: billingAddress,
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
    defaultInvoiceTerms: defaultInvoiceTerms,
    followUpStatus: followUpStatus,
    followUpNotes: followUpNotes,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    customFields: customFields,
  );
}
