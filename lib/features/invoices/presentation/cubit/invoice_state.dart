part of 'invoice_cubit.dart';

enum InvoiceStatusView { initial, loading, loaded, saving, saved, failure }

class InvoiceState extends Equatable {
  const InvoiceState({
    this.status = InvoiceStatusView.initial,
    this.invoices = const [],
    this.customers = const [],
    this.products = const [],
    this.searchQuery = '',
    this.settings,
    this.companyProfile,
    this.draft,
    this.message,
  });

  final InvoiceStatusView status;
  final List<Invoice> invoices;
  final List<Customer> customers;
  final List<ProductService> products;
  final String searchQuery;
  final AppSettings? settings;
  final CompanyProfile? companyProfile;
  final InvoiceDraft? draft;
  final String? message;

  bool get isBusy =>
      status == InvoiceStatusView.loading || status == InvoiceStatusView.saving;

  List<Invoice> get filteredInvoices {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return invoices;
    return invoices.where((invoice) {
      final customerName =
          invoice.customerSnapshot['name']?.toString().toLowerCase() ?? '';
      return invoice.invoiceNumber.toLowerCase().contains(query) ||
          customerName.contains(query) ||
          invoice.status.label.toLowerCase().contains(query);
    }).toList();
  }

  InvoiceState copyWith({
    InvoiceStatusView? status,
    List<Invoice>? invoices,
    List<Customer>? customers,
    List<ProductService>? products,
    String? searchQuery,
    AppSettings? settings,
    CompanyProfile? companyProfile,
    InvoiceDraft? draft,
    String? message,
    bool clearMessage = false,
  }) {
    return InvoiceState(
      status: status ?? this.status,
      invoices: invoices ?? this.invoices,
      customers: customers ?? this.customers,
      products: products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
      settings: settings ?? this.settings,
      companyProfile: companyProfile ?? this.companyProfile,
      draft: draft ?? this.draft,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    invoices,
    customers,
    products,
    searchQuery,
    settings,
    companyProfile,
    draft,
    message,
  ];
}
