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
    required this.customCustomerFields,
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
      customCustomerFields: const [],
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
  final List<String> customCustomerFields;
  final List<String> customLineItemFields;
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
    customCustomerFields,
    customLineItemFields,
    updatedAt,
  ];
}
