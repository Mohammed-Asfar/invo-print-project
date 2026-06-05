import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/products/data/models/purchase_entry_model.dart';
import 'package:invo_print/features/products/data/repositories/purchase_entry_repository.dart';
import 'package:invo_print/features/products/domain/entities/purchase_entry.dart';

import '../../../../helpers/fake_customer_firestore_rest_client.dart';

void main() {
  group('PurchaseEntryRepository', () {
    test(
      'fetches active purchase entries sorted by purchase date descending',
      () async {
        final older = _entry(
          id: 'pur_old',
          entryNumber: 'PUR-001',
          purchaseDate: DateTime(2026, 6, 1),
        );
        final newer = _entry(
          id: 'pur_new',
          entryNumber: 'PUR-002',
          purchaseDate: DateTime(2026, 6, 5),
        );
        final inactive = _entry(
          id: 'pur_inactive',
          entryNumber: 'PUR-003',
          purchaseDate: DateTime(2026, 6, 6),
          isActive: false,
        );
        final firestore = FakeCustomerFirestoreRestClient({
          'purchase_entries/${older.id}': PurchaseEntryModel.fromEntity(
            older,
          ).toMap(),
          'purchase_entries/${newer.id}': PurchaseEntryModel.fromEntity(
            newer,
          ).toMap(),
          'purchase_entries/${inactive.id}': PurchaseEntryModel.fromEntity(
            inactive,
          ).toMap(),
        });

        final entries = await PurchaseEntryRepository(
          firestore,
        ).fetchPurchaseEntries();

        expect(entries.map((entry) => entry.id), ['pur_new', 'pur_old']);
      },
    );

    test('saves purchase entries with generated ids', () async {
      final firestore = FakeCustomerFirestoreRestClient();
      final repository = PurchaseEntryRepository(firestore);

      await repository.savePurchaseEntry(
        _entry(
          id: '',
          entryNumber: 'PUR-202606-001',
          purchaseDate: DateTime(2026, 6, 5),
        ),
      );

      final saved = firestore.documents.entries.single;
      expect(saved.key, startsWith('purchase_entries/pur_'));
      expect(saved.value, containsPair('entryNumber', 'PUR-202606-001'));
      expect((saved.value['items'] as List), hasLength(1));
    });
  });
}

PurchaseEntry _entry({
  required String id,
  required String entryNumber,
  required DateTime purchaseDate,
  bool isActive = true,
}) {
  return PurchaseEntry(
    id: id,
    entryNumber: entryNumber,
    supplierId: 'sup_1',
    supplierName: 'Supply Hub',
    billReference: 'BILL-44',
    purchaseDate: purchaseDate,
    items: const [
      PurchaseEntryItem(
        productId: 'prod_1',
        productName: 'Thermal Printer',
        sku: 'PRN-1',
        unit: 'pcs',
        quantity: 2,
        unitCost: 2000,
        lineTotal: 4000,
      ),
    ],
    notes: '',
    totalAmount: 4000,
    isActive: isActive,
    createdAt: purchaseDate,
    updatedAt: purchaseDate,
  );
}
