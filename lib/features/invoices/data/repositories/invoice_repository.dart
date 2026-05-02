import '../../../../core/firebase/customer_firestore_rest_client.dart';
import '../../domain/entities/invoice.dart';
import '../models/invoice_model.dart';

class InvoiceRepository {
  InvoiceRepository(this._firestore);

  final CustomerFirestoreRestClient _firestore;

  Future<List<Invoice>> fetchInvoices() async {
    final documents = await _firestore.listDocuments('invoices');
    final invoices =
        documents
            .map((document) => InvoiceModel.fromMap(document.id, document.data))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return invoices;
  }

  Future<void> saveInvoice(Invoice invoice) {
    return _firestore.setDocument(
      'invoices',
      invoice.id,
      InvoiceModel.fromEntity(invoice).toMap(),
    );
  }
}
