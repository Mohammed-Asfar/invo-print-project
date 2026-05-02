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
