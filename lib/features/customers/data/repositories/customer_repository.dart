import '../../../../core/firebase/customer_firestore_rest_client.dart';
import '../../domain/entities/customer.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  CustomerRepository(this._firestore);

  final CustomerFirestoreRestClient _firestore;

  Future<List<Customer>> fetchCustomers() async {
    final documents = await _firestore.listDocuments('customers');
    final customers =
        documents
            .map(
              (document) => CustomerModel.fromMap(document.id, document.data),
            )
            .where((customer) => customer.isActive)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return customers;
  }

  Future<void> saveCustomer(Customer customer) {
    final now = DateTime.now();
    final id = customer.id.isEmpty
        ? 'cust_${now.microsecondsSinceEpoch}'
        : customer.id;
    final model = CustomerModel.fromEntity(
      Customer(
        id: id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        billingAddress: customer.billingAddress,
        shippingAddress: customer.shippingAddress,
        gstin: customer.gstin,
        state: customer.state,
        defaultDiscountType: customer.defaultDiscountType,
        defaultDiscountValue: customer.defaultDiscountValue,
        loyaltyEnabled: customer.loyaltyEnabled,
        loyaltyPointsBalance: customer.loyaltyPointsBalance,
        lifetimePointsEarned: customer.lifetimePointsEarned,
        lifetimePointsRedeemed: customer.lifetimePointsRedeemed,
        totalBilled: customer.totalBilled,
        totalPaid: customer.totalPaid,
        outstandingAmount: customer.outstandingAmount,
        lastInvoiceAt: customer.lastInvoiceAt,
        notes: customer.notes,
        isActive: customer.isActive,
        createdAt: customer.id.isEmpty ? now : customer.createdAt,
        updatedAt: now,
      ),
    );
    return _firestore.setDocument('customers', id, model.toMap());
  }

  Future<void> archiveCustomer(Customer customer) {
    final archived = Customer(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
      email: customer.email,
      billingAddress: customer.billingAddress,
      shippingAddress: customer.shippingAddress,
      gstin: customer.gstin,
      state: customer.state,
      defaultDiscountType: customer.defaultDiscountType,
      defaultDiscountValue: customer.defaultDiscountValue,
      loyaltyEnabled: customer.loyaltyEnabled,
      loyaltyPointsBalance: customer.loyaltyPointsBalance,
      lifetimePointsEarned: customer.lifetimePointsEarned,
      lifetimePointsRedeemed: customer.lifetimePointsRedeemed,
      totalBilled: customer.totalBilled,
      totalPaid: customer.totalPaid,
      outstandingAmount: customer.outstandingAmount,
      lastInvoiceAt: customer.lastInvoiceAt,
      notes: customer.notes,
      isActive: false,
      createdAt: customer.createdAt,
      updatedAt: DateTime.now(),
    );
    return _firestore.setDocument(
      'customers',
      customer.id,
      CustomerModel.fromEntity(archived).toMap(),
    );
  }
}
