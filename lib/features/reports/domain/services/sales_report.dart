import '../../../invoices/domain/entities/invoice.dart';

class SalesReport {
  const SalesReport({
    required this.rows,
    required this.invoiceCount,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.totalCredited,
    required this.outstandingBalance,
    required this.customerCredit,
    required this.cgstTotal,
    required this.sgstTotal,
    required this.igstTotal,
    required this.roundOffTotal,
  });

  final List<SalesReportRow> rows;
  final int invoiceCount;
  final double totalInvoiced;
  final double totalPaid;
  final double totalCredited;
  final double outstandingBalance;
  final double customerCredit;
  final double cgstTotal;
  final double sgstTotal;
  final double igstTotal;
  final double roundOffTotal;
}

class SalesReportRow {
  const SalesReportRow({
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerName,
    required this.status,
    required this.grandTotal,
    required this.amountPaid,
    required this.creditTotal,
    required this.balanceDue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.roundOffAmount,
  });

  final String invoiceNumber;
  final DateTime invoiceDate;
  final String customerName;
  final InvoiceStatus status;
  final double grandTotal;
  final double amountPaid;
  final double creditTotal;
  final double balanceDue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double roundOffAmount;
}

SalesReport buildSalesReport({
  required Iterable<Invoice> invoices,
  DateTime? from,
  DateTime? to,
}) {
  final fromDate = from == null ? null : _dateOnly(from);
  final toDate = to == null ? null : _dateOnly(to);
  final rows =
      invoices
          .where(_countsInReport)
          .where(
            (invoice) => _isWithinRange(invoice.invoiceDate, fromDate, toDate),
          )
          .map(_rowFromInvoice)
          .toList()
        ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

  var totalInvoiced = 0.0;
  var totalPaid = 0.0;
  var totalCredited = 0.0;
  var outstandingBalance = 0.0;
  var customerCredit = 0.0;
  var cgstTotal = 0.0;
  var sgstTotal = 0.0;
  var igstTotal = 0.0;
  var roundOffTotal = 0.0;

  for (final row in rows) {
    totalInvoiced += row.grandTotal;
    totalPaid += row.amountPaid;
    totalCredited += row.creditTotal;
    if (row.balanceDue > 0) {
      outstandingBalance += row.balanceDue;
    } else if (row.balanceDue < 0) {
      customerCredit += row.balanceDue.abs();
    }
    cgstTotal += row.cgstAmount;
    sgstTotal += row.sgstAmount;
    igstTotal += row.igstAmount;
    roundOffTotal += row.roundOffAmount;
  }

  return SalesReport(
    rows: rows,
    invoiceCount: rows.length,
    totalInvoiced: _money(totalInvoiced),
    totalPaid: _money(totalPaid),
    totalCredited: _money(totalCredited),
    outstandingBalance: _money(outstandingBalance),
    customerCredit: _money(customerCredit),
    cgstTotal: _money(cgstTotal),
    sgstTotal: _money(sgstTotal),
    igstTotal: _money(igstTotal),
    roundOffTotal: _money(roundOffTotal),
  );
}

String buildSalesReportCsv(SalesReport report) {
  final rows = [
    [
      'Invoice No',
      'Date',
      'Customer',
      'Status',
      'Grand Total',
      'Paid',
      'Credits',
      'Balance Due',
      'CGST',
      'SGST',
      'IGST',
      'Round Off',
    ],
    for (final row in report.rows)
      [
        row.invoiceNumber,
        _formatDate(row.invoiceDate),
        row.customerName,
        row.status.label,
        _formatMoney(row.grandTotal),
        _formatMoney(row.amountPaid),
        _formatMoney(row.creditTotal),
        _formatMoney(row.balanceDue),
        _formatMoney(row.cgstAmount),
        _formatMoney(row.sgstAmount),
        _formatMoney(row.igstAmount),
        _formatMoney(row.roundOffAmount),
      ],
    [],
    ['Summary'],
    ['Invoice Count', report.invoiceCount.toString()],
    ['Total Invoiced', _formatMoney(report.totalInvoiced)],
    ['Total Paid', _formatMoney(report.totalPaid)],
    ['Total Credited', _formatMoney(report.totalCredited)],
    ['Outstanding Balance', _formatMoney(report.outstandingBalance)],
    ['Customer Credit', _formatMoney(report.customerCredit)],
    ['CGST', _formatMoney(report.cgstTotal)],
    ['SGST', _formatMoney(report.sgstTotal)],
    ['IGST', _formatMoney(report.igstTotal)],
    ['Round Off', _formatMoney(report.roundOffTotal)],
  ];

  return rows
      .map((row) => row.map((cell) => _csvCell(cell.toString())).join(','))
      .join('\n');
}

SalesReportRow _rowFromInvoice(Invoice invoice) {
  return SalesReportRow(
    invoiceNumber: invoice.invoiceNumber,
    invoiceDate: invoice.invoiceDate,
    customerName: invoice.customerSnapshot['name']?.toString() ?? '',
    status: invoice.status,
    grandTotal: invoice.grandTotal,
    amountPaid: _invoicePaid(invoice),
    creditTotal: invoice.creditTotal,
    balanceDue: invoice.balanceDue,
    cgstAmount: invoice.cgstAmount,
    sgstAmount: invoice.sgstAmount,
    igstAmount: invoice.igstAmount,
    roundOffAmount: invoice.roundOffAmount,
  );
}

bool _countsInReport(Invoice invoice) {
  return invoice.status != InvoiceStatus.draft &&
      invoice.status != InvoiceStatus.cancelled;
}

double _invoicePaid(Invoice invoice) {
  if (invoice.amountPaid > 0) return invoice.amountPaid;
  return invoice.paymentHistory.fold<double>(
    0,
    (sum, payment) => sum + payment.amount,
  );
}

bool _isWithinRange(DateTime value, DateTime? from, DateTime? to) {
  final day = _dateOnly(value);
  if (from != null && day.isBefore(from)) return false;
  if (to != null && day.isAfter(to)) return false;
  return true;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

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
