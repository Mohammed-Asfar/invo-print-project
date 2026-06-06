import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/data/models/customer_model.dart';
import 'package:invo_print/features/customers/data/repositories/customer_repository.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('CustomerRepository', () {
    test(
      'fetches only active customers sorted by updated date descending',
      () async {
        final older = _customer(id: 'older', updatedAt: DateTime(2026, 5, 1));
        final newer = _customer(id: 'newer', updatedAt: DateTime(2026, 5, 3));
        final inactive = _customer(
          id: 'inactive',
          updatedAt: DateTime(2026, 5, 4),
          isActive: false,
        );
        final firestore = FakeCustomerFirestoreRestClient({
          'customers/older': CustomerModel.fromEntity(older).toMap(),
          'customers/newer': CustomerModel.fromEntity(newer).toMap(),
          'customers/inactive': CustomerModel.fromEntity(inactive).toMap(),
        });

        final customers = await CustomerRepository(firestore).fetchCustomers();

        expect(customers.map((customer) => customer.id), ['newer', 'older']);
      },
    );

    test(
      'selected existing customer keeps loyalty history when phone changes',
      () async {
        final existing = _customer(
          id: 'cust_1',
          name: 'Old Name',
          phone: '9000000000',
          loyaltyPointsBalance: 250,
          lifetimePointsEarned: 500,
          totalBilled: 10000,
        );
        final firestore = FakeCustomerFirestoreRestClient({
          'customers/cust_1': CustomerModel.fromEntity(existing).toMap(),
        });

        final saved = await CustomerRepository(firestore)
            .findOrCreateFromInvoice(
              _customer(
                id: 'cust_1',
                name: 'New Name',
                phone: '9111111111',
                billingAddress: 'New address',
              ),
            );

        expect(saved.id, 'cust_1');
        expect(saved.name, 'New Name');
        expect(saved.phone, '9111111111');
        expect(saved.billingAddress, 'New address');
        expect(saved.loyaltyPointsBalance, 250);
        expect(saved.lifetimePointsEarned, 500);
        expect(saved.totalBilled, 10000);
        expect(saved.createdAt, existing.createdAt);
      },
    );

    test(
      'matches manually entered customers by GSTIN, email, then phone',
      () async {
        final byGstin = _customer(id: 'gst', gstin: '33AAHCT1111A1Z5');
        final byEmail = _customer(id: 'email', email: 'match@example.com');
        final byPhone = _customer(id: 'phone', phone: '9655246269');
        final firestore = FakeCustomerFirestoreRestClient({
          'customers/gst': CustomerModel.fromEntity(byGstin).toMap(),
          'customers/email': CustomerModel.fromEntity(byEmail).toMap(),
          'customers/phone': CustomerModel.fromEntity(byPhone).toMap(),
        });
        final repository = CustomerRepository(firestore);

        expect(
          (await repository.findOrCreateFromInvoice(
            _customer(gstin: '33AAHCT1111A1Z5', phone: 'new'),
          )).id,
          'gst',
        );
        expect(
          (await repository.findOrCreateFromInvoice(
            _customer(email: 'match@example.com', phone: 'newer'),
          )).id,
          'email',
        );
        expect(
          (await repository.findOrCreateFromInvoice(
            _customer(phone: '9655246269'),
          )).id,
          'phone',
        );
      },
    );

    test('does not merge customers by name alone', () async {
      final firestore = FakeCustomerFirestoreRestClient({
        'customers/existing': CustomerModel.fromEntity(
          _customer(id: 'existing', name: 'TBS Enterprises', phone: '1'),
        ).toMap(),
      });

      final saved = await CustomerRepository(
        firestore,
      ).findOrCreateFromInvoice(_customer(name: 'TBS Enterprises', phone: '2'));

      expect(saved.id, isNot('existing'));
      expect(saved.name, 'TBS Enterprises');
      expect(saved.phone, '2');
    });

    test(
      'preserves follow-up metadata when matched from invoice details',
      () async {
        final existing = _customer(
          id: 'cust_1',
          phone: '9655246269',
          followUpStatus: CustomerFollowUpStatus.pending,
          followUpNotes: 'Call about overdue payment',
          nextFollowUpDate: DateTime(2026, 5, 10),
        );
        final firestore = FakeCustomerFirestoreRestClient({
          'customers/cust_1': CustomerModel.fromEntity(existing).toMap(),
        });

        final saved = await CustomerRepository(firestore)
            .findOrCreateFromInvoice(
              _customer(
                phone: '9655246269',
                billingAddress: 'Updated address',
                defaultInvoiceTerms: 'Net 15',
              ),
            );

        expect(saved.id, 'cust_1');
        expect(saved.billingAddress, 'Updated address');
        expect(saved.followUpStatus, CustomerFollowUpStatus.pending);
        expect(saved.followUpNotes, 'Call about overdue payment');
        expect(saved.nextFollowUpDate, DateTime(2026, 5, 10));
      },
    );
  });
}

Customer _customer({
  String id = '',
  String name = 'TBS Enterprises',
  String phone = '9655246269',
  String email = '',
  String gstin = '',
  String billingAddress = 'Billing address',
  String defaultInvoiceTerms = '',
  int loyaltyPointsBalance = 0,
  int lifetimePointsEarned = 0,
  double totalBilled = 0,
  bool isActive = true,
  CustomerFollowUpStatus followUpStatus = CustomerFollowUpStatus.none,
  DateTime? nextFollowUpDate,
  String followUpNotes = '',
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 5, 1);
  return Customer(
    id: id,
    name: name,
    phone: phone,
    email: email,
    billingAddress: billingAddress,
    shippingAddress: '',
    gstin: gstin,
    state: 'Tamil Nadu',
    defaultDiscountType: 'none',
    defaultDiscountValue: 0,
    loyaltyEnabled: true,
    loyaltyPointsBalance: loyaltyPointsBalance,
    lifetimePointsEarned: lifetimePointsEarned,
    lifetimePointsRedeemed: 0,
    totalBilled: totalBilled,
    totalPaid: 0,
    outstandingAmount: 0,
    notes: '',
    defaultInvoiceTerms: defaultInvoiceTerms,
    followUpStatus: followUpStatus,
    nextFollowUpDate: nextFollowUpDate,
    followUpNotes: followUpNotes,
    isActive: isActive,
    createdAt: now,
    updatedAt: updatedAt ?? now,
    customFields: const {},
  );
}
