part of 'quotation_cubit.dart';

enum QuotationViewStatus { initial, loading, loaded, saving, saved, failure }

class QuotationState extends Equatable {
  const QuotationState({
    this.status = QuotationViewStatus.initial,
    this.quotations = const [],
    this.customers = const [],
    this.settings,
    this.companyProfile,
    this.searchQuery = '',
    this.message,
  });

  final QuotationViewStatus status;
  final List<Quotation> quotations;
  final List<Customer> customers;
  final AppSettings? settings;
  final CompanyProfile? companyProfile;
  final String searchQuery;
  final String? message;

  bool get isBusy =>
      status == QuotationViewStatus.loading ||
      status == QuotationViewStatus.saving;

  List<Quotation> get filteredQuotations {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return quotations;
    return quotations.where((quotation) {
      return [
        quotation.quotationNumber,
        quotation.customerName,
        quotation.status.label,
        quotation.grandTotal.toStringAsFixed(2),
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  QuotationState copyWith({
    QuotationViewStatus? status,
    List<Quotation>? quotations,
    List<Customer>? customers,
    AppSettings? settings,
    CompanyProfile? companyProfile,
    String? searchQuery,
    String? message,
    bool clearMessage = false,
  }) {
    return QuotationState(
      status: status ?? this.status,
      quotations: quotations ?? this.quotations,
      customers: customers ?? this.customers,
      settings: settings ?? this.settings,
      companyProfile: companyProfile ?? this.companyProfile,
      searchQuery: searchQuery ?? this.searchQuery,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    quotations,
    customers,
    settings,
    companyProfile,
    searchQuery,
    message,
  ];
}
