import '../entities/invoice.dart';
import '../entities/invoice_item.dart';

class InvoiceTotals {
  const InvoiceTotals({
    required this.items,
    required this.subtotal,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.grandTotal,
  });

  final List<InvoiceItem> items;
  final double subtotal;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double grandTotal;
}

class InvoiceCalculator {
  InvoiceTotals calculate({
    required List<InvoiceItem> items,
    required TaxMode taxMode,
  }) {
    final calculatedItems = items
        .map((item) => calculateItem(item: item, taxMode: taxMode))
        .toList();
    final subtotal = _sum(calculatedItems.map((item) => item.taxableAmount));
    final cgst = _sum(calculatedItems.map((item) => item.cgstAmount));
    final sgst = _sum(calculatedItems.map((item) => item.sgstAmount));
    final igst = _sum(calculatedItems.map((item) => item.igstAmount));
    return InvoiceTotals(
      items: calculatedItems,
      subtotal: subtotal,
      taxableAmount: subtotal,
      cgstAmount: cgst,
      sgstAmount: sgst,
      igstAmount: igst,
      grandTotal: subtotal + cgst + sgst + igst,
    );
  }

  InvoiceItem calculateItem({
    required InvoiceItem item,
    required TaxMode taxMode,
  }) {
    final taxable = _round(item.quantity * item.rate);
    final tax = taxMode == TaxMode.none
        ? 0.0
        : _round(taxable * item.gstRate / 100);
    final cgst = taxMode == TaxMode.cgstSgst ? _round(tax / 2) : 0.0;
    final sgst = taxMode == TaxMode.cgstSgst ? _round(tax / 2) : 0.0;
    final igst = taxMode == TaxMode.igst ? tax : 0.0;
    return item.copyWith(
      taxableAmount: taxable,
      cgstAmount: cgst,
      sgstAmount: sgst,
      igstAmount: igst,
      total: taxable + cgst + sgst + igst,
    );
  }

  double _sum(Iterable<double> values) {
    return _round(values.fold<double>(0, (total, value) => total + value));
  }

  double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}

class NumberingService {
  String financialYear(DateTime date) {
    final start = date.month >= 4 ? date.year : date.year - 1;
    final end = (start + 1).toString().substring(2);
    return '$start-$end';
  }

  String buildNumber({
    required String prefix,
    required String separator,
    required String dateFormat,
    required int sequence,
    required int padding,
    required DateTime date,
  }) {
    final segments = <String>[prefix];
    final formattedDate = _formatDate(dateFormat, date);
    if (formattedDate.isNotEmpty) segments.add(formattedDate);
    segments.add(sequence.toString().padLeft(padding, '0'));
    final cleanSeparator = separator.trim().isEmpty ? '-' : separator.trim();
    return segments
        .where((segment) => segment.trim().isNotEmpty)
        .join(cleanSeparator);
  }

  String _formatDate(String format, DateTime date) {
    final trimmed = format.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .replaceAll('yyyy', date.year.toString())
        .replaceAll('yy', date.year.toString().substring(2))
        .replaceAll('MM', date.month.toString().padLeft(2, '0'))
        .replaceAll('dd', date.day.toString().padLeft(2, '0'));
  }
}
