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
    return saveAndReturnCustomer(customer).then((_) {});
  }

  Future<Customer> saveAndReturnCustomer(Customer customer) async {
    final now = DateTime.now();
    final id = customer.id.isEmpty
        ? 'cust_${now.microsecondsSinceEpoch}'
        : customer.id;
    final saved = Customer(
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
      customFields: customer.customFields,
    );
    await _firestore.setDocument(
      'customers',
      id,
      CustomerModel.fromEntity(saved).toMap(),
    );
    return saved;
  }

  Future<Customer> findOrCreateFromInvoice(Customer customer) async {
    final customers = await fetchCustomers();
    final match = _findBestMatch(customers, customer);
    if (match != null) {
      final merged = Customer(
        id: match.id,
        name: customer.name.isEmpty ? match.name : customer.name,
        phone: customer.phone.isEmpty ? match.phone : customer.phone,
        email: customer.email.isEmpty ? match.email : customer.email,
        billingAddress: customer.billingAddress.isEmpty
            ? match.billingAddress
            : customer.billingAddress,
        shippingAddress: customer.shippingAddress.isEmpty
            ? match.shippingAddress
            : customer.shippingAddress,
        gstin: customer.gstin.isEmpty ? match.gstin : customer.gstin,
        state: customer.state.isEmpty ? match.state : customer.state,
        defaultDiscountType: match.defaultDiscountType,
        defaultDiscountValue: match.defaultDiscountValue,
        loyaltyEnabled: match.loyaltyEnabled,
        loyaltyPointsBalance: match.loyaltyPointsBalance,
        lifetimePointsEarned: match.lifetimePointsEarned,
        lifetimePointsRedeemed: match.lifetimePointsRedeemed,
        totalBilled: match.totalBilled,
        totalPaid: match.totalPaid,
        outstandingAmount: match.outstandingAmount,
        lastInvoiceAt: match.lastInvoiceAt,
        notes: match.notes,
        isActive: true,
        createdAt: match.createdAt,
        updatedAt: DateTime.now(),
        customFields: {...match.customFields, ...customer.customFields},
      );
      return saveAndReturnCustomer(merged);
    }
    return saveAndReturnCustomer(customer);
  }

  Customer? _findBestMatch(List<Customer> customers, Customer candidate) {
    final phone = candidate.phone.trim().toLowerCase();
    final email = candidate.email.trim().toLowerCase();
    final gstin = candidate.gstin.trim().toLowerCase();
    for (final customer in customers) {
      if (phone.isNotEmpty && customer.phone.toLowerCase() == phone) {
        return customer;
      }
      if (email.isNotEmpty && customer.email.toLowerCase() == email) {
        return customer;
      }
      if (gstin.isNotEmpty && customer.gstin.toLowerCase() == gstin) {
        return customer;
      }
    }
    return null;
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
      customFields: customer.customFields,
    );
    return _firestore.setDocument(
      'customers',
      customer.id,
      CustomerModel.fromEntity(archived).toMap(),
    );
  }
}
