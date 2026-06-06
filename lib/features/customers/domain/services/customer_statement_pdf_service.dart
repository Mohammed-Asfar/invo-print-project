import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../entities/customer.dart';
import '../../../invoices/domain/entities/invoice.dart';
import 'customer_ledger.dart';

class CustomerStatementPdfService {
  const CustomerStatementPdfService();

  Future<Uint8List> buildStatementPdf({
    required Customer customer,
    required CustomerLedger ledger,
    DateTime? asOfDate,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdf = pw.Document();
    final effectiveAsOfDate = _dateOnly(toDate ?? asOfDate ?? DateTime.now());
    final effectiveFromDate = fromDate == null ? null : _dateOnly(fromDate);
    final effectiveToDate = toDate == null ? null : _dateOnly(toDate);
    final filteredEntries = ledger.entries.where((entry) {
      final entryDate = _dateOnly(entry.date);
      if (effectiveFromDate != null && entryDate.isBefore(effectiveFromDate)) {
        return false;
      }
      if (effectiveToDate != null && entryDate.isAfter(effectiveToDate)) {
        return false;
      }
      return true;
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Customer Statement',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('As of ${_date(effectiveAsOfDate)}'),
          if (effectiveFromDate != null || effectiveToDate != null)
            pw.Text(
              'Activity period: ${effectiveFromDate == null ? 'Beginning' : _date(effectiveFromDate)} to ${effectiveToDate == null ? 'Latest' : _date(effectiveToDate)}',
            ),
          pw.SizedBox(height: 8),
          pw.Text(
            customer.name,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          if (customer.phone.trim().isNotEmpty)
            pw.Text('Phone: ${customer.phone.trim()}'),
          if (customer.email.trim().isNotEmpty)
            pw.Text('Email: ${customer.email.trim()}'),
          if (customer.gstin.trim().isNotEmpty)
            pw.Text('GSTIN: ${customer.gstin.trim()}'),
          if (customer.billingAddress.trim().isNotEmpty)
            pw.Text('Billing Address: ${customer.billingAddress.trim()}'),
          pw.SizedBox(height: 16),
          _summaryGrid(ledger),
          pw.SizedBox(height: 16),
          pw.Text(
            'Open Invoices',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _openInvoicesTable(ledger, effectiveAsOfDate),
          pw.SizedBox(height: 16),
          pw.Text(
            'Ledger Timeline',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _timelineTable(filteredEntries),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _summaryGrid(CustomerLedger ledger) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _metric('Invoiced', _money(ledger.totalInvoiced)),
        _metric('Paid', _money(ledger.totalPaid)),
        _metric('Credits', _money(ledger.totalCredited)),
        _metric('Outstanding', _money(ledger.outstandingBalance)),
        _metric('Customer Credit', _money(ledger.creditBalance)),
        _metric('Loyalty Points', ledger.loyaltyPoints.toString()),
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

  pw.Widget _openInvoicesTable(CustomerLedger ledger, DateTime asOfDate) {
    final rows = ledger.invoices
        .where((invoice) => invoice.balanceDue > 0)
        .toList();
    if (rows.isEmpty) {
      return pw.Text('No open invoices.');
    }
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headers: const [
        'Invoice',
        'Date',
        'Due Date',
        'Status',
        'Total',
        'Paid',
        'Credits',
        'Balance',
        'Overdue',
      ],
      data: [
        for (final invoice in rows)
          [
            invoice.invoiceNumber,
            _date(invoice.invoiceDate),
            _date(invoice.dueDate),
            invoice.status.label,
            _money(invoice.grandTotal),
            _money(invoice.amountPaid),
            _money(invoice.creditTotal),
            _money(invoice.balanceDue),
            _isInvoiceOverdue(invoice, asOfDate)
                ? '${_dateOnly(asOfDate).difference(_dateOnly(invoice.dueDate)).inDays}d'
                : '-',
          ],
      ],
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    );
  }

  pw.Widget _timelineTable(List<CustomerLedgerEntry> entries) {
    if (entries.isEmpty) {
      return pw.Text('No ledger entries.');
    }
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headers: const ['Date', 'Type', 'Reference', 'Description', 'Amount'],
      data: [
        for (final entry in entries)
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

bool _isInvoiceOverdue(Invoice invoice, DateTime today) {
  if (invoice.balanceDue <= 0) return false;
  if (invoice.status == InvoiceStatus.paid ||
      invoice.status == InvoiceStatus.cancelled) {
    return false;
  }
  return _dateOnly(invoice.dueDate).isBefore(today);
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _money(double value) => value.toStringAsFixed(2);

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
