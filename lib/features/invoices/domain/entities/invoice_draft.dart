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
    required this.customerStateCode,
    required this.billingAddress,
    required this.shippingEnabled,
    required this.shippingAddress,
    this.shipToName = '',
    this.shipToPhone = '',
    this.shipToEmail = '',
    this.shipToState = '',
    this.shipToPincode = '',
    this.shippingCustomFields = const {},
    this.customerCustomFields = const {},
    required this.invoiceDate,
    required this.dueDate,
    required this.taxMode,
    required this.status,
    required this.roundOffEnabled,
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
      customerStateCode: '',
      billingAddress: '',
      shippingEnabled: false,
      shippingAddress: '',
      shipToName: '',
      shipToPhone: '',
      shipToEmail: '',
      shipToState: '',
      shipToPincode: '',
      shippingCustomFields: const {},
      customerCustomFields: const {},
      invoiceDate: now,
      dueDate: now.add(const Duration(days: 15)),
      taxMode: TaxMode.cgstSgst,
      status: InvoiceStatus.unpaid,
      roundOffEnabled: false,
      items: const [
        InvoiceItem(
          productId: '',
          name: '',
          description: '',
          hsnSac: '',
          quantity: 1,
          unit: 'service',
          rate: 0,
          rateIncludingGst: 0,
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
  final String customerStateCode;
  final String billingAddress;
  final bool shippingEnabled;
  final String shippingAddress;
  final String shipToName;
  final String shipToPhone;
  final String shipToEmail;
  final String shipToState;
  final String shipToPincode;
  final Map<String, String> shippingCustomFields;
  final Map<String, String> customerCustomFields;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final TaxMode taxMode;
  final InvoiceStatus status;
  final bool roundOffEnabled;
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
      shippingAddress: shippingEnabled
          ? shippingAddress
          : existing.shippingAddress,
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
      customFields: {
        ...existing.customFields,
        ...customerCustomFields,
        if (customerStateCode.trim().isNotEmpty)
          '_builtinStateCode': customerStateCode.trim(),
      },
    );
  }

  Map<String, dynamic> get customerSnapshot {
    final snapshot = <String, dynamic>{
      'name': customerName,
      'phone': customerPhone,
      'email': customerEmail,
      'gstin': customerGstin,
      'state': customerState,
      'billingAddress': billingAddress,
      'customFields': customerCustomFields,
    };
    if (customerStateCode.trim().isNotEmpty) {
      snapshot['stateCode'] = customerStateCode.trim();
    }
    if (shippingEnabled) {
      snapshot['shippingAddress'] = shippingAddress;
      snapshot['shippedTo'] = {
        'name': shipToName,
        'phone': shipToPhone,
        'email': shipToEmail,
        'address': shippingAddress,
        'state': shipToState,
        'pincode': shipToPincode,
        'customFields': shippingCustomFields,
      };
    }
    return snapshot;
  }

  @override
  List<Object?> get props => [
    existingCustomer,
    customerName,
    customerPhone,
    customerEmail,
    customerGstin,
    customerState,
    customerStateCode,
    billingAddress,
    shippingEnabled,
    shippingAddress,
    shipToName,
    shipToPhone,
    shipToEmail,
    shipToState,
    shipToPincode,
    shippingCustomFields,
    customerCustomFields,
    invoiceDate,
    dueDate,
    taxMode,
    status,
    roundOffEnabled,
    items,
    notes,
    terms,
  ];
}
