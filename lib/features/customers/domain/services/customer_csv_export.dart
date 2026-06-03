import '../entities/customer.dart';

String buildCustomersCsv(Iterable<Customer> customers) {
  final customerList = customers.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final customFieldKeys = {
    for (final customer in customerList) ...customer.customFields.keys,
  }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final headers = [
    'Name',
    'Phone',
    'Email',
    'GSTIN',
    'State',
    'Billing Address',
    'Shipping Address',
    'Loyalty Points',
    'Outstanding',
    'Default Terms',
    'Notes',
    for (final key in customFieldKeys) 'Custom: $key',
  ];

  final rows = [
    headers,
    for (final customer in customerList)
      [
        customer.name,
        customer.phone,
        customer.email,
        customer.gstin,
        customer.state,
        customer.billingAddress,
        customer.shippingAddress,
        customer.loyaltyPointsBalance.toString(),
        customer.outstandingAmount.toStringAsFixed(2),
        customer.defaultInvoiceTerms,
        customer.notes,
        for (final key in customFieldKeys) customer.customFields[key] ?? '',
      ],
  ];

  return rows
      .map((row) => row.map((cell) => _csvCell(cell.toString())).join(','))
      .join('\n');
}

String _csvCell(String value) {
  if (!value.contains(',') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}
