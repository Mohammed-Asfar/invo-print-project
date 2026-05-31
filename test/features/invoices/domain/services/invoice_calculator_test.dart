import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/invoices/domain/services/invoice_calculator.dart';

void main() {
  late InvoiceCalculator calculator;

  setUp(() {
    calculator = InvoiceCalculator();
  });

  group('InvoiceCalculator', () {
    test('calculates CGST and SGST for taxable line items', () {
      final totals = calculator.calculate(
        items: [_item(rate: 1000, quantity: 2, gstRate: 18)],
        taxMode: TaxMode.cgstSgst,
      );

      expect(totals.subtotal, 2000);
      expect(totals.taxableAmount, 2000);
      expect(totals.cgstAmount, 180);
      expect(totals.sgstAmount, 180);
      expect(totals.igstAmount, 0);
      expect(totals.grandTotal, 2360);
      expect(totals.items.single.total, 2360);
    });

    test('calculates IGST instead of split tax for interstate invoices', () {
      final totals = calculator.calculate(
        items: [_item(rate: 2500, gstRate: 18)],
        taxMode: TaxMode.igst,
      );

      expect(totals.cgstAmount, 0);
      expect(totals.sgstAmount, 0);
      expect(totals.igstAmount, 450);
      expect(totals.grandTotal, 2950);
    });

    test('does not add GST when tax mode is none', () {
      final totals = calculator.calculate(
        items: [_item(rate: 999.99, gstRate: 18)],
        taxMode: TaxMode.none,
      );

      expect(totals.subtotal, 999.99);
      expect(totals.cgstAmount, 0);
      expect(totals.sgstAmount, 0);
      expect(totals.igstAmount, 0);
      expect(totals.grandTotal, 999.99);
    });

    test('applies percentage discount before tax', () {
      final totals = calculator.calculate(
        items: [_item(rate: 1000, gstRate: 18)],
        taxMode: TaxMode.cgstSgst,
        discountType: 'percentage',
        discountValue: 10,
      );

      expect(totals.discountTotal, 100);
      expect(totals.taxableAmount, 900);
      expect(totals.cgstAmount, 81);
      expect(totals.sgstAmount, 81);
      expect(totals.grandTotal, 1062);
    });

    test('clamps amount discount to subtotal', () {
      final totals = calculator.calculate(
        items: [_item(rate: 1000, gstRate: 18)],
        taxMode: TaxMode.cgstSgst,
        discountType: 'amount',
        discountValue: 2000,
      );

      expect(totals.discountTotal, 1000);
      expect(totals.taxableAmount, 0);
      expect(totals.grandTotal, 0);
    });

    test('adds only labelled extra charges', () {
      final totals = calculator.calculate(
        items: [_item(rate: 1000, gstRate: 18)],
        taxMode: TaxMode.none,
        extraCharges: const [
          InvoiceCharge(label: 'Packing', amount: 50),
          InvoiceCharge(label: '', amount: 999),
        ],
      );

      expect(totals.extraChargeTotal, 50);
      expect(totals.grandTotal, 1050);
    });

    test('rounds grand total only when round off is enabled', () {
      final withoutRoundOff = calculator.calculate(
        items: [_item(rate: 999.99, quantity: 1, gstRate: 18)],
        taxMode: TaxMode.cgstSgst,
      );
      final withRoundOff = calculator.calculate(
        items: [_item(rate: 999.99, quantity: 1, gstRate: 18)],
        taxMode: TaxMode.cgstSgst,
        roundOffEnabled: true,
      );

      expect(withoutRoundOff.grandTotal, 1179.99);
      expect(withRoundOff.grandTotal, 1180);
      expect(withRoundOff.roundOffAmount, 0.01);
    });

    test(
      'converts between tax-exclusive and tax-inclusive rates accurately',
      () {
        expect(
          calculator.rateIncludingTax(rate: 2500, taxRate: 18),
          closeTo(2950, 0.0001),
        );
        expect(
          calculator.rateBeforeTax(rateIncludingTax: 118, taxRate: 18),
          closeTo(100, 0.0001),
        );
        expect(calculator.formatRateInput(84.7457627119), '84.745763');
      },
    );
  });
}

InvoiceItem _item({
  double quantity = 1,
  required double rate,
  double gstRate = 18,
}) {
  return InvoiceItem.empty().copyWith(
    name: 'Service',
    quantity: quantity,
    rate: rate,
    gstRate: gstRate,
  );
}
