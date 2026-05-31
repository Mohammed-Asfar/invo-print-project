import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/app_exception.dart';

class GstinLookupService {
  GstinLookupService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GstinValidationResult> validate({
    required String gstin,
    required String apiKey,
    required String host,
    required String endpointPath,
  }) async {
    final normalizedGstin = gstin.trim().toUpperCase();
    if (normalizedGstin.isEmpty) {
      throw const AppException('Enter a GSTIN to validate.');
    }
    final payload = await _requestPayload(
      gstin: normalizedGstin,
      apiKey: apiKey,
      host: host,
      endpointPath: endpointPath,
    );

    final flattened = <String, List<dynamic>>{};
    GstinBusinessDetails._flatten(payload, flattened);
    final returnedGstin = GstinBusinessDetails._firstText(flattened, const [
      'gstin',
      'gstNumber',
      'gst_number',
      'gstno',
    ], fallback: normalizedGstin);

    bool? isValid;
    for (final key in const ['is_valid', 'isValid', 'valid', 'is_active']) {
      final normalizedKey = GstinBusinessDetails._normalizeKey(key);
      final values = flattened[normalizedKey];
      if (values == null) continue;
      for (final value in values) {
        if (value is bool) {
          isValid = value;
          break;
        }
        final text = value?.toString().trim().toLowerCase() ?? '';
        if (text == 'true') {
          isValid = true;
          break;
        }
        if (text == 'false') {
          isValid = false;
          break;
        }
      }
      if (isValid != null) break;
    }

    if (isValid == null) {
      final status = GstinBusinessDetails._firstText(flattened, const [
        'status',
        'gstStatus',
      ]).toLowerCase();
      if (status == 'active' || status == 'valid') {
        isValid = true;
      } else if (status == 'inactive' || status == 'invalid') {
        isValid = false;
      }
    }

    return GstinValidationResult(
      gstin: returnedGstin,
      isValid: isValid ?? false,
    );
  }

  Future<GstinBusinessDetails> lookup({
    required String gstin,
    required String apiKey,
    required String host,
    required String endpointPath,
  }) async {
    final normalizedGstin = gstin.trim().toUpperCase();
    if (normalizedGstin.isEmpty) {
      throw const AppException('Enter a GSTIN to fetch customer details.');
    }
    final payload = await _requestPayload(
      gstin: normalizedGstin,
      apiKey: apiKey,
      host: host,
      endpointPath: endpointPath,
    );
    final details = GstinBusinessDetails.fromPayload(
      payload,
      fallbackGstin: normalizedGstin,
    );

    if (details.displayName.isEmpty &&
        details.formattedAddress.isEmpty &&
        details.stateName.isEmpty) {
      throw const AppException(
        'The GSTIN API did not return usable customer details.',
      );
    }
    return details;
  }

  Future<Map<String, dynamic>> _requestPayload({
    required String gstin,
    required String apiKey,
    required String host,
    required String endpointPath,
    int retriesRemaining = 1,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AppException('RapidAPI key is missing in Company Settings.');
    }
    final normalizedHost = _normalizeHost(host);
    if (normalizedHost.isEmpty) {
      throw const AppException('RapidAPI host is missing in Company Settings.');
    }
    if (endpointPath.trim().isEmpty) {
      throw const AppException(
        'GSTIN API path is missing in Company Settings.',
      );
    }

    final uri = _buildUri(
      host: normalizedHost,
      endpointPath: endpointPath,
      gstin: gstin,
    );

    http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-RapidAPI-Key': apiKey.trim(),
          'X-RapidAPI-Host': normalizedHost,
          'Accept': 'application/json',
        },
      );
    } catch (error) {
      throw AppException('Unable to reach GSTIN lookup API: $error');
    }

    if (response.statusCode == 429 && retriesRemaining > 0) {
      await Future<void>.delayed(const Duration(seconds: 2));
      return _requestPayload(
        gstin: gstin,
        apiKey: apiKey,
        host: host,
        endpointPath: endpointPath,
        retriesRemaining: retriesRemaining - 1,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
        _friendlyErrorMessage(
          statusCode: response.statusCode,
          body: response.body,
          gstin: gstin,
        ),
      );
    }

    final decoded = _decodeBody(response.body);
    return _unwrapPayload(decoded);
  }

  String _friendlyErrorMessage({
    required int statusCode,
    required String body,
    required String gstin,
  }) {
    final payload = _tryDecodeErrorBody(body);
    final apiMessage = _readString(payload, const [
      'error',
      'message',
      'detail',
    ]).trim();

    if (statusCode == 422) {
      if (apiMessage.isNotEmpty) {
        return apiMessage;
      }
      return 'GSTIN format is invalid. Check the number and try again.';
    }
    if (statusCode == 404) {
      return 'No GST record was found for $gstin.';
    }
    if (statusCode == 429) {
      return 'GST lookup limit reached. Please wait and try again later.';
    }
    if (apiMessage.isNotEmpty) {
      return apiMessage;
    }
    return 'GSTIN lookup failed with status $statusCode.';
  }

  Map<String, dynamic> _tryDecodeErrorBody(String body) {
    try {
      final decoded = jsonDecode(body);
      return _toStringKeyMap(decoded);
    } catch (_) {
      return const {};
    }
  }

  Uri _buildUri({
    required String host,
    required String endpointPath,
    required String gstin,
  }) {
    final resolvedPath = endpointPath.trim().replaceAll('{gstin}', gstin);
    if (resolvedPath.startsWith('http://') ||
        resolvedPath.startsWith('https://')) {
      final uri = Uri.parse(resolvedPath);
      return _ensureGstinQuery(uri, gstin, endpointPath);
    }

    final normalizedPath = resolvedPath.startsWith('/')
        ? resolvedPath
        : '/$resolvedPath';
    final uri = Uri.parse('https://$host$normalizedPath');
    return _ensureGstinQuery(uri, gstin, endpointPath);
  }

  Uri _ensureGstinQuery(Uri uri, String gstin, String endpointPath) {
    if (endpointPath.contains('{gstin}') ||
        uri.queryParameters.containsKey('gstin')) {
      return uri;
    }
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'gstin': gstin},
    );
  }

  dynamic _decodeBody(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      throw const AppException('GSTIN lookup returned an unreadable response.');
    }
  }

  Map<String, dynamic> _unwrapPayload(dynamic value) {
    final root = _toStringKeyMap(value);
    final status = _readString(root, const ['status', 'message', 'detail']);
    if ((root['success'] == false || root['ok'] == false) &&
        status.isNotEmpty) {
      throw AppException(status);
    }

    for (final key in const ['data', 'result', 'payload', 'response']) {
      final nested = root[key];
      final nestedMap = _toStringKeyMap(nested);
      if (nestedMap.isNotEmpty) {
        return nestedMap;
      }
    }
    return root;
  }

  String _readString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  Map<String, dynamic> _toStringKeyMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return const {};
  }

  String _normalizeHost(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');
  }
}

class GstinValidationResult {
  const GstinValidationResult({required this.gstin, required this.isValid});

  final String gstin;
  final bool isValid;
}

class GstinBusinessDetails {
  const GstinBusinessDetails({
    required this.gstin,
    required this.legalName,
    required this.tradeName,
    required this.stateName,
    required this.stateCode,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.pincode,
    required this.rawPayload,
  });

  factory GstinBusinessDetails.fromPayload(
    Map<String, dynamic> payload, {
    required String fallbackGstin,
  }) {
    final flattened = <String, List<dynamic>>{};
    _flatten(payload, flattened);

    final principalAddress =
        _findNamedMap(payload, const [
          'pradr',
          'principalAddress',
          'principalPlaceOfBusiness',
          'address',
          'adr',
        ]) ??
        const {};
    final addressMap =
        _findNamedMap(principalAddress, const ['addr', 'address']) ??
        principalAddress;

    final gstin = _firstText(flattened, const [
      'gstin',
      'gstNumber',
      'gst_number',
      'gstno',
    ], fallback: fallbackGstin);
    final legalName = _firstText(flattened, const [
      'lgnm',
      'legalName',
      'legal_name',
      'taxpayerName',
      'businessName',
      'name',
    ]);
    final tradeName = _firstText(flattened, const [
      'tradeNam',
      'trdnam',
      'tradeName',
      'trade_name',
      'businessTradeName',
    ]);
    final stateCode = _firstText(flattened, const ['stcd', 'stateCode']);
    final derivedStateCode = stateCode.isNotEmpty
        ? stateCode.padLeft(2, '0')
        : (gstin.length >= 2 ? gstin.substring(0, 2) : '');
    final explicitState = _firstText(flattened, const [
      'state',
      'stateName',
      'statename',
    ]);
    final stateName = explicitState.isNotEmpty
        ? explicitState
        : _gstStateNames[derivedStateCode] ?? '';

    final addressPieces = <String>[
      _readAddressValue(addressMap, const ['bno', 'buildingNumber', 'doorNum']),
      _readAddressValue(addressMap, const ['flno', 'floorNumber', 'floorNum']),
      _readAddressValue(addressMap, const ['bnm', 'buildingName']),
      _readAddressValue(addressMap, const ['st', 'street']),
      _readAddressValue(addressMap, const ['loc', 'location']),
      _readAddressValue(addressMap, const ['dst', 'district']),
      _readAddressValue(addressMap, const ['city']),
      stateName,
      _readAddressValue(addressMap, const [
        'pncd',
        'pincode',
        'pinCode',
        'zip',
      ]),
    ];
    final filteredAddress = _dedupe(addressPieces);

    return GstinBusinessDetails(
      gstin: gstin,
      legalName: legalName,
      tradeName: tradeName,
      stateName: stateName,
      stateCode: derivedStateCode,
      addressLine1: filteredAddress.take(4).join(', '),
      addressLine2: filteredAddress.skip(4).join(', '),
      city: _readAddressValue(addressMap, const ['city', 'loc']),
      pincode: _readAddressValue(addressMap, const [
        'pncd',
        'pincode',
        'pinCode',
        'zip',
      ]),
      rawPayload: payload,
    );
  }

  final String gstin;
  final String legalName;
  final String tradeName;
  final String stateName;
  final String stateCode;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String pincode;
  final Map<String, dynamic> rawPayload;

  String get displayName => tradeName.isNotEmpty ? tradeName : legalName;

  String get formattedAddress {
    final pieces = _dedupe([addressLine1, addressLine2]);
    return pieces.join(', ');
  }

  static void _flatten(dynamic value, Map<String, List<dynamic>> output) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = _normalizeKey(entry.key.toString());
        if (key.isNotEmpty) {
          output.putIfAbsent(key, () => <dynamic>[]).add(entry.value);
        }
        _flatten(entry.value, output);
      }
      return;
    }
    if (value is List) {
      for (final item in value) {
        _flatten(item, output);
      }
    }
  }

  static Map<String, dynamic>? _findNamedMap(
    Map<String, dynamic> value,
    List<String> keys,
  ) {
    final targets = keys.map(_normalizeKey).toSet();
    for (final entry in value.entries) {
      final currentKey = _normalizeKey(entry.key);
      final entryValue = entry.value;
      if (targets.contains(currentKey) && entryValue is Map) {
        return entryValue.map(
          (nestedKey, nestedValue) =>
              MapEntry(nestedKey.toString(), nestedValue),
        );
      }
      if (entryValue is Map) {
        final nested = _findNamedMap(
          entryValue.map(
            (nestedKey, nestedValue) =>
                MapEntry(nestedKey.toString(), nestedValue),
          ),
          keys,
        );
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  static String _firstText(
    Map<String, List<dynamic>> flattened,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final values = flattened[_normalizeKey(key)];
      if (values == null) continue;
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          return text;
        }
      }
    }
    return fallback;
  }

  static String _readAddressValue(
    Map<String, dynamic> address,
    List<String> keys,
  ) {
    for (final key in keys) {
      for (final entry in address.entries) {
        if (_normalizeKey(entry.key) != _normalizeKey(key)) continue;
        final text = entry.value?.toString().trim() ?? '';
        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          return text;
        }
      }
    }
    return '';
  }

  static List<String> _dedupe(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (!seen.add(normalized)) continue;
      result.add(trimmed);
    }
    return result;
  }

  static String _normalizeKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static const Map<String, String> _gstStateNames = {
    '01': 'Jammu and Kashmir',
    '02': 'Himachal Pradesh',
    '03': 'Punjab',
    '04': 'Chandigarh',
    '05': 'Uttarakhand',
    '06': 'Haryana',
    '07': 'Delhi',
    '08': 'Rajasthan',
    '09': 'Uttar Pradesh',
    '10': 'Bihar',
    '11': 'Sikkim',
    '12': 'Arunachal Pradesh',
    '13': 'Nagaland',
    '14': 'Manipur',
    '15': 'Mizoram',
    '16': 'Tripura',
    '17': 'Meghalaya',
    '18': 'Assam',
    '19': 'West Bengal',
    '20': 'Jharkhand',
    '21': 'Odisha',
    '22': 'Chhattisgarh',
    '23': 'Madhya Pradesh',
    '24': 'Gujarat',
    '26': 'Dadra and Nagar Haveli and Daman and Diu',
    '27': 'Maharashtra',
    '28': 'Andhra Pradesh',
    '29': 'Karnataka',
    '30': 'Goa',
    '31': 'Lakshadweep',
    '32': 'Kerala',
    '33': 'Tamil Nadu',
    '34': 'Puducherry',
    '35': 'Andaman and Nicobar Islands',
    '36': 'Telangana',
    '37': 'Andhra Pradesh',
    '38': 'Ladakh',
    '97': 'Other Territory',
  };
}
