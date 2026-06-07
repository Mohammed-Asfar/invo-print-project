import '../../../customers/domain/entities/customer.dart';
import '../../../customers/domain/services/customer_follow_up.dart';
import '../../../invoices/domain/entities/invoice.dart';

class CustomerAgingReport {
  const CustomerAgingReport({
    required this.rows,
    required this.customerCount,
    required this.openInvoiceCount,
    required this.totalOutstanding,
    required this.currentTotal,
    required this.days0To30Total,
    required this.days31To60Total,
    required this.days61To90Total,
    required this.days90PlusTotal,
    required this.asOfDate,
  });

  final List<CustomerAgingRow> rows;
  final int customerCount;
  final int openInvoiceCount;
  final double totalOutstanding;
  final double currentTotal;
  final double days0To30Total;
  final double days31To60Total;
  final double days61To90Total;
  final double days90PlusTotal;
  final DateTime asOfDate;
}

class CustomerAgingRow {
  const CustomerAgingRow({
    required this.customerId,
    required this.customerName,
    required this.openInvoiceCount,
    required this.totalOutstanding,
    required this.currentAmount,
    required this.days0To30Amount,
    required this.days31To60Amount,
    required this.days61To90Amount,
    required this.days90PlusAmount,
    required this.oldestOverdueDays,
    required this.lastInvoiceDate,
  });

  final String customerId;
  final String customerName;
  final int openInvoiceCount;
  final double totalOutstanding;
  final double currentAmount;
  final double days0To30Amount;
  final double days31To60Amount;
  final double days61To90Amount;
  final double days90PlusAmount;
  final int oldestOverdueDays;
  final DateTime? lastInvoiceDate;
}

CustomerAgingReport buildCustomerAgingReport({
  required Iterable<Customer> customers,
  required Iterable<Invoice> invoices,
  DateTime? asOfDate,
}) {
  final effectiveAsOfDate = _dateOnly(asOfDate ?? DateTime.now());
  final queue = buildCustomerFollowUpQueue(
    customers: customers,
    invoices: invoices,
    today: effectiveAsOfDate,
  );
  final rows =
      queue.rows
          .where((row) => row.outstandingBalance > 0)
          .map(
            (row) => CustomerAgingRow(
              customerId: row.customer.id,
              customerName: row.customer.name,
              openInvoiceCount: _openInvoiceCount(row.customer, invoices),
              totalOutstanding: row.outstandingBalance,
              currentAmount: row.agingBuckets[CustomerAgingBucket.current] ?? 0,
              days0To30Amount:
                  row.agingBuckets[CustomerAgingBucket.d0To30] ?? 0,
              days31To60Amount:
                  row.agingBuckets[CustomerAgingBucket.d31To60] ?? 0,
              days61To90Amount:
                  row.agingBuckets[CustomerAgingBucket.d61To90] ?? 0,
              days90PlusAmount:
                  row.agingBuckets[CustomerAgingBucket.d90Plus] ?? 0,
              oldestOverdueDays: row.oldestOverdueDays,
              lastInvoiceDate: row.lastInvoiceDate,
            ),
          )
          .toList()
        ..sort((a, b) {
          final balanceCompare = b.totalOutstanding.compareTo(
            a.totalOutstanding,
          );
          if (balanceCompare != 0) return balanceCompare;
          return a.customerName.toLowerCase().compareTo(
            b.customerName.toLowerCase(),
          );
        });

  return CustomerAgingReport(
    rows: rows,
    customerCount: rows.length,
    openInvoiceCount: rows.fold<int>(
      0,
      (sum, row) => sum + row.openInvoiceCount,
    ),
    totalOutstanding: _money(
      rows.fold<double>(0, (sum, row) => sum + row.totalOutstanding),
    ),
    currentTotal: _money(
      rows.fold<double>(0, (sum, row) => sum + row.currentAmount),
    ),
    days0To30Total: _money(
      rows.fold<double>(0, (sum, row) => sum + row.days0To30Amount),
    ),
    days31To60Total: _money(
      rows.fold<double>(0, (sum, row) => sum + row.days31To60Amount),
    ),
    days61To90Total: _money(
      rows.fold<double>(0, (sum, row) => sum + row.days61To90Amount),
    ),
    days90PlusTotal: _money(
      rows.fold<double>(0, (sum, row) => sum + row.days90PlusAmount),
    ),
    asOfDate: effectiveAsOfDate,
  );
}

String buildCustomerAgingCsv(CustomerAgingReport report) {
  final rows = [
    [
      'Customer',
      'Open Invoices',
      'Outstanding',
      'Current',
      '0-30',
      '31-60',
      '61-90',
      '90+',
      'Oldest Overdue Days',
      'Last Invoice',
    ],
    for (final row in report.rows)
      [
        row.customerName,
        row.openInvoiceCount.toString(),
        _formatMoney(row.totalOutstanding),
        _formatMoney(row.currentAmount),
        _formatMoney(row.days0To30Amount),
        _formatMoney(row.days31To60Amount),
        _formatMoney(row.days61To90Amount),
        _formatMoney(row.days90PlusAmount),
        row.oldestOverdueDays.toString(),
        row.lastInvoiceDate == null ? '' : _formatDate(row.lastInvoiceDate!),
      ],
    [],
    ['Summary'],
    ['Customers', report.customerCount.toString()],
    ['Open Invoices', report.openInvoiceCount.toString()],
    ['Outstanding', _formatMoney(report.totalOutstanding)],
    ['Current', _formatMoney(report.currentTotal)],
    ['0-30', _formatMoney(report.days0To30Total)],
    ['31-60', _formatMoney(report.days31To60Total)],
    ['61-90', _formatMoney(report.days61To90Total)],
    ['90+', _formatMoney(report.days90PlusTotal)],
  ];

  return rows
      .map((row) => row.map((cell) => _csvCell(cell.toString())).join(','))
      .join('\n');
}

int _openInvoiceCount(Customer customer, Iterable<Invoice> invoices) {
  return invoices.where((invoice) {
    if (invoice.status == InvoiceStatus.draft ||
        invoice.status == InvoiceStatus.cancelled ||
        invoice.status == InvoiceStatus.paid ||
        invoice.balanceDue <= 0) {
      return false;
    }
    if (invoice.customerId.isNotEmpty) return invoice.customerId == customer.id;
    final snapshot = invoice.customerSnapshot;
    final gstin = snapshot['gstin']?.toString().trim().toLowerCase() ?? '';
    final phone = snapshot['phone']?.toString().trim().toLowerCase() ?? '';
    final name = snapshot['name']?.toString().trim().toLowerCase() ?? '';
    return (gstin.isNotEmpty && gstin == customer.gstin.toLowerCase()) ||
        (phone.isNotEmpty && phone == customer.phone.toLowerCase()) ||
        (name.isNotEmpty && name == customer.name.toLowerCase());
  }).length;
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

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatMoney(double value) => value.toStringAsFixed(2);

double _money(double value) => double.parse(value.toStringAsFixed(2));

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
