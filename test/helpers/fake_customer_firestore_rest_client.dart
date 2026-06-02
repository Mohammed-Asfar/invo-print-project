import 'package:invo_print/core/firebase/customer_firestore_rest_client.dart';
import 'package:invo_print/core/firebase/firebase_app_manager.dart';
import 'package:invo_print/core/errors/app_exception.dart';

class FakeCustomerFirestoreRestClient extends CustomerFirestoreRestClient {
  FakeCustomerFirestoreRestClient([Map<String, Map<String, dynamic>>? seed])
    : documents = {
        for (final entry in (seed ?? {}).entries) entry.key: {...entry.value},
      },
      _versions = {
        for (final entry in (seed ?? {}).entries)
          entry.key: 'version-${_seedIndex++}',
      },
      super(FirebaseAppManager());

  final Map<String, Map<String, dynamic>> documents;
  final Map<String, String> _versions;
  static int _seedIndex = 1;
  static int _writeIndex = 1000;

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
    final snapshot = await getDocumentSnapshot(collection, documentId);
    return snapshot?.data;
  }

  @override
  Future<FirestoreRestDocumentSnapshot?> getDocumentSnapshot(
    String collection,
    String documentId,
  ) async {
    final path = '$collection/$documentId';
    final data = documents[path];
    if (data == null) return null;
    return FirestoreRestDocumentSnapshot(
      data: {...data},
      updateTime: _versions[path],
    );
  }

  @override
  Future<void> setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data, {
    FirestoreWritePrecondition? precondition,
  }) async {
    final path = '$collection/$documentId';
    final exists = documents.containsKey(path);
    if (precondition?.exists == true && !exists) {
      throw const AppException('Missing document. (FAILED_PRECONDITION)');
    }
    if (precondition?.exists == false && exists) {
      throw const AppException(
        'Document already exists. (FAILED_PRECONDITION)',
      );
    }
    if (precondition?.updateTime != null &&
        _versions[path] != precondition!.updateTime) {
      throw const AppException(
        'Document update conflict. (FAILED_PRECONDITION)',
      );
    }
    documents[path] = {...data};
    _versions[path] = 'version-${_writeIndex++}';
  }

  @override
  Future<void> deleteDocument(String collection, String documentId) async {
    final path = '$collection/$documentId';
    documents.remove(path);
    _versions.remove(path);
  }
}
