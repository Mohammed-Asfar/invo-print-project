import 'package:equatable/equatable.dart';

import '../../../customers/domain/entities/customer.dart';
import 'invoice.dart';
import 'invoice_item.dart';

class InvoiceDraft extends Equatable {
  const InvoiceDraft({
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.customerGstin,
    required this.customerState,
    required this.billingAddress,
    required this.shippingAddress,
    this.customerCustomFields = const {},
    required this.invoiceDate,
    required this.dueDate,
    required this.taxMode,
    required this.status,
    required this.items,
    required this.notes,
    required this.terms,
    this.existingCustomer,
  });

  factory InvoiceDraft.initial() {
    final now = DateTime.now();
    return InvoiceDraft(
      customerName: '',
      customerPhone: '',
      customerEmail: '',
      customerGstin: '',
      customerState: '',
      billingAddress: '',
      shippingAddress: '',
      customerCustomFields: const {},
      invoiceDate: now,
      dueDate: now.add(const Duration(days: 15)),
      taxMode: TaxMode.cgstSgst,
      status: InvoiceStatus.unpaid,
      items: const [
        InvoiceItem(
          productId: '',
          name: '',
          description: '',
          hsnSac: '',
          quantity: 1,
          unit: 'service',
          rate: 0,
          gstRate: 18,
          taxableAmount: 0,
          cgstAmount: 0,
          sgstAmount: 0,
          igstAmount: 0,
          total: 0,
        ),
      ],
      notes: '',
      terms: '',
    );
  }

  final Customer? existingCustomer;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerGstin;
  final String customerState;
  final String billingAddress;
  final String shippingAddress;
  final Map<String, String> customerCustomFields;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final TaxMode taxMode;
  final InvoiceStatus status;
  final List<InvoiceItem> items;
  final String notes;
  final String terms;

  Customer toCustomerDraft({required bool loyaltyEnabled}) {
    final existing = existingCustomer ?? Customer.empty();
    return Customer(
      id: existing.id,
      name: customerName,
      phone: customerPhone,
      email: customerEmail,
      billingAddress: billingAddress,
      shippingAddress: shippingAddress,
      gstin: customerGstin,
      state: customerState,
      defaultDiscountType: existing.defaultDiscountType,
      defaultDiscountValue: existing.defaultDiscountValue,
      loyaltyEnabled: loyaltyEnabled && existing.loyaltyEnabled,
      loyaltyPointsBalance: existing.loyaltyPointsBalance,
      lifetimePointsEarned: existing.lifetimePointsEarned,
      lifetimePointsRedeemed: existing.lifetimePointsRedeemed,
      totalBilled: existing.totalBilled,
      totalPaid: existing.totalPaid,
      outstandingAmount: existing.outstandingAmount,
      lastInvoiceAt: existing.lastInvoiceAt,
      notes: existing.notes,
      isActive: true,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      customFields: {...existing.customFields, ...customerCustomFields},
    );
  }

  Map<String, dynamic> get customerSnapshot {
    return {
      'name': customerName,
      'phone': customerPhone,
      'email': customerEmail,
      'gstin': customerGstin,
      'state': customerState,
      'billingAddress': billingAddress,
      'shippingAddress': shippingAddress,
      'customFields': customerCustomFields,
    };
  }

  @override
  List<Object?> get props => [
    existingCustomer,
    customerName,
    customerPhone,
    customerEmail,
    customerGstin,
    customerState,
    billingAddress,
    shippingAddress,
    customerCustomFields,
    invoiceDate,
    dueDate,
    taxMode,
    status,
    items,
    notes,
    terms,
  ];
}
