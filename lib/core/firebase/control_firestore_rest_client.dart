import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../firebase_options.dart';
import '../errors/app_exception.dart';
import 'firebase_app_manager.dart';
import 'firestore_rest_codec.dart';

class ControlFirestoreRestClient {
  ControlFirestoreRestClient(this._firebaseAppManager, {http.Client? client})
    : _client = client ?? http.Client();

  final FirebaseAppManager _firebaseAppManager;
  final http.Client _client;

  String get _projectId => DefaultFirebaseOptions.currentPlatform.projectId;

  Uri _documentUri(String collection, String documentId) {
    return Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_projectId/databases/(default)/documents/$collection/$documentId',
    );
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
      throw AppException(FirestoreRestCodec.errorMessage(response));
    }
  }

  Future<Map<String, String>> _headers() async {
    await _firebaseAppManager.initializeControlApp();
    final token = await _firebaseAppManager.controlAuth.currentUser
        ?.getIdToken();
    if (token == null) {
      throw const AppException('You must be signed in to access setup data.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
}
