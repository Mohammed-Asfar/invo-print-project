import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/invoices/data/models/invoice_model.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';

void main() {
  group('InvoiceModel', () {
    test(
      'skips empty optional adjustment and payment fields in Firestore map',
      () {
        final map = InvoiceModel.fromEntity(_invoice()).toMap();

        expect(map.containsKey('discountType'), isFalse);
        expect(map.containsKey('discountValue'), isFalse);
        expect(map.containsKey('discountTotal'), isFalse);
        expect(map.containsKey('extraCharges'), isFalse);
        expect(map.containsKey('extraChargeTotal'), isFalse);
        expect(map.containsKey('amountPaid'), isFalse);
        expect(map.containsKey('paidAt'), isFalse);
        expect(map.containsKey('paymentHistory'), isFalse);
        expect(map['balanceDue'], 1180);
      },
    );

    test('stores optional adjustment and payment fields only when used', () {
      final paidAt = DateTime(2026, 5, 23);
      final map = InvoiceModel.fromEntity(
        _invoice(
          discountType: 'percentage',
          discountValue: 10,
          discountTotal: 100,
          extraCharges: const [InvoiceCharge(label: 'Packing', amount: 50)],
          extraChargeTotal: 50,
          amountPaid: 500,
          balanceDue: 612,
          paidAt: paidAt,
          paymentHistory: [
            InvoicePaymentRecord(
              amount: 500,
              paidAt: paidAt,
              method: 'UPI',
              reference: 'UTR-1',
            ),
          ],
        ),
      ).toMap();

      expect(map['discountType'], 'percentage');
      expect(map['discountValue'], 10);
      expect(map['discountTotal'], 100);
      expect(map['extraCharges'], [
        {'label': 'Packing', 'amount': 50.0},
      ]);
      expect(map['extraChargeTotal'], 50);
      expect(map['amountPaid'], 500);
      expect(map['paidAt'], paidAt);
      expect(map['paymentHistory'], hasLength(1));
    });

    test('round trips older sparse invoice maps with defaults', () {
      final model = InvoiceModel.fromMap('inv_1', {
        'invoiceNumber': 'INV-001',
        'invoiceSequence': 1,
        'financialYear': '2026-27',
        'invoiceDate': DateTime(2026, 5, 2),
        'dueDate': DateTime(2026, 5, 17),
        'customerId': 'cust_1',
        'items': const <Map<String, dynamic>>[],
        'taxMode': 'cgst_sgst',
        'status': 'unpaid',
        'subtotal': 1000,
        'taxableAmount': 1000,
        'cgstAmount': 90,
        'sgstAmount': 90,
        'igstAmount': 0,
        'roundOffEnabled': false,
        'grandTotal': 1180,
        'balanceDue': 1180,
        'createdAt': DateTime(2026, 5, 2),
        'updatedAt': DateTime(2026, 5, 2),
      });

      expect(model.discountType, 'none');
      expect(model.discountValue, 0);
      expect(model.extraCharges, isEmpty);
      expect(model.amountPaid, 0);
      expect(model.paymentHistory, isEmpty);
      expect(model.balanceDue, 1180);
    });
  });
}

Invoice _invoice({
  String discountType = 'none',
  double discountValue = 0,
  double discountTotal = 0,
  List<InvoiceCharge> extraCharges = const [],
  double extraChargeTotal = 0,
  double amountPaid = 0,
  double balanceDue = 1180,
  DateTime? paidAt,
  List<InvoicePaymentRecord> paymentHistory = const [],
}) {
  final now = DateTime(2026, 5, 2);
  return Invoice(
    id: 'inv_1',
    invoiceNumber: 'INV-001',
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: now,
    dueDate: DateTime(2026, 5, 17),
    customerId: 'cust_1',
    customerSnapshot: const {'name': 'TBS Enterprises'},
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: [
      InvoiceItem.empty().copyWith(
        name: 'Service',
        quantity: 1,
        rate: 1000,
        gstRate: 18,
        taxableAmount: 1000,
        cgstAmount: 90,
        sgstAmount: 90,
        total: 1180,
      ),
    ],
    taxMode: TaxMode.cgstSgst,
    status: amountPaid > 0 ? InvoiceStatus.partialPaid : InvoiceStatus.unpaid,
    subtotal: 1000,
    discountType: discountType,
    discountValue: discountValue,
    discountTotal: discountTotal,
    extraCharges: extraCharges,
    extraChargeTotal: extraChargeTotal,
    taxableAmount: 1000 - discountTotal,
    cgstAmount: 90,
    sgstAmount: 90,
    igstAmount: 0,
    roundOffEnabled: false,
    roundOffAmount: 0,
    grandTotal: 1180,
    amountPaid: amountPaid,
    balanceDue: balanceDue,
    paidAt: paidAt,
    notes: '',
    terms: '',
    paymentHistory: paymentHistory,
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: now,
    updatedAt: now,
  );
}
