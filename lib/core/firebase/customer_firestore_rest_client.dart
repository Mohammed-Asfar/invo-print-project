import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';
import 'firebase_app_manager.dart';
import 'firestore_rest_codec.dart';

class CustomerFirestoreRestClient {
  CustomerFirestoreRestClient(this._firebaseAppManager, {http.Client? client})
    : _client = client ?? http.Client();

  final FirebaseAppManager _firebaseAppManager;
  final http.Client _client;

  Uri _documentUri(String collection, String documentId) {
    final projectId = _firebaseAppManager.customerProjectId;
    return Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/$collection/$documentId',
    );
  }

  Uri _collectionUri(String collection) {
    final projectId = _firebaseAppManager.customerProjectId;
    return Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/$collection',
    );
  }

  Future<List<FirestoreRestDocument>> listDocuments(String collection) async {
    final response = await _client.get(
      _collectionUri(collection),
      headers: await _headers(),
    );

    if (response.statusCode == 404) return [];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 403) {
        throw const AppException(
          'Customer Firestore rules are blocking access. Deploy customer_firestore.rules to the customer Firebase project.',
        );
      }
      throw AppException(FirestoreRestCodec.errorMessage(response));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = json['documents'] as List<dynamic>? ?? [];
    return documents.map((document) {
      final map = document as Map<String, dynamic>;
      final name = map['name'] as String? ?? '';
      final id = name.split('/').last;
      final fields = FirestoreRestCodec.decodeFields(
        map['fields'] as Map<String, dynamic>? ?? {},
      );
      return FirestoreRestDocument(id: id, data: fields);
    }).toList();
  }

  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String documentId,
  ) async {
    final snapshot = await getDocumentSnapshot(collection, documentId);
    return snapshot?.data;
  }

  Future<FirestoreRestDocumentSnapshot?> getDocumentSnapshot(
    String collection,
    String documentId,
  ) async {
    final response = await _client.get(
      _documentUri(collection, documentId),
      headers: await _headers(),
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 403) {
        throw const AppException(
          'Customer Firestore rules are blocking access. Deploy customer_firestore.rules to the customer Firebase project.',
        );
      }
      throw AppException(FirestoreRestCodec.errorMessage(response));
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FirestoreRestDocumentSnapshot(
      data: FirestoreRestCodec.decodeFields(
        json['fields'] as Map<String, dynamic>? ?? {},
      ),
      updateTime: json['updateTime'] as String?,
    );
  }

  Future<void> setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data, {
    FirestoreWritePrecondition? precondition,
  }) async {
    final response = await _client.patch(
      _documentUri(
        collection,
        documentId,
      ).replace(queryParameters: precondition?.toQueryParameters()),
      headers: await _headers(),
      body: jsonEncode({'fields': FirestoreRestCodec.encodeFields(data)}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 403) {
        throw const AppException(
          'Customer Firestore rules are blocking access. Deploy customer_firestore.rules to the customer Firebase project.',
        );
      }
      throw AppException(FirestoreRestCodec.errorMessage(response));
    }
  }

  Future<void> deleteDocument(String collection, String documentId) async {
    final response = await _client.delete(
      _documentUri(collection, documentId),
      headers: await _headers(),
    );

    if (response.statusCode == 404) return;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 403) {
        throw const AppException(
          'Customer Firestore rules are blocking access. Deploy customer_firestore.rules to the customer Firebase project.',
        );
      }
      throw AppException(FirestoreRestCodec.errorMessage(response));
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await _firebaseAppManager.customerAuth.currentUser
        ?.getIdToken();
    if (token == null) {
      throw const AppException('Customer Firebase session is not active.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
}

class FirestoreRestDocument {
  const FirestoreRestDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

class FirestoreRestDocumentSnapshot {
  const FirestoreRestDocumentSnapshot({
    required this.data,
    required this.updateTime,
  });

  final Map<String, dynamic> data;
  final String? updateTime;
}

class FirestoreWritePrecondition {
  const FirestoreWritePrecondition({this.exists, this.updateTime});

  const FirestoreWritePrecondition.mustExist() : this(exists: true);

  const FirestoreWritePrecondition.mustNotExist() : this(exists: false);

  final bool? exists;
  final String? updateTime;

  Map<String, String>? toQueryParameters() {
    final values = <String, String>{};
    if (exists != null) {
      values['currentDocument.exists'] = exists.toString();
    }
    if (updateTime != null && updateTime!.trim().isNotEmpty) {
      values['currentDocument.updateTime'] = updateTime!.trim();
    }
    return values.isEmpty ? null : values;
  }
}
