import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/invoices/domain/services/hsn_gst_lookup.dart';

void main() {
  group('HsnGstLookup', () {
    test('uses exact HSN match when available', () {
      final lookup = HsnGstLookup.fromJsonMap({
        '0202': {'igst_rate': 5},
        '020210': {'igst_rate': 12},
      });

      expect(lookup.findRate('020210'), 12);
    });

    test('falls back to nearest numeric prefix', () {
      final lookup = HsnGstLookup.fromJsonMap({
        '0202': {'igst_rate': '5'},
      });

      expect(lookup.findRate('HSN 02029999'), 5);
    });

    test('ignores invalid entries and empty codes', () {
      final lookup = HsnGstLookup.fromJsonMap({
        'abcd': {'igst_rate': 18},
        '9999': {'igst_rate': 'bad'},
      });

      expect(lookup.findRate('abcd'), isNull);
      expect(lookup.findRate('9999'), isNull);
    });
  });
}
