import '../../../../core/firebase/customer_firestore_rest_client.dart';
import '../../domain/entities/product_inventory_entry.dart';
import '../models/product_inventory_entry_model.dart';

class ProductInventoryRepository {
  ProductInventoryRepository(this._firestore);

  final CustomerFirestoreRestClient _firestore;

  Future<List<ProductInventoryEntry>> fetchAllEntries() async {
    final documents = await _firestore.listDocuments(
      'product_inventory_entries',
    );
    final entries =
        documents
            .map(
              (document) => ProductInventoryEntryModel.fromMap(
                document.id,
                document.data,
              ),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<List<ProductInventoryEntry>> fetchEntries(String productId) async {
    final entries = await fetchAllEntries();
    return entries.where((entry) => entry.productId == productId).toList();
  }

  Future<void> saveEntry(ProductInventoryEntry entry) {
    final id = entry.id.isEmpty
        ? 'stock_${DateTime.now().microsecondsSinceEpoch}'
        : entry.id;
    return _firestore.setDocument(
      'product_inventory_entries',
      id,
      ProductInventoryEntryModel.fromEntity(entry.copyWith(id: id)).toMap(),
    );
  }

  Future<void> saveEntries(Iterable<ProductInventoryEntry> entries) async {
    for (final entry in entries) {
      await saveEntry(entry);
    }
  }

  Future<void> deleteEntry(String entryId) {
    return _firestore.deleteDocument('product_inventory_entries', entryId);
  }

  Future<void> deleteEntries(Iterable<String> entryIds) async {
    for (final entryId in entryIds) {
      await deleteEntry(entryId);
    }
  }
}
