import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/domain/entities/purchase_entry.dart';
import 'package:invo_print/features/products/domain/entities/supplier.dart';
import 'package:invo_print/features/products/domain/services/supplier_ledger.dart';
import 'package:invo_print/features/products/domain/services/supplier_statement_pdf_service.dart';
import 'package:invo_print/features/reports/domain/services/supplier_payables_report.dart';

void main() {
  test('SupplierStatementPdfService builds readable statement pdf', () async {
    final supplier = Supplier(
      id: 'sup_1',
      name: 'Supply Hub',
      phone: '9876543210',
      email: 'hello@supplyhub.test',
      gstin: '33ABCDE1234F1Z5',
      address: 'No. 12 Market Road',
      notes: '',
      isActive: true,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
    final entry = PurchaseEntry(
      id: 'pur_1',
      entryNumber: 'PUR-001',
      supplierId: supplier.id,
      supplierName: supplier.name,
      billReference: 'BILL-44',
      purchaseDate: DateTime(2026, 6, 5),
      dueDate: DateTime(2026, 6, 20),
      items: const [],
      notes: '',
      totalAmount: 6000,
      amountPaid: 1000,
      paymentHistory: [
        PurchasePayment(
          amount: 1000,
          paidAt: DateTime(2026, 6, 6),
          method: 'Bank',
          reference: 'PAY-1',
        ),
      ],
      status: PurchasePaymentStatus.partial,
      isActive: true,
      createdAt: DateTime(2026, 6, 5),
      updatedAt: DateTime(2026, 6, 5),
    );
    final ledger = buildSupplierLedger(
      supplier: supplier,
      purchaseEntries: [entry],
    );
    final payablesRow = buildSupplierPayablesReport(
      suppliers: [supplier],
      purchaseEntries: [entry],
      asOfDate: DateTime(2026, 6, 30),
    ).rows.single;

    final bytes = await const SupplierStatementPdfService().buildStatementPdf(
      supplier: supplier,
      ledger: ledger,
      payableRow: payablesRow,
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final decoded = _decodedPdfText(bytes);
    expect(decoded, contains('Supplier'));
    expect(decoded, contains('Statement'));
    expect(decoded, contains('Supply'));
    expect(decoded, contains('Hub'));
    expect(decoded, contains('PUR-001'));
    expect(decoded, contains('Due'));
  });
}

String _decodedPdfText(Uint8List bytes) {
  final rawPdf = latin1.decode(bytes, allowInvalid: true);
  final decodedStreams = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream')
      .allMatches(rawPdf)
      .map((match) {
        final stream = latin1.encode(match.group(1)!);
        try {
          return latin1.decode(zlib.decode(stream), allowInvalid: true);
        } on FormatException {
          return latin1.decode(stream, allowInvalid: true);
        }
      });

  return [rawPdf, ...decodedStreams].join('\n');
}
