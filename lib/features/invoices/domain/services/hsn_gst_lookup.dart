class HsnGstLookup {
  const HsnGstLookup(this._ratesByCode);

  final Map<String, double> _ratesByCode;

  factory HsnGstLookup.fromJsonMap(Map<String, dynamic> json) {
    final rates = <String, double>{};
    for (final entry in json.entries) {
      final normalized = _normalizeCode(entry.key);
      if (normalized.isEmpty) continue;
      final value = entry.value;
      if (value is! Map) continue;
      final rawRate = value['igst_rate'];
      final rate = _toDouble(rawRate);
      if (rate == null) continue;
      rates[normalized] = rate;
    }
    return HsnGstLookup(rates);
  }

  double? findRate(String rawCode) {
    final normalized = _normalizeCode(rawCode);
    if (normalized.isEmpty) return null;
    for (var length = normalized.length; length >= 2; length--) {
      final prefix = normalized.substring(0, length);
      final rate = _ratesByCode[prefix];
      if (rate != null) return rate;
    }
    return null;
  }

  static String _normalizeCode(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}
