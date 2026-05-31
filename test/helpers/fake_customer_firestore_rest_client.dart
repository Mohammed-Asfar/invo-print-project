import 'package:invo_print/core/firebase/customer_firestore_rest_client.dart';
import 'package:invo_print/core/firebase/firebase_app_manager.dart';

class FakeCustomerFirestoreRestClient extends CustomerFirestoreRestClient {
  FakeCustomerFirestoreRestClient([Map<String, Map<String, dynamic>>? seed])
    : documents = {
        for (final entry in (seed ?? {}).entries) entry.key: {...entry.value},
      },
      super(FirebaseAppManager());

  final Map<String, Map<String, dynamic>> documents;

  @override
  Future<List<FirestoreRestDocument>> listDocuments(String collection) async {
    final prefix = '$collection/';
    return documents.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map(
          (entry) => FirestoreRestDocument(
            id: entry.key.substring(prefix.length),
            data: {...entry.value},
          ),
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String documentId,
  ) async {
    final data = documents['$collection/$documentId'];
    return data == null ? null : {...data};
  }

  @override
  Future<void> setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    documents['$collection/$documentId'] = {...data};
  }

  @override
  Future<void> deleteDocument(String collection, String documentId) async {
    documents.remove('$collection/$documentId');
  }
}
