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
    return FirestoreRestCodec.decodeFields(
      json['fields'] as Map<String, dynamic>? ?? {},
    );
  }

  Future<void> setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.patch(
      _documentUri(collection, documentId),
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
