import '../../../../core/firebase/customer_firestore_rest_client.dart';
import '../../domain/entities/supplier.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  SupplierRepository(this._firestore);

  final CustomerFirestoreRestClient _firestore;

  Future<List<Supplier>> fetchSuppliers({bool includeInactive = false}) async {
    final documents = await _firestore.listDocuments('suppliers');
    final suppliers =
        documents
            .map(
              (document) => SupplierModel.fromMap(document.id, document.data),
            )
            .where((supplier) => includeInactive || supplier.isActive)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return suppliers;
  }

  Future<void> saveSupplier(Supplier supplier) async {
    final now = DateTime.now();
    final id = supplier.id.isEmpty
        ? 'sup_${now.microsecondsSinceEpoch}'
        : supplier.id;
    final saved = supplier.copyWith(
      id: id,
      isActive: true,
      createdAt: supplier.id.isEmpty ? now : supplier.createdAt,
      updatedAt: now,
    );
    await _firestore.setDocument(
      'suppliers',
      id,
      SupplierModel.fromEntity(saved).toMap(),
    );
  }

  Future<void> archiveSupplier(Supplier supplier) {
    return _firestore.setDocument(
      'suppliers',
      supplier.id,
      SupplierModel.fromEntity(
        supplier.copyWith(isActive: false, updatedAt: DateTime.now()),
      ).toMap(),
    );
  }
}
