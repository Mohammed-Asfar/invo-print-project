import '../../domain/entities/company_profile.dart';

class CompanyProfileModel extends CompanyProfile {
  const CompanyProfileModel({
    required super.businessName,
    required super.legalName,
    required super.gstin,
    required super.pan,
    required super.email,
    required super.phone,
    required super.website,
    required super.addressLine1,
    required super.addressLine2,
    required super.city,
    required super.state,
    required super.pincode,
    required super.country,
    required super.bankName,
    required super.bankAccountName,
    required super.bankAccountNumber,
    required super.ifscCode,
    required super.upiId,
    required super.defaultInvoiceTerms,
    required super.defaultQuotationTerms,
    required super.logoBase64,
    required super.paymentQrBase64,
    required super.updatedAt,
  });

  factory CompanyProfileModel.fromEntity(CompanyProfile profile) {
    return CompanyProfileModel(
      businessName: profile.businessName,
      legalName: profile.legalName,
      gstin: profile.gstin,
      pan: profile.pan,
      email: profile.email,
      phone: profile.phone,
      website: profile.website,
      addressLine1: profile.addressLine1,
      addressLine2: profile.addressLine2,
      city: profile.city,
      state: profile.state,
      pincode: profile.pincode,
      country: profile.country,
      bankName: profile.bankName,
      bankAccountName: profile.bankAccountName,
      bankAccountNumber: profile.bankAccountNumber,
      ifscCode: profile.ifscCode,
      upiId: profile.upiId,
      defaultInvoiceTerms: profile.defaultInvoiceTerms,
      defaultQuotationTerms: profile.defaultQuotationTerms,
      logoBase64: profile.logoBase64,
      paymentQrBase64: profile.paymentQrBase64,
      updatedAt: profile.updatedAt,
    );
  }

  factory CompanyProfileModel.fromMap(Map<String, dynamic> map) {
    final defaults = CompanyProfile.empty();
    return CompanyProfileModel(
      businessName: map['businessName'] as String? ?? defaults.businessName,
      legalName: map['legalName'] as String? ?? defaults.legalName,
      gstin: map['gstin'] as String? ?? defaults.gstin,
      pan: map['pan'] as String? ?? defaults.pan,
      email: map['email'] as String? ?? defaults.email,
      phone: map['phone'] as String? ?? defaults.phone,
      website: map['website'] as String? ?? defaults.website,
      addressLine1: map['addressLine1'] as String? ?? defaults.addressLine1,
      addressLine2: map['addressLine2'] as String? ?? defaults.addressLine2,
      city: map['city'] as String? ?? defaults.city,
      state: map['state'] as String? ?? defaults.state,
      pincode: map['pincode'] as String? ?? defaults.pincode,
      country: map['country'] as String? ?? defaults.country,
      bankName: map['bankName'] as String? ?? defaults.bankName,
      bankAccountName:
          map['bankAccountName'] as String? ?? defaults.bankAccountName,
      bankAccountNumber:
          map['bankAccountNumber'] as String? ?? defaults.bankAccountNumber,
      ifscCode: map['ifscCode'] as String? ?? defaults.ifscCode,
      upiId: map['upiId'] as String? ?? defaults.upiId,
      defaultInvoiceTerms:
          map['defaultInvoiceTerms'] as String? ?? defaults.defaultInvoiceTerms,
      defaultQuotationTerms:
          map['defaultQuotationTerms'] as String? ??
          defaults.defaultQuotationTerms,
      logoBase64: map['logoBase64'] as String? ?? defaults.logoBase64,
      paymentQrBase64:
          map['paymentQrBase64'] as String? ?? defaults.paymentQrBase64,
      updatedAt: _toDateTime(map['updatedAt']) ?? defaults.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'legalName': legalName,
      'gstin': gstin,
      'pan': pan,
      'email': email,
      'phone': phone,
      'website': website,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
      'bankName': bankName,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'ifscCode': ifscCode,
      'upiId': upiId,
      'defaultInvoiceTerms': defaultInvoiceTerms,
      'defaultQuotationTerms': defaultQuotationTerms,
      'logoBase64': logoBase64,
      'paymentQrBase64': paymentQrBase64,
      'updatedAt': updatedAt,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
