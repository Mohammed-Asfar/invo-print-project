import '../../domain/entities/app_settings.dart';

class AppSettingsModel extends AppSettings {
  const AppSettingsModel({
    required super.gstEnabled,
    required super.defaultGstRate,
    required super.invoicePrefix,
    required super.invoiceSeparator,
    required super.invoiceDateFormat,
    required super.invoiceNextNumber,
    required super.invoiceNumberPadding,
    required super.quotationPrefix,
    required super.quotationSeparator,
    required super.quotationDateFormat,
    required super.quotationNextNumber,
    required super.quotationNumberPadding,
    required super.loyaltyEnabled,
    required super.pointsPerRupee,
    required super.pointsRedemptionValue,
    required super.currencyCode,
    required super.currencySymbol,
    required super.themeMode,
    required super.primaryColorHex,
    required super.showLineItemHsn,
    required super.gstinLookupEnabled,
    required super.gstinLookupApiKey,
    required super.gstinLookupApiHost,
    required super.gstinValidationApiPath,
    required super.gstinLookupApiPath,
    required super.defaultCustomerState,
    required super.defaultShippingState,
    required super.defaultLineItemUnit,
    required super.customCustomerFields,
    required super.customShippingFields,
    required super.customLineItemFields,
    required super.updatedAt,
  });

  factory AppSettingsModel.fromEntity(AppSettings settings) {
    return AppSettingsModel(
      gstEnabled: settings.gstEnabled,
      defaultGstRate: settings.defaultGstRate,
      invoicePrefix: settings.invoicePrefix,
      invoiceSeparator: settings.invoiceSeparator,
      invoiceDateFormat: settings.invoiceDateFormat,
      invoiceNextNumber: settings.invoiceNextNumber,
      invoiceNumberPadding: settings.invoiceNumberPadding,
      quotationPrefix: settings.quotationPrefix,
      quotationSeparator: settings.quotationSeparator,
      quotationDateFormat: settings.quotationDateFormat,
      quotationNextNumber: settings.quotationNextNumber,
      quotationNumberPadding: settings.quotationNumberPadding,
      loyaltyEnabled: settings.loyaltyEnabled,
      pointsPerRupee: settings.pointsPerRupee,
      pointsRedemptionValue: settings.pointsRedemptionValue,
      currencyCode: settings.currencyCode,
      currencySymbol: settings.currencySymbol,
      themeMode: settings.themeMode,
      primaryColorHex: settings.primaryColorHex,
      showLineItemHsn: settings.showLineItemHsn,
      gstinLookupEnabled: settings.gstinLookupEnabled,
      gstinLookupApiKey: settings.gstinLookupApiKey,
      gstinLookupApiHost: settings.gstinLookupApiHost,
      gstinValidationApiPath: settings.gstinValidationApiPath,
      gstinLookupApiPath: settings.gstinLookupApiPath,
      defaultCustomerState: settings.defaultCustomerState,
      defaultShippingState: settings.defaultShippingState,
      defaultLineItemUnit: settings.defaultLineItemUnit,
      customCustomerFields: settings.customCustomerFields,
      customShippingFields: settings.customShippingFields,
      customLineItemFields: settings.customLineItemFields,
      updatedAt: settings.updatedAt,
    );
  }

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    final defaults = AppSettings.initial();
    return AppSettingsModel(
      gstEnabled: map['gstEnabled'] as bool? ?? defaults.gstEnabled,
      defaultGstRate: _toDouble(map['defaultGstRate'], defaults.defaultGstRate),
      invoicePrefix: map['invoicePrefix'] as String? ?? defaults.invoicePrefix,
      invoiceSeparator:
          map['invoiceSeparator'] as String? ?? defaults.invoiceSeparator,
      invoiceDateFormat:
          map['invoiceDateFormat'] as String? ?? defaults.invoiceDateFormat,
      invoiceNextNumber:
          map['invoiceNextNumber'] as int? ?? defaults.invoiceNextNumber,
      invoiceNumberPadding:
          map['invoiceNumberPadding'] as int? ?? defaults.invoiceNumberPadding,
      quotationPrefix:
          map['quotationPrefix'] as String? ?? defaults.quotationPrefix,
      quotationSeparator:
          map['quotationSeparator'] as String? ?? defaults.quotationSeparator,
      quotationDateFormat:
          map['quotationDateFormat'] as String? ?? defaults.quotationDateFormat,
      quotationNextNumber:
          map['quotationNextNumber'] as int? ?? defaults.quotationNextNumber,
      quotationNumberPadding:
          map['quotationNumberPadding'] as int? ??
          defaults.quotationNumberPadding,
      loyaltyEnabled: map['loyaltyEnabled'] as bool? ?? defaults.loyaltyEnabled,
      pointsPerRupee: _toDouble(map['pointsPerRupee'], defaults.pointsPerRupee),
      pointsRedemptionValue: _toDouble(
        map['pointsRedemptionValue'],
        defaults.pointsRedemptionValue,
      ),
      currencyCode: map['currencyCode'] as String? ?? defaults.currencyCode,
      currencySymbol:
          map['currencySymbol'] as String? ?? defaults.currencySymbol,
      themeMode: map['themeMode'] as String? ?? defaults.themeMode,
      primaryColorHex:
          map['primaryColorHex'] as String? ?? defaults.primaryColorHex,
      showLineItemHsn:
          map['showLineItemHsn'] as bool? ?? defaults.showLineItemHsn,
      gstinLookupEnabled:
          map['gstinLookupEnabled'] as bool? ?? defaults.gstinLookupEnabled,
      gstinLookupApiKey:
          map['gstinLookupApiKey'] as String? ?? defaults.gstinLookupApiKey,
      gstinLookupApiHost:
          map['gstinLookupApiHost'] as String? ?? defaults.gstinLookupApiHost,
      gstinValidationApiPath:
          map['gstinValidationApiPath'] as String? ??
          defaults.gstinValidationApiPath,
      gstinLookupApiPath:
          map['gstinLookupApiPath'] as String? ?? defaults.gstinLookupApiPath,
      defaultCustomerState:
          map['defaultCustomerState'] as String? ??
          defaults.defaultCustomerState,
      defaultShippingState:
          map['defaultShippingState'] as String? ??
          defaults.defaultShippingState,
      defaultLineItemUnit:
          map['defaultLineItemUnit'] as String? ?? defaults.defaultLineItemUnit,
      customCustomerFields: _toCustomFields(
        map['customCustomerFields'],
        defaults.customCustomerFields,
      ),
      customShippingFields: _toCustomFields(
        map['customShippingFields'],
        defaults.customShippingFields,
      ),
      customLineItemFields: _toCustomFields(
        map['customLineItemFields'],
        defaults.customLineItemFields,
      ),
      updatedAt: _toDateTime(map['updatedAt']) ?? defaults.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gstEnabled': gstEnabled,
      'defaultGstRate': defaultGstRate,
      'invoicePrefix': invoicePrefix,
      'invoiceSeparator': invoiceSeparator,
      'invoiceDateFormat': invoiceDateFormat,
      'invoiceNextNumber': invoiceNextNumber,
      'invoiceNumberPadding': invoiceNumberPadding,
      'quotationPrefix': quotationPrefix,
      'quotationSeparator': quotationSeparator,
      'quotationDateFormat': quotationDateFormat,
      'quotationNextNumber': quotationNextNumber,
      'quotationNumberPadding': quotationNumberPadding,
      'loyaltyEnabled': loyaltyEnabled,
      'pointsPerRupee': pointsPerRupee,
      'pointsRedemptionValue': pointsRedemptionValue,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'themeMode': themeMode,
      'primaryColorHex': primaryColorHex,
      'showLineItemHsn': showLineItemHsn,
      'gstinLookupEnabled': gstinLookupEnabled,
      'gstinLookupApiKey': gstinLookupApiKey,
      'gstinLookupApiHost': gstinLookupApiHost,
      'gstinValidationApiPath': gstinValidationApiPath,
      'gstinLookupApiPath': gstinLookupApiPath,
      'defaultCustomerState': defaultCustomerState,
      'defaultShippingState': defaultShippingState,
      'defaultLineItemUnit': defaultLineItemUnit,
      'customCustomerFields': customCustomerFields.map(_fieldToMap).toList(),
      'customShippingFields': customShippingFields.map(_fieldToMap).toList(),
      'customLineItemFields': customLineItemFields.map(_fieldToMap).toList(),
      'updatedAt': updatedAt,
    };
  }

  static List<CustomFieldDefinition> _toCustomFields(
    dynamic value,
    List<CustomFieldDefinition> fallback,
  ) {
    if (value is List) {
      return value
          .map(_fieldFromValue)
          .where((item) => item.name.trim().isNotEmpty)
          .toList();
    }
    return fallback;
  }

  static CustomFieldDefinition _fieldFromValue(dynamic value) {
    if (value is String) {
      return CustomFieldDefinition(name: value.trim());
    }
    if (value is Map) {
      return CustomFieldDefinition(
        name: value['name']?.toString().trim() ?? '',
        defaultValue: value['defaultValue']?.toString() ?? '',
        isRequired: value['required'] as bool? ?? false,
      );
    }
    return const CustomFieldDefinition(name: '');
  }

  static Map<String, dynamic> _fieldToMap(CustomFieldDefinition field) {
    return {
      'name': field.name,
      'defaultValue': field.defaultValue,
      'required': field.isRequired,
    };
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
