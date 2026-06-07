import '../../../invoices/domain/entities/invoice.dart';

class GstSummaryReport {
  const GstSummaryReport({
    required this.rows,
    required this.rateRows,
    required this.invoiceCount,
    required this.taxableTotal,
    required this.cgstTotal,
    required this.sgstTotal,
    required this.igstTotal,
    required this.gstTotal,
  });

  final List<GstSummaryRow> rows;
  final List<GstRateSummaryRow> rateRows;
  final int invoiceCount;
  final double taxableTotal;
  final double cgstTotal;
  final double sgstTotal;
  final double igstTotal;
  final double gstTotal;
}

class GstSummaryRow {
  const GstSummaryRow({
    required this.taxMode,
    required this.invoiceCount,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
  });

  final TaxMode taxMode;
  final int invoiceCount;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;

  double get gstAmount => cgstAmount + sgstAmount + igstAmount;
}

class GstRateSummaryRow {
  const GstRateSummaryRow({
    required this.gstRate,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
  });

  final double gstRate;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;

  double get gstAmount => cgstAmount + sgstAmount + igstAmount;
}

GstSummaryReport buildGstSummaryReport({
  required Iterable<Invoice> invoices,
  DateTime? from,
  DateTime? to,
}) {
  final fromDate = from == null ? null : _dateOnly(from);
  final toDate = to == null ? null : _dateOnly(to);
  final countedInvoices = invoices
      .where(_countsInReport)
      .where((invoice) => _isWithinRange(invoice.invoiceDate, fromDate, toDate))
      .toList();
  final rowsByMode = <TaxMode, _GstAccumulator>{};
  final rowsByRate = <double, _GstAccumulator>{};

  for (final invoice in countedInvoices) {
    rowsByMode
        .putIfAbsent(invoice.taxMode, _GstAccumulator.new)
        .addInvoice(invoice);
    for (final item in invoice.items) {
      final rate = _money(item.gstRate);
      rowsByRate
          .putIfAbsent(rate, _GstAccumulator.new)
          .addLine(
            taxableAmount: item.taxableAmount,
            cgstAmount: item.cgstAmount,
            sgstAmount: item.sgstAmount,
            igstAmount: item.igstAmount,
          );
    }
  }

  final rows = TaxMode.values.where(rowsByMode.containsKey).map((mode) {
    final value = rowsByMode[mode]!;
    return GstSummaryRow(
      taxMode: mode,
      invoiceCount: value.invoiceCount,
      taxableAmount: _money(value.taxableAmount),
      cgstAmount: _money(value.cgstAmount),
      sgstAmount: _money(value.sgstAmount),
      igstAmount: _money(value.igstAmount),
    );
  }).toList();
  final rateRows = rowsByRate.entries.map((entry) {
    final value = entry.value;
    return GstRateSummaryRow(
      gstRate: entry.key,
      taxableAmount: _money(value.taxableAmount),
      cgstAmount: _money(value.cgstAmount),
      sgstAmount: _money(value.sgstAmount),
      igstAmount: _money(value.igstAmount),
    );
  }).toList()..sort((a, b) => a.gstRate.compareTo(b.gstRate));

  final taxableTotal = _money(
    rows.fold<double>(0, (sum, row) => sum + row.taxableAmount),
  );
  final cgstTotal = _money(
    rows.fold<double>(0, (sum, row) => sum + row.cgstAmount),
  );
  final sgstTotal = _money(
    rows.fold<double>(0, (sum, row) => sum + row.sgstAmount),
  );
  final igstTotal = _money(
    rows.fold<double>(0, (sum, row) => sum + row.igstAmount),
  );

  return GstSummaryReport(
    rows: rows,
    rateRows: rateRows,
    invoiceCount: countedInvoices.length,
    taxableTotal: taxableTotal,
    cgstTotal: cgstTotal,
    sgstTotal: sgstTotal,
    igstTotal: igstTotal,
    gstTotal: _money(cgstTotal + sgstTotal + igstTotal),
  );
}

String buildGstSummaryCsv(GstSummaryReport report) {
  final rows = [
    ['GST Summary By Tax Mode'],
    ['Tax Mode', 'Invoices', 'Taxable', 'CGST', 'SGST', 'IGST', 'GST Total'],
    for (final row in report.rows)
      [
        row.taxMode.label,
        row.invoiceCount.toString(),
        _formatMoney(row.taxableAmount),
        _formatMoney(row.cgstAmount),
        _formatMoney(row.sgstAmount),
        _formatMoney(row.igstAmount),
        _formatMoney(row.gstAmount),
      ],
    [],
    ['GST Summary By Rate'],
    ['GST %', 'Taxable', 'CGST', 'SGST', 'IGST', 'GST Total'],
    for (final row in report.rateRows)
      [
        _formatNumber(row.gstRate),
        _formatMoney(row.taxableAmount),
        _formatMoney(row.cgstAmount),
        _formatMoney(row.sgstAmount),
        _formatMoney(row.igstAmount),
        _formatMoney(row.gstAmount),
      ],
    [],
    ['Summary'],
    ['Invoices', report.invoiceCount.toString()],
    ['Taxable', _formatMoney(report.taxableTotal)],
    ['CGST', _formatMoney(report.cgstTotal)],
    ['SGST', _formatMoney(report.sgstTotal)],
    ['IGST', _formatMoney(report.igstTotal)],
    ['GST Total', _formatMoney(report.gstTotal)],
  ];

  return rows
      .map((row) => row.map((cell) => _csvCell(cell.toString())).join(','))
      .join('\n');
}

class _GstAccumulator {
  var invoiceCount = 0;
  var taxableAmount = 0.0;
  var cgstAmount = 0.0;
  var sgstAmount = 0.0;
  var igstAmount = 0.0;

  void addInvoice(Invoice invoice) {
    invoiceCount += 1;
    taxableAmount += invoice.taxableAmount;
    cgstAmount += invoice.cgstAmount;
    sgstAmount += invoice.sgstAmount;
    igstAmount += invoice.igstAmount;
  }

  void addLine({
    required double taxableAmount,
    required double cgstAmount,
    required double sgstAmount,
    required double igstAmount,
  }) {
    this.taxableAmount += taxableAmount;
    this.cgstAmount += cgstAmount;
    this.sgstAmount += sgstAmount;
    this.igstAmount += igstAmount;
  }
}

bool _countsInReport(Invoice invoice) {
  return invoice.status != InvoiceStatus.draft &&
      invoice.status != InvoiceStatus.cancelled;
}

bool _isWithinRange(DateTime value, DateTime? from, DateTime? to) {
  final day = _dateOnly(value);
  if (from != null && day.isBefore(from)) return false;
  if (to != null && day.isAfter(to)) return false;
  return true;
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

String _formatMoney(double value) => value.toStringAsFixed(2);

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

double _money(double value) => double.parse(value.toStringAsFixed(2));

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
