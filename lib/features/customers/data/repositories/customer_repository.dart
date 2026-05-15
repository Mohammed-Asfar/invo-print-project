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
      defaultInvoiceTerms: customer.defaultInvoiceTerms,
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

  Future<Customer> findOrCreateFromInvoice(
    Customer customer, {
    List<Customer>? existingCustomers,
  }) async {
    final customers = existingCustomers ?? await fetchCustomers();
    final selectedMatches = customer.id.isEmpty
        ? <Customer>[]
        : customers.where((existing) => existing.id == customer.id).toList();
    final selectedMatch = selectedMatches.isEmpty
        ? null
        : selectedMatches.first;
    if (selectedMatch != null) {
      return saveAndReturnCustomer(_mergeCustomer(selectedMatch, customer));
    }

    final match = _findBestMatch(customers, customer);
    if (match != null) {
      return saveAndReturnCustomer(_mergeCustomer(match, customer));
    }
    return saveAndReturnCustomer(customer);
  }

  Customer? _findBestMatch(List<Customer> customers, Customer candidate) {
    final phone = candidate.phone.trim().toLowerCase();
    final email = candidate.email.trim().toLowerCase();
    final gstin = candidate.gstin.trim().toLowerCase();
    for (final customer in customers) {
      if (gstin.isNotEmpty && customer.gstin.toLowerCase() == gstin) {
        return customer;
      }
      if (email.isNotEmpty && customer.email.toLowerCase() == email) {
        return customer;
      }
      if (phone.isNotEmpty && customer.phone.toLowerCase() == phone) {
        return customer;
      }
    }
    return null;
  }

  Customer _mergeCustomer(Customer existing, Customer incoming) {
    return Customer(
      id: existing.id,
      name: incoming.name.isEmpty ? existing.name : incoming.name,
      phone: incoming.phone.isEmpty ? existing.phone : incoming.phone,
      email: incoming.email.isEmpty ? existing.email : incoming.email,
      billingAddress: incoming.billingAddress.isEmpty
          ? existing.billingAddress
          : incoming.billingAddress,
      shippingAddress: incoming.shippingAddress.isEmpty
          ? existing.shippingAddress
          : incoming.shippingAddress,
      gstin: incoming.gstin.isEmpty ? existing.gstin : incoming.gstin,
      state: incoming.state.isEmpty ? existing.state : incoming.state,
      defaultDiscountType: existing.defaultDiscountType,
      defaultDiscountValue: existing.defaultDiscountValue,
      loyaltyEnabled: existing.loyaltyEnabled,
      loyaltyPointsBalance: existing.loyaltyPointsBalance,
      lifetimePointsEarned: existing.lifetimePointsEarned,
      lifetimePointsRedeemed: existing.lifetimePointsRedeemed,
      totalBilled: existing.totalBilled,
      totalPaid: existing.totalPaid,
      outstandingAmount: existing.outstandingAmount,
      lastInvoiceAt: existing.lastInvoiceAt,
      notes: existing.notes,
      defaultInvoiceTerms: incoming.defaultInvoiceTerms.isEmpty
          ? existing.defaultInvoiceTerms
          : incoming.defaultInvoiceTerms,
      isActive: true,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      customFields: {...existing.customFields, ...incoming.customFields},
    );
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
      defaultInvoiceTerms: customer.defaultInvoiceTerms,
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
