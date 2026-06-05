import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../reports/domain/services/supplier_payables_report.dart';
import '../entities/supplier.dart';
import 'supplier_ledger.dart';

class SupplierStatementPdfService {
  const SupplierStatementPdfService();

  Future<Uint8List> buildStatementPdf({
    required Supplier supplier,
    required SupplierLedger ledger,
    required SupplierPayablesRow? payableRow,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Supplier Statement',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            supplier.name,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          if (supplier.phone.trim().isNotEmpty)
            pw.Text('Phone: ${supplier.phone.trim()}'),
          if (supplier.email.trim().isNotEmpty)
            pw.Text('Email: ${supplier.email.trim()}'),
          if (supplier.gstin.trim().isNotEmpty)
            pw.Text('GSTIN: ${supplier.gstin.trim()}'),
          if (supplier.address.trim().isNotEmpty)
            pw.Text('Address: ${supplier.address.trim()}'),
          pw.SizedBox(height: 16),
          _summaryGrid(ledger, payableRow),
          pw.SizedBox(height: 16),
          pw.Text(
            'Open Bills',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _openBillsTable(ledger),
          pw.SizedBox(height: 16),
          pw.Text(
            'Ledger Timeline',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _timelineTable(ledger),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _summaryGrid(
    SupplierLedger ledger,
    SupplierPayablesRow? payableRow,
  ) {
    final aging = payableRow;
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _metric('Purchased', _money(ledger.totalPurchased)),
        _metric('Paid', _money(ledger.totalPaid)),
        _metric('Outstanding', _money(ledger.outstandingBalance)),
        _metric('Bills', ledger.purchaseEntries.length.toString()),
        if (aging != null) ...[
          _metric('0-30 Days', _money(aging.currentBucketAmount)),
          _metric('31-60 Days', _money(aging.days31To60BucketAmount)),
          _metric('61-90 Days', _money(aging.days61To90BucketAmount)),
          _metric('90+ Days', _money(aging.days90PlusBucketAmount)),
        ],
      ],
    );
  }

  pw.Widget _metric(String label, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _openBillsTable(SupplierLedger ledger) {
    final rows = ledger.purchaseEntries
        .where((entry) => entry.balanceDue > 0)
        .toList();
    if (rows.isEmpty) {
      return pw.Text('No open bills.');
    }
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headers: const [
        'Entry',
        'Date',
        'Bill Ref',
        'Status',
        'Total',
        'Paid',
        'Balance',
      ],
      data: [
        for (final entry in rows)
          [
            entry.entryNumber,
            _date(entry.purchaseDate),
            entry.billReference,
            entry.status.label,
            _money(entry.totalAmount),
            _money(entry.amountPaid),
            _money(entry.balanceDue),
          ],
      ],
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    );
  }

  pw.Widget _timelineTable(SupplierLedger ledger) {
    if (ledger.entries.isEmpty) {
      return pw.Text('No ledger entries.');
    }
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headers: const ['Date', 'Type', 'Reference', 'Description', 'Amount'],
      data: [
        for (final entry in ledger.entries)
          [
            _date(entry.date),
            entry.type.label,
            entry.reference,
            entry.description,
            _money(entry.amount.abs()),
          ],
      ],
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    );
  }
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _money(double value) => value.toStringAsFixed(2);
