import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.gstEnabled,
    required this.defaultGstRate,
    required this.invoicePrefix,
    required this.invoiceSeparator,
    required this.invoiceDateFormat,
    required this.invoiceNextNumber,
    required this.invoiceNumberPadding,
    required this.quotationPrefix,
    required this.quotationSeparator,
    required this.quotationDateFormat,
    required this.quotationNextNumber,
    required this.quotationNumberPadding,
    required this.loyaltyEnabled,
    required this.pointsPerRupee,
    required this.pointsRedemptionValue,
    required this.currencyCode,
    required this.currencySymbol,
    required this.themeMode,
    required this.primaryColorHex,
    required this.showLineItemHsn,
    required this.showCustomerStateCode,
    required this.gstinLookupEnabled,
    required this.gstinLookupApiKey,
    required this.gstinLookupApiHost,
    required this.gstinValidationApiPath,
    required this.gstinLookupApiPath,
    required this.defaultCustomerState,
    required this.defaultShippingState,
    required this.defaultLineItemUnit,
    required this.customCustomerFields,
    required this.customShippingFields,
    required this.customLineItemFields,
    required this.updatedAt,
  });

  factory AppSettings.initial() {
    return AppSettings(
      gstEnabled: true,
      defaultGstRate: 18,
      invoicePrefix: 'INV',
      invoiceSeparator: '-',
      invoiceDateFormat: 'yyyy/MM',
      invoiceNextNumber: 1,
      invoiceNumberPadding: 4,
      quotationPrefix: 'QUO',
      quotationSeparator: '-',
      quotationDateFormat: 'yyyy/MM',
      quotationNextNumber: 1,
      quotationNumberPadding: 4,
      loyaltyEnabled: true,
      pointsPerRupee: 0.01,
      pointsRedemptionValue: 1,
      currencyCode: 'INR',
      currencySymbol: 'Rs',
      themeMode: 'dark',
      primaryColorHex: '#7C4DFF',
      showLineItemHsn: true,
      showCustomerStateCode: true,
      gstinLookupEnabled: false,
      gstinLookupApiKey: '',
      gstinLookupApiHost: 'powerful-gstin-tool.p.rapidapi.com',
      gstinValidationApiPath: '/v1/gstin/{gstin}/status',
      gstinLookupApiPath: '/v1/gstin/{gstin}/details',
      defaultCustomerState: '',
      defaultShippingState: '',
      defaultLineItemUnit: 'service',
      customCustomerFields: const [],
      customShippingFields: const [],
      customLineItemFields: const [],
      updatedAt: DateTime.now(),
    );
  }

  final bool gstEnabled;
  final double defaultGstRate;
  final String invoicePrefix;
  final String invoiceSeparator;
  final String invoiceDateFormat;
  final int invoiceNextNumber;
  final int invoiceNumberPadding;
  final String quotationPrefix;
  final String quotationSeparator;
  final String quotationDateFormat;
  final int quotationNextNumber;
  final int quotationNumberPadding;
  final bool loyaltyEnabled;
  final double pointsPerRupee;
  final double pointsRedemptionValue;
  final String currencyCode;
  final String currencySymbol;
  final String themeMode;
  final String primaryColorHex;
  final bool showLineItemHsn;
  final bool showCustomerStateCode;
  final bool gstinLookupEnabled;
  final String gstinLookupApiKey;
  final String gstinLookupApiHost;
  final String gstinValidationApiPath;
  final String gstinLookupApiPath;
  final String defaultCustomerState;
  final String defaultShippingState;
  final String defaultLineItemUnit;
  final List<CustomFieldDefinition> customCustomerFields;
  final List<CustomFieldDefinition> customShippingFields;
  final List<CustomFieldDefinition> customLineItemFields;
  final DateTime updatedAt;

  AppSettings copyWith({
    bool? gstEnabled,
    double? defaultGstRate,
    String? invoicePrefix,
    String? invoiceSeparator,
    String? invoiceDateFormat,
    int? invoiceNextNumber,
    int? invoiceNumberPadding,
    String? quotationPrefix,
    String? quotationSeparator,
    String? quotationDateFormat,
    int? quotationNextNumber,
    int? quotationNumberPadding,
    bool? loyaltyEnabled,
    double? pointsPerRupee,
    double? pointsRedemptionValue,
    String? currencyCode,
    String? currencySymbol,
    String? themeMode,
    String? primaryColorHex,
    bool? showLineItemHsn,
    bool? showCustomerStateCode,
    bool? gstinLookupEnabled,
    String? gstinLookupApiKey,
    String? gstinLookupApiHost,
    String? gstinValidationApiPath,
    String? gstinLookupApiPath,
    String? defaultCustomerState,
    String? defaultShippingState,
    String? defaultLineItemUnit,
    List<CustomFieldDefinition>? customCustomerFields,
    List<CustomFieldDefinition>? customShippingFields,
    List<CustomFieldDefinition>? customLineItemFields,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      gstEnabled: gstEnabled ?? this.gstEnabled,
      defaultGstRate: defaultGstRate ?? this.defaultGstRate,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoiceSeparator: invoiceSeparator ?? this.invoiceSeparator,
      invoiceDateFormat: invoiceDateFormat ?? this.invoiceDateFormat,
      invoiceNextNumber: invoiceNextNumber ?? this.invoiceNextNumber,
      invoiceNumberPadding: invoiceNumberPadding ?? this.invoiceNumberPadding,
      quotationPrefix: quotationPrefix ?? this.quotationPrefix,
      quotationSeparator: quotationSeparator ?? this.quotationSeparator,
      quotationDateFormat: quotationDateFormat ?? this.quotationDateFormat,
      quotationNextNumber: quotationNextNumber ?? this.quotationNextNumber,
      quotationNumberPadding:
          quotationNumberPadding ?? this.quotationNumberPadding,
      loyaltyEnabled: loyaltyEnabled ?? this.loyaltyEnabled,
      pointsPerRupee: pointsPerRupee ?? this.pointsPerRupee,
      pointsRedemptionValue:
          pointsRedemptionValue ?? this.pointsRedemptionValue,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      themeMode: themeMode ?? this.themeMode,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      showLineItemHsn: showLineItemHsn ?? this.showLineItemHsn,
      showCustomerStateCode:
          showCustomerStateCode ?? this.showCustomerStateCode,
      gstinLookupEnabled: gstinLookupEnabled ?? this.gstinLookupEnabled,
      gstinLookupApiKey: gstinLookupApiKey ?? this.gstinLookupApiKey,
      gstinLookupApiHost: gstinLookupApiHost ?? this.gstinLookupApiHost,
      gstinValidationApiPath:
          gstinValidationApiPath ?? this.gstinValidationApiPath,
      gstinLookupApiPath: gstinLookupApiPath ?? this.gstinLookupApiPath,
      defaultCustomerState: defaultCustomerState ?? this.defaultCustomerState,
      defaultShippingState: defaultShippingState ?? this.defaultShippingState,
      defaultLineItemUnit: defaultLineItemUnit ?? this.defaultLineItemUnit,
      customCustomerFields: customCustomerFields ?? this.customCustomerFields,
      customShippingFields: customShippingFields ?? this.customShippingFields,
      customLineItemFields: customLineItemFields ?? this.customLineItemFields,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    gstEnabled,
    defaultGstRate,
    invoicePrefix,
    invoiceSeparator,
    invoiceDateFormat,
    invoiceNextNumber,
    invoiceNumberPadding,
    quotationPrefix,
    quotationSeparator,
    quotationDateFormat,
    quotationNextNumber,
    quotationNumberPadding,
    loyaltyEnabled,
    pointsPerRupee,
    pointsRedemptionValue,
    currencyCode,
    currencySymbol,
    themeMode,
    primaryColorHex,
    showLineItemHsn,
    showCustomerStateCode,
    gstinLookupEnabled,
    gstinLookupApiKey,
    gstinLookupApiHost,
    gstinValidationApiPath,
    gstinLookupApiPath,
    defaultCustomerState,
    defaultShippingState,
    defaultLineItemUnit,
    customCustomerFields,
    customShippingFields,
    customLineItemFields,
    updatedAt,
  ];
}

class CustomFieldDefinition extends Equatable {
  const CustomFieldDefinition({
    required this.name,
    this.defaultValue = '',
    this.isRequired = false,
  });

  final String name;
  final String defaultValue;
  final bool isRequired;

  CustomFieldDefinition copyWith({
    String? name,
    String? defaultValue,
    bool? isRequired,
  }) {
    return CustomFieldDefinition(
      name: name ?? this.name,
      defaultValue: defaultValue ?? this.defaultValue,
      isRequired: isRequired ?? this.isRequired,
    );
  }

  @override
  List<Object?> get props => [name, defaultValue, isRequired];
}
