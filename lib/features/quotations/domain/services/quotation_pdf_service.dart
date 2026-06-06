import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../company/domain/entities/app_settings.dart';
import '../../../company/domain/entities/company_profile.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/entities/invoice_item.dart';
import '../entities/quotation.dart';

class QuotationPdfService {
  const QuotationPdfService();

  Future<Uint8List> buildQuotationPdf({
    required Quotation quotation,
    required String currencySymbol,
    CompanyProfile? currentCompanyProfile,
    AppSettings? settings,
  }) async {
    final companyData = _companyData(
      quotation.companySnapshot,
      fallbackProfile: currentCompanyProfile,
    );
    final customerData = _customerData(quotation.customerSnapshot);
    final logoBytes = _decodeBase64Image(companyData.logoBase64);
    final showHsn =
        (settings?.showLineItemHsn ?? true) &&
        quotation.items.any((item) => item.hsnSac.trim().isNotEmpty);
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 20, 24, 28),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        footer: (_) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'For Authorised Signatory',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        build: (_) => [
          _header(quotation, companyData, logoBytes),
          pw.SizedBox(height: 10),
          _divider(),
          pw.SizedBox(height: 8),
          _meta(quotation),
          pw.SizedBox(height: 10),
          _partyBlock(customerData),
          pw.SizedBox(height: 12),
          _itemsTable(
            quotation.items,
            showHsn: showHsn,
            currencySymbol: currencySymbol,
          ),
          pw.SizedBox(height: 8),
          _totals(quotation, currencySymbol),
          if (quotation.notes.trim().isNotEmpty ||
              quotation.terms.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            if (quotation.notes.trim().isNotEmpty)
              pw.Text(
                'Notes: ${quotation.notes.trim()}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            if (quotation.terms.trim().isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  'Terms: ${quotation.terms.trim()}',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ),
          ],
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _header(
    Quotation quotation,
    _QuotationCompanyData company,
    Uint8List? logoBytes,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 130,
          child: logoBytes == null
              ? pw.SizedBox()
              : pw.Image(
                  pw.MemoryImage(logoBytes),
                  height: 72,
                  fit: pw.BoxFit.contain,
                  alignment: pw.Alignment.centerLeft,
                ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'QUOTATION',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                company.displayName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              for (final line in company.lines)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1.5),
                  child: pw.Text(
                    line,
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _meta(Quotation quotation) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'Quotation No: ${quotation.quotationNumber}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          'Date: ${_date(quotation.quotationDate)}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(width: 18),
        pw.Text(
          'Valid Until: ${_date(quotation.validUntil)}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _partyBlock(List<_QuotationField> fields) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Quoted To:',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        for (final field in fields)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 58,
                  child: pw.Text(
                    '${field.label}:',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    field.value,
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _itemsTable(
    List<InvoiceItem> items, {
    required bool showHsn,
    required String currencySymbol,
  }) {
    final headers = [
      'S.No',
      'Description',
      if (showHsn) 'HSN/SAC',
      'Qty',
      'Unit',
      'Rate',
      'Amount',
    ];
    final data = [
      for (var index = 0; index < items.length; index++)
        [
          '${index + 1}',
          _itemLabel(items[index]),
          if (showHsn) items[index].hsnSac.trim(),
          _number(items[index].quantity),
          items[index].unit.trim(),
          items[index].rate.toStringAsFixed(2),
          items[index].total.toStringAsFixed(2),
        ],
    ];
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    );
  }

  pw.Widget _totals(Quotation quotation, String currencySymbol) {
    final rows = [
      _AmountRow('Sub-Total', quotation.subtotal),
      if (quotation.discountTotal > 0)
        _AmountRow('Discount', -quotation.discountTotal, signed: true),
      if (quotation.extraChargeTotal > 0)
        _AmountRow('Extra Charges', quotation.extraChargeTotal, signed: true),
      if (quotation.taxMode == TaxMode.cgstSgst) ...[
        _AmountRow('CGST', quotation.cgstAmount),
        _AmountRow('SGST', quotation.sgstAmount),
      ],
      if (quotation.taxMode == TaxMode.igst)
        _AmountRow('IGST', quotation.igstAmount),
      if (quotation.roundOffEnabled && quotation.roundOffAmount != 0)
        _AmountRow('Round Off', quotation.roundOffAmount, signed: true),
      _AmountRow('Total', quotation.grandTotal, strong: true),
    ];
    return pw.Column(
      children: [
        for (final row in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '${row.label}:',
                    style: pw.TextStyle(
                      fontSize: row.strong ? 9 : 8.3,
                      fontWeight: row.strong
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 100,
                  child: pw.Text(
                    row.signed
                        ? _signedMoney(row.amount, currencySymbol)
                        : _money(row.amount, currencySymbol),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: row.strong ? 9 : 8.3,
                      fontWeight: row.strong
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _divider() => pw.Container(height: 1, color: PdfColors.black);

  _QuotationCompanyData _companyData(
    Map<String, dynamic> snapshot, {
    CompanyProfile? fallbackProfile,
  }) {
    final displayName = _fallback(
      snapshot['businessName'],
      fallbackProfile?.businessName ?? '',
    );
    final address = _join([
      _fallback(snapshot['addressLine1'], fallbackProfile?.addressLine1 ?? ''),
      _fallback(snapshot['addressLine2'], fallbackProfile?.addressLine2 ?? ''),
      _fallback(snapshot['city'], fallbackProfile?.city ?? ''),
      _fallback(snapshot['state'], fallbackProfile?.state ?? ''),
      _fallback(snapshot['pincode'], fallbackProfile?.pincode ?? ''),
      _fallback(snapshot['country'], fallbackProfile?.country ?? ''),
    ]);
    final phone = _fallback(snapshot['phone'], fallbackProfile?.phone ?? '');
    final email = _fallback(snapshot['email'], fallbackProfile?.email ?? '');
    final gstin = _fallback(snapshot['gstin'], fallbackProfile?.gstin ?? '');
    return _QuotationCompanyData(
      displayName: displayName,
      logoBase64: _fallback(
        snapshot['logoBase64'],
        fallbackProfile?.logoBase64 ?? '',
      ),
      lines: [
        if (address.isNotEmpty) address,
        if (phone.isNotEmpty) 'Mobile: $phone',
        if (gstin.isNotEmpty) 'GSTIN/UIN: $gstin',
        if (email.isNotEmpty) 'Email: $email',
      ],
    );
  }

  List<_QuotationField> _customerData(Map<String, dynamic> snapshot) {
    final fields = <_QuotationField>[
      _field('Name', snapshot['name']),
      _field('Address', snapshot['billingAddress']),
      _field('Mobile', snapshot['phone']),
      _field('Email', snapshot['email']),
      _field('GSTIN', snapshot['gstin']),
      _field('State', snapshot['state']),
    ];
    return fields.where((field) => field.value.trim().isNotEmpty).toList();
  }

  _QuotationField _field(String label, dynamic value) {
    return _QuotationField(label, value?.toString().trim() ?? '');
  }

  String _itemLabel(InvoiceItem item) {
    return [
      item.name.trim(),
      if (item.description.trim().isNotEmpty) item.description.trim(),
    ].join('\n');
  }

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _money(double value, String currencySymbol) {
    return '$currencySymbol ${value.toStringAsFixed(2)}';
  }

  String _signedMoney(double value, String currencySymbol) {
    if (value > 0) return '+ ${_money(value, currencySymbol)}';
    if (value < 0) return '- ${_money(value.abs(), currencySymbol)}';
    return _money(0, currencySymbol);
  }

  String _number(double value) {
    final rounded = value.roundToDouble();
    return (value - rounded).abs() < 0.000001
        ? rounded.toInt().toString()
        : value.toStringAsFixed(2);
  }

  String _join(List<String> parts) {
    return parts.where((part) => part.trim().isNotEmpty).join(', ');
  }

  String _fallback(dynamic primary, String secondary) {
    final first = primary?.toString().trim() ?? '';
    return first.isNotEmpty ? first : secondary.trim();
  }

  Uint8List? _decodeBase64Image(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      final normalized = trimmed.contains(',')
          ? trimmed.substring(trimmed.indexOf(',') + 1)
          : trimmed;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }
}

class _QuotationCompanyData {
  const _QuotationCompanyData({
    required this.displayName,
    required this.logoBase64,
    required this.lines,
  });

  final String displayName;
  final String logoBase64;
  final List<String> lines;
}

class _QuotationField {
  const _QuotationField(this.label, this.value);

  final String label;
  final String value;
}

class _AmountRow {
  const _AmountRow(
    this.label,
    this.amount, {
    this.signed = false,
    this.strong = false,
  });

  final String label;
  final double amount;
  final bool signed;
  final bool strong;
}
