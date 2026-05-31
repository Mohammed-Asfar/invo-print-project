import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../company/domain/entities/app_settings.dart';
import '../../../company/domain/entities/company_profile.dart';
import '../entities/invoice.dart';
import '../entities/invoice_item.dart';
import 'invoice_output_builder.dart';

class InvoicePdfService {
  const InvoicePdfService(this._outputBuilder);

  final InvoiceOutputBuilder _outputBuilder;

  Future<Uint8List> buildInvoicePdf({
    required Invoice invoice,
    required String currencySymbol,
    CompanyProfile? currentCompanyProfile,
    AppSettings? settings,
  }) async {
    final companyData = _companyData(
      invoice.companySnapshot,
      fallbackProfile: currentCompanyProfile,
    );
    final customerData = _customerData(invoice.customerSnapshot);
    final shippedToData = _shippedToData(invoice.customerSnapshot['shippedTo']);
    final paymentData = _outputBuilder.buildPaymentDataFromSnapshot(
      companySnapshot: invoice.companySnapshot,
      fallbackProfile: currentCompanyProfile,
      invoiceNumber: invoice.invoiceNumber,
      grandTotal: invoice.balanceDue > 0
          ? invoice.balanceDue
          : invoice.grandTotal,
    );
    final logoBytes = _decodeBase64Image(companyData.logoBase64);
    final itemHasHsn =
        (settings?.showLineItemHsn ?? true) &&
        invoice.items.any((item) => item.hsnSac.trim().isNotEmpty);
    final itemCustomFieldNames = <String>{
      for (final item in invoice.items) ...item.customFields.keys,
    }.toList();
    final isDraft = invoice.status == InvoiceStatus.draft;
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 24),
          buildForeground: isDraft ? (_) => _buildDraftWatermark() : null,
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: _buildSignatureFooter(),
        ),
        build: (context) => [
          _buildTopHeader(
            invoice: invoice,
            companyData: companyData,
            logoBytes: logoBytes,
            isDraft: isDraft,
          ),
          pw.SizedBox(height: 10),
          _divider(),
          pw.SizedBox(height: 8),
          _buildInvoiceMeta(invoice),
          pw.SizedBox(height: 8),
          _buildPartySection(
            customerData: customerData,
            shippedToData: shippedToData,
          ),
          pw.SizedBox(height: 12),
          _buildItemsTable(
            invoice.items,
            currencySymbol: currencySymbol,
            showHsn: itemHasHsn,
            customFieldNames: itemCustomFieldNames,
          ),
          pw.SizedBox(height: 8),
          _buildTotalsAndWords(invoice, currencySymbol: currencySymbol),
          if (companyData.bankFields.isNotEmpty || paymentData != null) ...[
            pw.SizedBox(height: 12),
            _buildPaymentAndBankDetails(
              companyData: companyData,
              paymentData: paymentData,
              currencySymbol: currencySymbol,
            ),
          ],
          if (invoice.paymentHistory.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _buildPaymentHistory(invoice, currencySymbol: currencySymbol),
          ],
          if (invoice.notes.trim().isNotEmpty ||
              invoice.terms.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _buildNotesAndTerms(invoice),
          ],
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _buildTopHeader({
    required Invoice invoice,
    required _PdfCompanyData companyData,
    required Uint8List? logoBytes,
    required bool isDraft,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 120),
            pw.Column(
              children: [
                pw.Text(
                  invoice.taxMode == TaxMode.none ? 'INVOICE' : 'TAX INVOICE',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '(ORIGINAL FOR RECIPIENT)',
                  style: const pw.TextStyle(fontSize: 6.5),
                ),
                if (isDraft) ...[pw.SizedBox(height: 5), _buildDraftBadge()],
              ],
            ),
            pw.SizedBox(width: 120),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 160,
              child: logoBytes == null
                  ? pw.Container()
                  : pw.Image(
                      pw.MemoryImage(logoBytes),
                      height: 82,
                      fit: pw.BoxFit.contain,
                      alignment: pw.Alignment.centerLeft,
                    ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    companyData.displayName,
                    style: pw.TextStyle(
                      fontSize: 19,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  for (final line in companyData.addressLines)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 1.5),
                      child: pw.Text(
                        line,
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 8.2),
                      ),
                    ),
                  pw.SizedBox(height: 2),
                  for (final line in companyData.contactLines)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 1),
                      child: pw.Text(
                        line,
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 8.8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildDraftBadge() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.red700, width: 0.8),
      ),
      child: pw.Text(
        'DRAFT',
        style: pw.TextStyle(
          color: PdfColors.red700,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _buildDraftWatermark() {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Center(
        child: pw.Opacity(
          opacity: 0.08,
          child: pw.Transform.rotate(
            angle: -math.pi / 6,
            child: pw.Text(
              'DRAFT',
              style: pw.TextStyle(
                color: PdfColors.grey700,
                fontSize: 86,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  pw.Widget _buildInvoiceMeta(Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            'Invoice No: ${invoice.invoiceNumber}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          'Date: ${_formatDateLong(invoice.invoiceDate)}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildPartySection({
    required _PdfPartyData customerData,
    required _PdfPartyData shippedToData,
  }) {
    if (shippedToData.visibleFields.isEmpty) {
      return _buildPartyBlock('Billed To', customerData.visibleFields);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildPartyBlock('Billed To', customerData.visibleFields),
        ),
        pw.SizedBox(width: 18),
        pw.Expanded(
          child: _buildPartyBlock('Shipped To', shippedToData.visibleFields),
        ),
      ],
    );
  }

  pw.Widget _buildPartyBlock(String title, List<InvoiceOutputField> fields) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$title:',
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
                  width: 60,
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

  pw.Widget _buildItemsTable(
    List<InvoiceItem> items, {
    required String currencySymbol,
    required bool showHsn,
    required List<String> customFieldNames,
  }) {
    final headers = <String>[
      'S.No',
      'Description',
      if (showHsn) 'HSN/SAC',
      'Qty',
      'Unit',
      'Rate',
      'Amount',
      ...customFieldNames,
    ];

    final rows = <List<String>>[];
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      rows.add([
        '${index + 1}',
        _itemLabel(item),
        if (showHsn) item.hsnSac.trim(),
        _formatNumber(item.quantity),
        item.unit.trim(),
        _formatMoneyPlain(item.rate),
        _formatMoneyPlain(item.total),
        for (final fieldName in customFieldNames)
          item.customFields[fieldName]?.trim() ?? '',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 7.2),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        for (var i = 2; i < headers.length; i++) i: pw.Alignment.center,
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        for (var i = 2; i < headers.length; i++) i: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(26),
        1: const pw.FlexColumnWidth(3.2),
        if (showHsn) 2: const pw.FixedColumnWidth(52),
      },
    );
  }

  pw.Widget _buildTotalsAndWords(
    Invoice invoice, {
    required String currencySymbol,
  }) {
    final totalRows = <_AmountRow>[
      _AmountRow('Sub-Total', invoice.subtotal),
      if (invoice.discountTotal > 0)
        _AmountRow('Discount', -invoice.discountTotal, signed: true),
      if (invoice.extraChargeTotal > 0)
        _AmountRow('Extra Charges', invoice.extraChargeTotal, signed: true),
      if (invoice.taxMode == TaxMode.cgstSgst) ...[
        _AmountRow(
          'OUTPUT CGST @ ${_formatNumber(invoice.items.isEmpty ? 0 : invoice.items.first.gstRate / 2)}%',
          invoice.cgstAmount,
        ),
        _AmountRow(
          'OUTPUT SGST @ ${_formatNumber(invoice.items.isEmpty ? 0 : invoice.items.first.gstRate / 2)}%',
          invoice.sgstAmount,
        ),
      ],
      if (invoice.taxMode == TaxMode.igst)
        _AmountRow(
          'OUTPUT IGST @ ${_formatNumber(invoice.items.isEmpty ? 0 : invoice.items.first.gstRate)}%',
          invoice.igstAmount,
        ),
      if (invoice.roundOffEnabled && invoice.roundOffAmount != 0)
        _AmountRow('Round Off', invoice.roundOffAmount, signed: true),
      _AmountRow('Total', invoice.grandTotal, strong: true),
      if (invoice.amountPaid > 0) _AmountRow('Amount Paid', invoice.amountPaid),
      if (invoice.amountPaid > 0 || invoice.balanceDue > 0)
        _AmountRow('Balance Due', invoice.balanceDue, strong: true),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final row in totalRows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '${row.label}:',
                    style: pw.TextStyle(
                      fontSize: row.strong ? 9 : 8.2,
                      fontWeight: row.strong
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
                pw.SizedBox(
                  width: 96,
                  child: pw.Text(
                    row.signed
                        ? _formatSignedMoney(row.amount, currencySymbol)
                        : _formatMoney(row.amount, currencySymbol),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: row.strong ? 9 : 8.2,
                      fontWeight: row.strong
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Total in Words: ${_numberToWords(invoice.grandTotal)} Only',
          style: pw.TextStyle(fontSize: 8.3, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildPaymentAndBankDetails({
    required _PdfCompanyData companyData,
    required InvoicePaymentData? paymentData,
    required String currencySymbol,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (companyData.bankFields.isNotEmpty)
                pw.Text(
                  'Company Bank Details:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              for (final field in companyData.bankFields)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    '${field.label}: ${field.value}',
                    style: const pw.TextStyle(fontSize: 8.2),
                  ),
                ),
            ],
          ),
        ),
        if (paymentData != null) ...[
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                width: 76,
                height: 76,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.6),
                ),
                child: paymentData.isDynamic
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: paymentData.qrPayload,
                        ),
                      )
                    : pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Image(
                          pw.MemoryImage(paymentData.imageBytes!),
                          fit: pw.BoxFit.contain,
                        ),
                      ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                paymentData.label,
                style: const pw.TextStyle(fontSize: 7.2),
              ),
              pw.Text(
                _formatMoney(paymentData.amount, currencySymbol),
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  pw.Widget _buildNotesAndTerms(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (invoice.notes.trim().isNotEmpty)
          pw.Text(
            'Notes: ${invoice.notes.trim()}',
            style: const pw.TextStyle(fontSize: 8.2),
          ),
        if (invoice.terms.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'Terms: ${invoice.terms.trim()}',
              style: const pw.TextStyle(fontSize: 8.2),
            ),
          ),
      ],
    );
  }

  pw.Widget _buildPaymentHistory(
    Invoice invoice, {
    required String currencySymbol,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Payment History:',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        for (final payment in invoice.paymentHistory)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              '${_formatDateLong(payment.paidAt)} - ${_formatMoney(payment.amount, currencySymbol)}'
              '${payment.method.trim().isNotEmpty ? ' via ${payment.method.trim()}' : ''}'
              '${payment.reference.trim().isNotEmpty ? ' (${payment.reference.trim()})' : ''}'
              '${payment.notes.trim().isNotEmpty ? ' - ${payment.notes.trim()}' : ''}',
              style: const pw.TextStyle(fontSize: 8.2),
            ),
          ),
      ],
    );
  }

  pw.Widget _buildSignatureFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          "Customer's Seal & Signature",
          style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'For Authorised Signatory',
          style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _divider() {
    return pw.Container(height: 1, color: PdfColors.black);
  }

  _PdfCompanyData _companyData(
    Map<String, dynamic> snapshot, {
    CompanyProfile? fallbackProfile,
  }) {
    final addressLine1 = _fallback(
      snapshot['addressLine1'],
      fallbackProfile?.addressLine1 ?? '',
    );
    final addressLine2 = _fallback(
      snapshot['addressLine2'],
      fallbackProfile?.addressLine2 ?? '',
    );
    final city = _fallback(snapshot['city'], fallbackProfile?.city ?? '');
    final state = _fallback(snapshot['state'], fallbackProfile?.state ?? '');
    final pincode = _fallback(
      snapshot['pincode'],
      fallbackProfile?.pincode ?? '',
    );
    final country = _fallback(
      snapshot['country'],
      fallbackProfile?.country ?? '',
    );

    final phone = _fallback(snapshot['phone'], fallbackProfile?.phone ?? '');
    final gstin = _fallback(snapshot['gstin'], fallbackProfile?.gstin ?? '');
    final email = _fallback(snapshot['email'], fallbackProfile?.email ?? '');
    final website = _fallback(
      snapshot['website'],
      fallbackProfile?.website ?? '',
    );
    final stateCode = _extractStateCode(snapshot);
    final upiId = _fallback(snapshot['upiId'], fallbackProfile?.upiId ?? '');

    final addressLines = <String>[
      if (addressLine1.isNotEmpty) addressLine1,
      if (addressLine2.isNotEmpty) addressLine2,
      _joinNonEmpty([city, state, pincode, country]),
    ].where((line) => line.trim().isNotEmpty).toList();

    final contactLines = <String>[
      if (phone.isNotEmpty) 'Mobile: $phone',
      if (gstin.isNotEmpty) 'GSTIN/UIN: $gstin',
      if (state.isNotEmpty || stateCode.isNotEmpty)
        'State: ${[if (state.isNotEmpty) state, if (stateCode.isNotEmpty) 'Code: $stateCode'].join(', ')}',
      if (email.isNotEmpty) 'Email: $email',
      if (website.isNotEmpty) website,
    ];

    final bankFields = _outputBuilder.visibleFields(
      {
        'bankName': _fallback(
          snapshot['bankName'],
          fallbackProfile?.bankName ?? '',
        ),
        'bankAccountName': _fallback(
          snapshot['bankAccountName'],
          fallbackProfile?.bankAccountName ?? '',
        ),
        'bankAccountNumber': _fallback(
          snapshot['bankAccountNumber'],
          fallbackProfile?.bankAccountNumber ?? '',
        ),
        'ifscCode': _fallback(
          snapshot['ifscCode'],
          fallbackProfile?.ifscCode ?? '',
        ),
        'upiId': upiId,
      },
      const {
        'bankName': 'Bank Name',
        'bankAccountName': 'A/c Name',
        'bankAccountNumber': 'A/c No',
        'ifscCode': 'IFSC',
        'upiId': 'UPI ID',
      },
    );

    return _PdfCompanyData(
      displayName: _fallback(
        snapshot['businessName'],
        fallbackProfile?.businessName ?? '',
      ),
      logoBase64: _fallback(
        snapshot['logoBase64'],
        fallbackProfile?.logoBase64 ?? '',
      ),
      addressLines: addressLines,
      contactLines: contactLines,
      bankFields: bankFields,
    );
  }

  _PdfPartyData _customerData(Map<String, dynamic> snapshot) {
    final customFields = _mapStringMap(snapshot['customFields']);
    final visibleCustomFields = Map<String, String>.fromEntries(
      customFields.entries.where((entry) => !_isStateCodeField(entry.key)),
    );
    final fields = _outputBuilder.visibleFields(
      {
        'name': snapshot['name'],
        'address': snapshot['billingAddress'],
        'phone': snapshot['phone'],
        'email': snapshot['email'],
        'gstin': snapshot['gstin'],
        'stateCode': _extractStateCode(snapshot),
        'state': snapshot['state'],
        ...visibleCustomFields,
      },
      {
        'name': 'Name',
        'address': 'Address',
        'phone': 'Mobile',
        'email': 'Email',
        'gstin': 'GSTIN',
        'state': 'State',
        'stateCode': 'State Code',
        for (final key in visibleCustomFields.keys) key: key,
      },
    );
    return _PdfPartyData(visibleFields: fields);
  }

  _PdfPartyData _shippedToData(dynamic source) {
    final shippedTo = source is Map<String, dynamic>
        ? source
        : source is Map
        ? Map<String, dynamic>.from(source)
        : <String, dynamic>{};
    final customFields = _mapStringMap(shippedTo['customFields']);
    final visibleCustomFields = Map<String, String>.fromEntries(
      customFields.entries.where((entry) => !_isStateCodeField(entry.key)),
    );
    final fields = _outputBuilder.visibleFields(
      {
        'name': shippedTo['name'],
        'address': shippedTo['address'],
        'phone': shippedTo['phone'],
        'email': shippedTo['email'],
        'state': shippedTo['state'],
        'stateCode': _extractStateCode(shippedTo),
        'pincode': shippedTo['pincode'],
        ...visibleCustomFields,
      },
      {
        'name': 'Name',
        'address': 'Address',
        'phone': 'Mobile',
        'email': 'Email',
        'state': 'State',
        'stateCode': 'State Code',
        'pincode': 'Pincode',
        for (final key in visibleCustomFields.keys) key: key,
      },
    );
    return _PdfPartyData(visibleFields: fields);
  }

  String _extractStateCode(Map<String, dynamic> snapshot) {
    final topLevel = _readString(snapshot['stateCode']);
    if (topLevel.isNotEmpty) return topLevel;
    final customFields = _mapStringMap(snapshot['customFields']);
    final reserved = customFields['_builtinStateCode']?.trim() ?? '';
    if (reserved.isNotEmpty) return reserved;
    for (final entry in customFields.entries) {
      if (_isStateCodeField(entry.key)) {
        return entry.value.trim();
      }
    }
    return '';
  }

  bool _isStateCodeField(String value) {
    final key = value.trim().toLowerCase();
    return key.contains('state') && key.contains('code');
  }

  String _itemLabel(InvoiceItem item) {
    final lines = <String>[item.name.trim()];
    if (item.description.trim().isNotEmpty) {
      lines.add(item.description.trim());
    }
    return lines.join('\n');
  }

  String _formatDateLong(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = value.day.toString().padLeft(2, '0');
    return '$day ${months[value.month - 1]} ${value.year}';
  }

  String _formatMoney(double value, String currencySymbol) {
    return '$currencySymbol ${value.toStringAsFixed(2)}';
  }

  String _formatMoneyPlain(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatSignedMoney(double value, String currencySymbol) {
    if (value > 0) return '+ ${_formatMoney(value, currencySymbol)}';
    if (value < 0) return '- ${_formatMoney(value.abs(), currencySymbol)}';
    return _formatMoney(0, currencySymbol);
  }

  String _formatNumber(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.000001) {
      return rounded.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _joinNonEmpty(List<String> parts) {
    return parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _fallback(dynamic primary, String secondary) {
    final first = _readString(primary);
    return first.isNotEmpty ? first : secondary.trim();
  }

  Map<String, String> _mapStringMap(dynamic source) {
    if (source is Map<String, String>) return source;
    if (source is Map<String, dynamic>) {
      return source.map(
        (key, value) => MapEntry(key, value?.toString().trim() ?? ''),
      );
    }
    if (source is Map) {
      return source.map(
        (key, value) =>
            MapEntry(key.toString(), value?.toString().trim() ?? ''),
      );
    }
    return const {};
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

  String _numberToWords(double amount) {
    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();
    final rupeeWords = _convertNumber(rupees);
    if (paise == 0) {
      return '$rupeeWords Rupees';
    }
    final paiseWords = _convertNumber(paise);
    return '$rupeeWords Rupees and $paiseWords Paise';
  }

  String _convertNumber(int number) {
    if (number == 0) return 'Zero';

    final parts = <String>[];
    final scales = [
      (10000000, 'Crore'),
      (100000, 'Lakh'),
      (1000, 'Thousand'),
      (100, 'Hundred'),
    ];

    var remainder = number;
    for (final scale in scales) {
      final divisor = scale.$1;
      final name = scale.$2;
      if (remainder >= divisor) {
        final count = remainder ~/ divisor;
        remainder %= divisor;
        if (divisor == 100) {
          parts.add('${_convertBelowHundred(count)} $name');
        } else {
          parts.add('${_convertNumber(count)} $name');
        }
      }
    }

    if (remainder > 0) {
      parts.add(_convertBelowHundred(remainder));
    }

    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _convertBelowHundred(int number) {
    const units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number < 20) return units[number];
    final ten = number ~/ 10;
    final unit = number % 10;
    return unit == 0 ? tens[ten] : '${tens[ten]} ${units[unit]}';
  }
}

class _PdfCompanyData {
  const _PdfCompanyData({
    required this.displayName,
    required this.logoBase64,
    required this.addressLines,
    required this.contactLines,
    required this.bankFields,
  });

  final String displayName;
  final String logoBase64;
  final List<String> addressLines;
  final List<String> contactLines;
  final List<InvoiceOutputField> bankFields;
}

class _PdfPartyData {
  const _PdfPartyData({required this.visibleFields});

  final List<InvoiceOutputField> visibleFields;
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
