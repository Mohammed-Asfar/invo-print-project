import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/supplier_model.dart';
import 'package:invo_print/features/products/domain/entities/supplier.dart';

void main() {
  group('SupplierModel', () {
    test('round-trips optional supplier fields', () {
      final now = DateTime(2026, 6, 5, 9, 30);
      final model = SupplierModel(
        id: 'sup_1',
        name: 'Supply Hub',
        phone: '9876543210',
        email: 'hello@supplyhub.test',
        gstin: '33ABCDE1234F1Z5',
        address: 'No. 12 Market Road',
        notes: 'Preferred vendor',
        followUpStatus: SupplierFollowUpStatus.pending,
        lastContactedAt: now.subtract(const Duration(days: 2)),
        nextFollowUpDate: now.add(const Duration(days: 1)),
        followUpNotes: 'Call about overdue amount',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = model.toMap();
      final restored = SupplierModel.fromMap('sup_1', map);

      expect(restored, model);
      expect(map['name'], 'Supply Hub');
      expect(map['followUpStatus'], 'pending');
    });

    test('omits empty optional fields from map', () {
      final model = SupplierModel.fromEntity(
        Supplier.empty().copyWith(name: 'Bare Supplier'),
      );

      final map = model.toMap();

      expect(map, containsPair('name', 'Bare Supplier'));
      expect(map.containsKey('phone'), isFalse);
      expect(map.containsKey('email'), isFalse);
      expect(map.containsKey('gstin'), isFalse);
      expect(map.containsKey('address'), isFalse);
      expect(map.containsKey('notes'), isFalse);
      expect(map.containsKey('followUpStatus'), isFalse);
      expect(map.containsKey('lastContactedAt'), isFalse);
      expect(map.containsKey('nextFollowUpDate'), isFalse);
      expect(map.containsKey('followUpNotes'), isFalse);
    });
  });
}
