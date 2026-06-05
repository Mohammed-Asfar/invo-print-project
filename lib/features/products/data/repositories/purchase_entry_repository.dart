import '../../../../core/firebase/customer_firestore_rest_client.dart';
import '../../domain/entities/purchase_entry.dart';
import '../models/purchase_entry_model.dart';

class PurchaseEntryRepository {
  PurchaseEntryRepository(this._firestore);

  final CustomerFirestoreRestClient _firestore;

  Future<List<PurchaseEntry>> fetchPurchaseEntries({
    bool includeInactive = false,
  }) async {
    final documents = await _firestore.listDocuments('purchase_entries');
    final entries =
        documents
            .map(
              (document) =>
                  PurchaseEntryModel.fromMap(document.id, document.data),
            )
            .where((entry) => includeInactive || entry.isActive)
            .toList()
          ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    return entries;
  }

  Future<void> savePurchaseEntry(PurchaseEntry entry) async {
    final now = DateTime.now();
    final id = entry.id.isEmpty
        ? 'pur_${now.microsecondsSinceEpoch}'
        : entry.id;
    final saved = entry.copyWith(
      id: id,
      isActive: true,
      createdAt: entry.id.isEmpty ? now : entry.createdAt,
      updatedAt: now,
    );
    await _firestore.setDocument(
      'purchase_entries',
      id,
      PurchaseEntryModel.fromEntity(saved).toMap(),
    );
  }

  Future<void> archivePurchaseEntry(PurchaseEntry entry) {
    return _firestore.setDocument(
      'purchase_entries',
      entry.id,
      PurchaseEntryModel.fromEntity(
        entry.copyWith(isActive: false, updatedAt: DateTime.now()),
      ).toMap(),
    );
  }
}
