import '../entities/invoice.dart';
import '../entities/invoice_item.dart';

class InvoiceTotals {
  const InvoiceTotals({
    required this.items,
    required this.subtotal,
    required this.discountTotal,
    required this.taxableAmount,
    required this.extraChargeTotal,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.roundOffAmount,
    required this.grandTotal,
  });

  final List<InvoiceItem> items;
  final double subtotal;
  final double discountTotal;
  final double taxableAmount;
  final double extraChargeTotal;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double roundOffAmount;
  final double grandTotal;
}

class InvoiceCalculator {
  double rateBeforeTax({
    required double rateIncludingTax,
    required double taxRate,
  }) {
    if (rateIncludingTax <= 0) return 0;
    if (taxRate <= 0) return rateIncludingTax;
    return rateIncludingTax / (1 + taxRate / 100);
  }

  double rateIncludingTax({required double rate, required double taxRate}) {
    if (rate <= 0) return 0;
    if (taxRate <= 0) return rate;
    return rate * (1 + taxRate / 100);
  }

  String formatRateInput(double value) {
    final fixed = value.toStringAsFixed(6);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  InvoiceTotals calculate({
    required List<InvoiceItem> items,
    required TaxMode taxMode,
    bool roundOffEnabled = false,
    String discountType = 'none',
    double discountValue = 0,
    List<InvoiceCharge> extraCharges = const [],
  }) {
    final calculatedItems = items
        .map((item) => calculateItem(item: item, taxMode: taxMode))
        .toList();
    final subtotal = _sum(calculatedItems.map((item) => item.taxableAmount));
    final discountTotal = _discountTotal(
      subtotal: subtotal,
      discountType: discountType,
      discountValue: discountValue,
    );
    final taxableAmount = _round((subtotal - discountTotal).clamp(0, subtotal));
    final taxRatio = subtotal <= 0 ? 1.0 : taxableAmount / subtotal;
    final cgst = _round(
      _sum(calculatedItems.map((item) => item.cgstAmount)) * taxRatio,
    );
    final sgst = _round(
      _sum(calculatedItems.map((item) => item.sgstAmount)) * taxRatio,
    );
    final igst = _round(
      _sum(calculatedItems.map((item) => item.igstAmount)) * taxRatio,
    );
    final extraChargeTotal = _sum(
      extraCharges
          .where((charge) => charge.label.trim().isNotEmpty)
          .map((charge) => charge.amount),
    );
    final totalBeforeRoundOff = _round(
      taxableAmount + cgst + sgst + igst + extraChargeTotal,
    );
    final grandTotal = roundOffEnabled
        ? totalBeforeRoundOff.roundToDouble()
        : totalBeforeRoundOff;
    final roundOffAmount = _round(grandTotal - totalBeforeRoundOff);

    return InvoiceTotals(
      items: calculatedItems,
      subtotal: subtotal,
      discountTotal: discountTotal,
      taxableAmount: taxableAmount,
      extraChargeTotal: extraChargeTotal,
      cgstAmount: cgst,
      sgstAmount: sgst,
      igstAmount: igst,
      roundOffAmount: roundOffAmount,
      grandTotal: grandTotal,
    );
  }

  double _discountTotal({
    required double subtotal,
    required String discountType,
    required double discountValue,
  }) {
    if (subtotal <= 0 || discountValue <= 0) return 0;
    final normalizedType = discountType.trim().toLowerCase();
    final amount = switch (normalizedType) {
      'percentage' => subtotal * (discountValue / 100),
      'amount' => discountValue,
      _ => 0.0,
    };
    return _round(amount.clamp(0, subtotal));
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
