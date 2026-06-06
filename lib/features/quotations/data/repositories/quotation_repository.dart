import '../../../../core/firebase/customer_firestore_rest_client.dart';
import '../../domain/entities/quotation.dart';
import '../models/quotation_model.dart';

class QuotationRepository {
  QuotationRepository(this._firestore);

  final CustomerFirestoreRestClient _firestore;

  Future<List<Quotation>> fetchQuotations() async {
    final documents = await _firestore.listDocuments('quotations');
    final quotations = <Quotation>[
      for (final document in documents)
        if (QuotationModel.isDocumentActive(document.data))
          QuotationModel.fromMap(document.id, document.data),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return quotations;
  }

  Future<void> saveQuotation(Quotation quotation) {
    return _firestore.setDocument(
      'quotations',
      quotation.id,
      QuotationModel.fromEntity(quotation).toMap(),
    );
  }

  Future<void> archiveQuotation(Quotation quotation) {
    final archivedAt = DateTime.now();
    final map = QuotationModel.fromEntity(
      quotation,
    ).toArchiveMap(archivedAt: archivedAt);
    return _firestore.setDocument('quotations', quotation.id, map);
  }
}
