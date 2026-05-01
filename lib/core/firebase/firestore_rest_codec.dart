import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';

class FirestoreRestCodec {
  const FirestoreRestCodec._();

  static Map<String, dynamic> encodeFields(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, encodeValue(value)));
  }

  static Map<String, dynamic> encodeValue(dynamic value) {
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is Map<String, dynamic>) {
      return {
        'mapValue': {'fields': encodeFields(value)},
      };
    }
    if (value is List) {
      return {
        'arrayValue': {'values': value.map(encodeValue).toList()},
      };
    }
    if (value == null) return {'nullValue': null};
    throw AppException('Unsupported Firestore field value: $value');
  }

  static Map<String, dynamic> decodeFields(Map<String, dynamic> fields) {
    return fields.map((key, value) {
      return MapEntry(key, decodeValue(value as Map<String, dynamic>));
    });
  }

  static dynamic decodeValue(Map<String, dynamic> value) {
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue'].toString()) ?? 0;
    }
    if (value.containsKey('doubleValue')) return value['doubleValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('mapValue')) {
      final fields =
          (value['mapValue'] as Map<String, dynamic>)['fields']
              as Map<String, dynamic>? ??
          {};
      return decodeFields(fields);
    }
    if (value.containsKey('arrayValue')) {
      final values =
          (value['arrayValue'] as Map<String, dynamic>)['values']
              as List<dynamic>? ??
          [];
      return values
          .map((item) => decodeValue(item as Map<String, dynamic>))
          .toList();
    }
    return null;
  }

  static String errorMessage(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String?;
      final status = error?['status'] as String?;
      if (message != null) {
        return status == null ? message : '$message ($status)';
      }
    } catch (_) {
      return 'Firestore request failed: ${response.statusCode}.';
    }

    return 'Firestore request failed: ${response.statusCode}.';
  }
}
