import '../../../invoices/domain/entities/invoice.dart';
import '../../../products/domain/entities/product_service.dart';

class ProfitMarginReport {
  const ProfitMarginReport({
    required this.rows,
    required this.invoiceCount,
    required this.lineCount,
    required this.unknownCostLineCount,
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.marginPercent,
  });

  final List<ProfitMarginRow> rows;
  final int invoiceCount;
  final int lineCount;
  final int unknownCostLineCount;
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double marginPercent;
}

class ProfitMarginRow {
  const ProfitMarginRow({
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerName,
    required this.itemName,
    required this.quantity,
    required this.revenue,
    required this.unitCost,
    required this.cost,
    required this.grossProfit,
    required this.marginPercent,
    required this.costKnown,
  });

  final String invoiceNumber;
  final DateTime invoiceDate;
  final String customerName;
  final String itemName;
  final double quantity;
  final double revenue;
  final double unitCost;
  final double cost;
  final double grossProfit;
  final double marginPercent;
  final bool costKnown;
}

ProfitMarginReport buildProfitMarginReport({
  required Iterable<Invoice> invoices,
  required Iterable<ProductService> products,
  DateTime? from,
  DateTime? to,
}) {
  final fromDate = from == null ? null : _dateOnly(from);
  final toDate = to == null ? null : _dateOnly(to);
  final costByProductId = {
    for (final product in products.where((product) => product.isActive))
      product.id: product.costPrice,
  };
  final countedInvoices = invoices
      .where(_countsInReport)
      .where((invoice) => _isWithinRange(invoice.invoiceDate, fromDate, toDate))
      .toList();
  final rows = <ProfitMarginRow>[];

  for (final invoice in countedInvoices) {
    for (final item in invoice.items) {
      if (item.name.trim().isEmpty || item.quantity <= 0) continue;
      final unitCost = costByProductId[item.productId];
      final costKnown = unitCost != null;
      final revenue = _money(
        item.taxableAmount > 0 ? item.taxableAmount : item.rate * item.quantity,
      );
      final cost = costKnown ? _money(unitCost * item.quantity) : 0.0;
      final grossProfit = _money(revenue - cost);
      rows.add(
        ProfitMarginRow(
          invoiceNumber: invoice.invoiceNumber,
          invoiceDate: invoice.invoiceDate,
          customerName: invoice.customerSnapshot['name']?.toString() ?? '',
          itemName: item.name,
          quantity: item.quantity,
          revenue: revenue,
          unitCost: unitCost ?? 0,
          cost: cost,
          grossProfit: grossProfit,
          marginPercent: revenue <= 0 ? 0 : _money(grossProfit / revenue * 100),
          costKnown: costKnown,
        ),
      );
    }
  }

  rows.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
  final totalRevenue = _money(
    rows.fold<double>(0, (sum, row) => sum + row.revenue),
  );
  final totalCost = _money(rows.fold<double>(0, (sum, row) => sum + row.cost));
  final grossProfit = _money(totalRevenue - totalCost);

  return ProfitMarginReport(
    rows: rows,
    invoiceCount: countedInvoices.length,
    lineCount: rows.length,
    unknownCostLineCount: rows.where((row) => !row.costKnown).length,
    totalRevenue: totalRevenue,
    totalCost: totalCost,
    grossProfit: grossProfit,
    marginPercent: totalRevenue <= 0
        ? 0
        : _money(grossProfit / totalRevenue * 100),
  );
}

String buildProfitMarginCsv(ProfitMarginReport report) {
  final rows = [
    [
      'Invoice',
      'Date',
      'Customer',
      'Item',
      'Quantity',
      'Revenue',
      'Unit Cost',
      'Cost',
      'Gross Profit',
      'Margin %',
      'Cost Known',
    ],
    for (final row in report.rows)
      [
        row.invoiceNumber,
        _formatDate(row.invoiceDate),
        row.customerName,
        row.itemName,
        _formatNumber(row.quantity),
        _formatMoney(row.revenue),
        row.costKnown ? _formatMoney(row.unitCost) : '',
        row.costKnown ? _formatMoney(row.cost) : '',
        _formatMoney(row.grossProfit),
        _formatMoney(row.marginPercent),
        row.costKnown ? 'Yes' : 'No',
      ],
    [],
    ['Summary'],
    ['Invoices', report.invoiceCount.toString()],
    ['Lines', report.lineCount.toString()],
    ['Unknown Cost Lines', report.unknownCostLineCount.toString()],
    ['Revenue', _formatMoney(report.totalRevenue)],
    ['Cost', _formatMoney(report.totalCost)],
    ['Gross Profit', _formatMoney(report.grossProfit)],
    ['Margin %', _formatMoney(report.marginPercent)],
  ];

  return rows
      .map((row) => row.map((cell) => _csvCell(cell.toString())).join(','))
      .join('\n');
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

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatMoney(double value) => value.toStringAsFixed(2);

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

double _money(double value) => double.parse(value.toStringAsFixed(2));

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
