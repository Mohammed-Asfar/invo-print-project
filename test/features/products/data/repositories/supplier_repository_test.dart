import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/supplier_model.dart';
import 'package:invo_print/features/products/data/repositories/supplier_repository.dart';
import 'package:invo_print/features/products/domain/entities/supplier.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('SupplierRepository', () {
    test('fetches active suppliers sorted by name', () async {
      final alpha = _supplier(id: 'sup_a', name: 'Alpha Traders');
      final zeta = _supplier(id: 'sup_z', name: 'Zeta Supplies');
      final inactive = _supplier(
        id: 'sup_i',
        name: 'Inactive Supply',
        isActive: false,
      );
      final firestore = FakeCustomerFirestoreRestClient({
        'suppliers/sup_z': SupplierModel.fromEntity(zeta).toMap(),
        'suppliers/sup_a': SupplierModel.fromEntity(alpha).toMap(),
        'suppliers/sup_i': SupplierModel.fromEntity(inactive).toMap(),
      });

      final suppliers = await SupplierRepository(firestore).fetchSuppliers();

      expect(suppliers.map((supplier) => supplier.id), ['sup_a', 'sup_z']);
    });

    test('saves and archives supplier', () async {
      final firestore = FakeCustomerFirestoreRestClient();
      final repository = SupplierRepository(firestore);

      await repository.saveSupplier(_supplier(id: '', name: 'Supply Hub'));

      final savedEntry = firestore.documents.entries.single;
      expect(savedEntry.key, startsWith('suppliers/sup_'));
      expect(savedEntry.value, containsPair('name', 'Supply Hub'));

      final savedId = savedEntry.key.split('/').last;
      final savedSupplier = SupplierModel.fromMap(savedId, savedEntry.value);
      await repository.archiveSupplier(savedSupplier);

      expect(
        firestore.documents['suppliers/$savedId'],
        containsPair('isActive', false),
      );
    });
  });
}

Supplier _supplier({
  required String id,
  required String name,
  bool isActive = true,
}) {
  final now = DateTime(2026, 6, 5);
  return Supplier(
    id: id,
    name: name,
    phone: '',
    email: '',
    gstin: '',
    address: '',
    notes: '',
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}
