import 'package:equatable/equatable.dart';

class CompanyProfile extends Equatable {
  const CompanyProfile({
    required this.businessName,
    required this.legalName,
    required this.gstin,
    required this.pan,
    required this.email,
    required this.phone,
    required this.website,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.pincode,
    required this.country,
    required this.bankName,
    required this.bankAccountName,
    required this.bankAccountNumber,
    required this.ifscCode,
    required this.upiId,
    required this.defaultInvoiceTerms,
    required this.defaultQuotationTerms,
    required this.logoBase64,
    required this.paymentQrBase64,
    required this.updatedAt,
  });

  factory CompanyProfile.empty() {
    return CompanyProfile(
      businessName: '',
      legalName: '',
      gstin: '',
      pan: '',
      email: '',
      phone: '',
      website: '',
      addressLine1: '',
      addressLine2: '',
      city: '',
      state: '',
      pincode: '',
      country: 'India',
      bankName: '',
      bankAccountName: '',
      bankAccountNumber: '',
      ifscCode: '',
      upiId: '',
      defaultInvoiceTerms: 'Thank you for your business.',
      defaultQuotationTerms: 'Quotation validity: 15 days.',
      logoBase64: '',
      paymentQrBase64: '',
      updatedAt: DateTime.now(),
    );
  }

  final String businessName;
  final String legalName;
  final String gstin;
  final String pan;
  final String email;
  final String phone;
  final String website;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String pincode;
  final String country;
  final String bankName;
  final String bankAccountName;
  final String bankAccountNumber;
  final String ifscCode;
  final String upiId;
  final String defaultInvoiceTerms;
  final String defaultQuotationTerms;
  final String logoBase64;
  final String paymentQrBase64;
  final DateTime updatedAt;

  CompanyProfile copyWith({
    String? businessName,
    String? legalName,
    String? gstin,
    String? pan,
    String? email,
    String? phone,
    String? website,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? pincode,
    String? country,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? ifscCode,
    String? upiId,
    String? defaultInvoiceTerms,
    String? defaultQuotationTerms,
    String? logoBase64,
    String? paymentQrBase64,
    DateTime? updatedAt,
  }) {
    return CompanyProfile(
      businessName: businessName ?? this.businessName,
      legalName: legalName ?? this.legalName,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      country: country ?? this.country,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      defaultInvoiceTerms: defaultInvoiceTerms ?? this.defaultInvoiceTerms,
      defaultQuotationTerms:
          defaultQuotationTerms ?? this.defaultQuotationTerms,
      logoBase64: logoBase64 ?? this.logoBase64,
      paymentQrBase64: paymentQrBase64 ?? this.paymentQrBase64,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    businessName,
    legalName,
    gstin,
    pan,
    email,
    phone,
    website,
    addressLine1,
    addressLine2,
    city,
    state,
    pincode,
    country,
    bankName,
    bankAccountName,
    bankAccountNumber,
    ifscCode,
    upiId,
    defaultInvoiceTerms,
    defaultQuotationTerms,
    logoBase64,
    paymentQrBase64,
    updatedAt,
  ];
}
