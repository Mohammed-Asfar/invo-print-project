import '../../../invoices/domain/entities/invoice.dart';
import '../entities/customer.dart';

class CustomerFollowUpQueue {
  const CustomerFollowUpQueue({
    required this.rows,
    required this.actionCount,
    required this.overdueCustomerCount,
    required this.reminderDueCount,
    required this.totalOverdueAmount,
  });

  final List<CustomerFollowUpRow> rows;
  final int actionCount;
  final int overdueCustomerCount;
  final int reminderDueCount;
  final double totalOverdueAmount;
}

class CustomerFollowUpRow {
  const CustomerFollowUpRow({
    required this.customer,
    required this.outstandingBalance,
    required this.overdueAmount,
    required this.overdueInvoiceCount,
    required this.lastInvoiceDate,
    required this.reminderDue,
    required this.needsAction,
  });

  final Customer customer;
  final double outstandingBalance;
  final double overdueAmount;
  final int overdueInvoiceCount;
  final DateTime? lastInvoiceDate;
  final bool reminderDue;
  final bool needsAction;
}

CustomerFollowUpQueue buildCustomerFollowUpQueue({
  required Iterable<Customer> customers,
  required Iterable<Invoice> invoices,
  DateTime? today,
}) {
  final effectiveToday = _dateOnly(today ?? DateTime.now());
  final rows = <CustomerFollowUpRow>[];

  for (final customer in customers.where((customer) => customer.isActive)) {
    final customerInvoices =
        invoices
            .where((invoice) => _countsInQueue(invoice))
            .where((invoice) => _belongsToCustomer(invoice, customer))
            .toList()
          ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

    final outstandingBalance = _money(
      customerInvoices.fold<double>(
        0,
        (sum, invoice) =>
            sum + (invoice.balanceDue > 0 ? invoice.balanceDue : 0),
      ),
    );
    final overdueInvoices = customerInvoices
        .where((invoice) => _isInvoiceOverdue(invoice, effectiveToday))
        .toList();
    final overdueAmount = _money(
      overdueInvoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.balanceDue,
      ),
    );
    final reminderDue =
        customer.nextFollowUpDate != null &&
        !_dateOnly(customer.nextFollowUpDate!).isAfter(effectiveToday);
    final needsAction =
        overdueAmount > 0 ||
        reminderDue ||
        (outstandingBalance > 0 &&
            customer.followUpStatus == CustomerFollowUpStatus.pending);

    if (!needsAction && outstandingBalance <= 0) {
      continue;
    }

    rows.add(
      CustomerFollowUpRow(
        customer: customer,
        outstandingBalance: outstandingBalance,
        overdueAmount: overdueAmount,
        overdueInvoiceCount: overdueInvoices.length,
        lastInvoiceDate: customerInvoices.isEmpty
            ? customer.lastInvoiceAt
            : customerInvoices.first.invoiceDate,
        reminderDue: reminderDue,
        needsAction: needsAction,
      ),
    );
  }

  rows.sort((a, b) {
    if (a.needsAction != b.needsAction) return a.needsAction ? -1 : 1;
    if (a.reminderDue != b.reminderDue) return a.reminderDue ? -1 : 1;
    final overdueCompare = b.overdueAmount.compareTo(a.overdueAmount);
    if (overdueCompare != 0) return overdueCompare;
    final outstandingCompare = b.outstandingBalance.compareTo(
      a.outstandingBalance,
    );
    if (outstandingCompare != 0) return outstandingCompare;
    return a.customer.name.toLowerCase().compareTo(
      b.customer.name.toLowerCase(),
    );
  });

  return CustomerFollowUpQueue(
    rows: rows,
    actionCount: rows.where((row) => row.needsAction).length,
    overdueCustomerCount: rows.where((row) => row.overdueAmount > 0).length,
    reminderDueCount: rows.where((row) => row.reminderDue).length,
    totalOverdueAmount: _money(
      rows.fold<double>(0, (sum, row) => sum + row.overdueAmount),
    ),
  );
}

String buildCustomerFollowUpCsv(CustomerFollowUpQueue queue) {
  final rows = [
    [
      'Customer',
      'Status',
      'Outstanding',
      'Overdue Amount',
      'Overdue Invoices',
      'Reminder Due',
      'Last Invoice',
      'Last Contacted',
      'Next Follow-up',
      'Follow-up Notes',
    ],
    for (final row in queue.rows)
      [
        row.customer.name,
        row.customer.followUpStatus.label,
        row.outstandingBalance.toStringAsFixed(2),
        row.overdueAmount.toStringAsFixed(2),
        row.overdueInvoiceCount.toString(),
        row.reminderDue ? 'Yes' : 'No',
        row.lastInvoiceDate == null ? '' : _date(row.lastInvoiceDate!),
        row.customer.lastContactedAt == null
            ? ''
            : _date(row.customer.lastContactedAt!),
        row.customer.nextFollowUpDate == null
            ? ''
            : _date(row.customer.nextFollowUpDate!),
        row.customer.followUpNotes,
      ],
    [],
    ['Summary'],
    ['Action Queue', queue.actionCount.toString()],
    ['Overdue Customers', queue.overdueCustomerCount.toString()],
    ['Reminders Due', queue.reminderDueCount.toString()],
    ['Overdue Amount', queue.totalOverdueAmount.toStringAsFixed(2)],
  ];

  return rows
      .map((row) => row.map((cell) => _csvCell(cell.toString())).join(','))
      .join('\n');
}

bool _countsInQueue(Invoice invoice) {
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

bool _isInvoiceOverdue(Invoice invoice, DateTime today) {
  if (invoice.balanceDue <= 0) return false;
  if (invoice.status == InvoiceStatus.paid ||
      invoice.status == InvoiceStatus.cancelled) {
    return false;
  }
  return _dateOnly(invoice.dueDate).isBefore(today);
}

double _money(double value) => double.parse(value.toStringAsFixed(2));

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _csvCell(String value) {
  if (!value.contains(',') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}
