part of 'customer_cubit.dart';

enum CustomerStatus { initial, loading, loaded, saving, saved, failure }

class CustomerState extends Equatable {
  const CustomerState({
    this.status = CustomerStatus.initial,
    this.customers = const [],
    this.searchQuery = '',
    this.globalLoyaltyEnabled = false,
    this.message,
  });

  final CustomerStatus status;
  final List<Customer> customers;
  final String searchQuery;
  final bool globalLoyaltyEnabled;
  final String? message;

  bool get isBusy =>
      status == CustomerStatus.loading || status == CustomerStatus.saving;

  List<Customer> get filteredCustomers {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return customers;
    return customers.where((customer) {
      return customer.name.toLowerCase().contains(query) ||
          customer.phone.toLowerCase().contains(query) ||
          customer.email.toLowerCase().contains(query) ||
          customer.gstin.toLowerCase().contains(query);
    }).toList();
  }

  CustomerState copyWith({
    CustomerStatus? status,
    List<Customer>? customers,
    String? searchQuery,
    bool? globalLoyaltyEnabled,
    String? message,
    bool clearMessage = false,
  }) {
    return CustomerState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      searchQuery: searchQuery ?? this.searchQuery,
      globalLoyaltyEnabled: globalLoyaltyEnabled ?? this.globalLoyaltyEnabled,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    customers,
    searchQuery,
    globalLoyaltyEnabled,
    message,
  ];
}
