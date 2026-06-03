import '../../../invoices/domain/entities/invoice.dart';
import '../entities/customer.dart';

class CustomerLedger {
  const CustomerLedger({
    required this.customer,
    required this.invoices,
    required this.entries,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.totalCredited,
    required this.outstandingBalance,
    required this.creditBalance,
    required this.loyaltyPoints,
  });

  final Customer customer;
  final List<Invoice> invoices;
  final List<CustomerLedgerEntry> entries;
  final double totalInvoiced;
  final double totalPaid;
  final double totalCredited;
  final double outstandingBalance;
  final double creditBalance;
  final int loyaltyPoints;
}

class CustomerLedgerEntry {
  const CustomerLedgerEntry({
    required this.date,
    required this.type,
    required this.reference,
    required this.amount,
    this.description = '',
  });

  final DateTime date;
  final CustomerLedgerEntryType type;
  final String reference;
  final double amount;
  final String description;
}

enum CustomerLedgerEntryType {
  invoice,
  payment,
  credit;

  String get label => switch (this) {
    CustomerLedgerEntryType.invoice => 'Invoice',
    CustomerLedgerEntryType.payment => 'Payment',
    CustomerLedgerEntryType.credit => 'Credit',
  };
}

CustomerLedger buildCustomerLedger({
  required Customer customer,
  required Iterable<Invoice> invoices,
}) {
  final customerInvoices =
      invoices
          .where((invoice) => _belongsToCustomer(invoice, customer))
          .where(_countsInLedger)
          .toList()
        ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

  final entries = <CustomerLedgerEntry>[];
  var totalInvoiced = 0.0;
  var totalPaid = 0.0;
  var totalCredited = 0.0;
  var outstandingBalance = 0.0;
  var creditBalance = 0.0;
  var loyaltyPoints = customer.loyaltyPointsBalance;

  for (final invoice in customerInvoices) {
    final paymentHistoryTotal = invoice.paymentHistory.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final invoicePaid = invoice.amountPaid > 0
        ? invoice.amountPaid
        : paymentHistoryTotal;
    totalInvoiced += invoice.grandTotal;
    totalPaid += invoicePaid;
    totalCredited += invoice.creditTotal;
    if (invoice.balanceDue > 0) {
      outstandingBalance += invoice.balanceDue;
    } else if (invoice.balanceDue < 0) {
      creditBalance += invoice.balanceDue.abs();
    }
    loyaltyPoints += invoice.pointsEarned;

    entries.add(
      CustomerLedgerEntry(
        date: invoice.invoiceDate,
        type: CustomerLedgerEntryType.invoice,
        reference: invoice.invoiceNumber,
        amount: invoice.grandTotal,
        description: invoice.status.label,
      ),
    );

    for (final payment in invoice.paymentHistory) {
      entries.add(
        CustomerLedgerEntry(
          date: payment.paidAt,
          type: CustomerLedgerEntryType.payment,
          reference: payment.reference.trim().isNotEmpty
              ? payment.reference.trim()
              : invoice.invoiceNumber,
          amount: -payment.amount,
          description: payment.method.trim(),
        ),
      );
    }

    for (final credit in invoice.creditNotes) {
      entries.add(
        CustomerLedgerEntry(
          date: credit.issuedAt,
          type: CustomerLedgerEntryType.credit,
          reference: credit.reference.trim().isNotEmpty
              ? credit.reference.trim()
              : invoice.invoiceNumber,
          amount: -credit.amount,
          description: credit.reason.trim(),
        ),
      );
    }
  }

  entries.sort((a, b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;
    return a.type.index.compareTo(b.type.index);
  });

  return CustomerLedger(
    customer: customer,
    invoices: customerInvoices,
    entries: entries,
    totalInvoiced: _money(totalInvoiced),
    totalPaid: _money(totalPaid),
    totalCredited: _money(totalCredited),
    outstandingBalance: _money(outstandingBalance),
    creditBalance: _money(creditBalance),
    loyaltyPoints: loyaltyPoints,
  );
}

bool _countsInLedger(Invoice invoice) {
  return invoice.status != InvoiceStatus.draft &&
      invoice.status != InvoiceStatus.cancelled;
}

bool _belongsToCustomer(Invoice invoice, Customer customer) {
  if (invoice.customerId.isNotEmpty) {
    return invoice.customerId == customer.id;
  }
  final snapshot = invoice.customerSnapshot;
  final gstin = snapshot['gstin']?.toString().trim().toLowerCase() ?? '';
  if (gstin.isNotEmpty && gstin == customer.gstin.trim().toLowerCase()) {
    return true;
  }
  final phone = snapshot['phone']?.toString().trim().toLowerCase() ?? '';
  if (phone.isNotEmpty && phone == customer.phone.trim().toLowerCase()) {
    return true;
  }
  final name = snapshot['name']?.toString().trim().toLowerCase() ?? '';
  return name.isNotEmpty && name == customer.name.trim().toLowerCase();
}

double _money(double value) => double.parse(value.toStringAsFixed(2));
