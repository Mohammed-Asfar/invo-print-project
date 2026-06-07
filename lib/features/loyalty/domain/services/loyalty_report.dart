import '../../../customers/domain/entities/customer.dart';
import '../../../invoices/domain/entities/invoice.dart';

class LoyaltyReport {
  const LoyaltyReport({
    required this.customers,
    required this.recentAwards,
    required this.totalCustomers,
    required this.activeMembers,
    required this.pointsOutstanding,
    required this.lifetimePointsEarned,
    required this.lifetimePointsRedeemed,
    required this.outstandingValue,
  });

  final List<LoyaltyCustomerRow> customers;
  final List<LoyaltyAwardRow> recentAwards;
  final int totalCustomers;
  final int activeMembers;
  final int pointsOutstanding;
  final int lifetimePointsEarned;
  final int lifetimePointsRedeemed;
  final double outstandingValue;
}

class LoyaltyCustomerRow {
  const LoyaltyCustomerRow({
    required this.customer,
    required this.pointsBalance,
    required this.lifetimeEarned,
    required this.lifetimeRedeemed,
    required this.totalBilled,
    required this.outstandingAmount,
    required this.redeemableValue,
  });

  final Customer customer;
  final int pointsBalance;
  final int lifetimeEarned;
  final int lifetimeRedeemed;
  final double totalBilled;
  final double outstandingAmount;
  final double redeemableValue;
}

class LoyaltyAwardRow {
  const LoyaltyAwardRow({
    required this.invoice,
    required this.customerName,
    required this.pointsEarned,
  });

  final Invoice invoice;
  final String customerName;
  final int pointsEarned;
}

LoyaltyReport buildLoyaltyReport({
  required List<Customer> customers,
  required List<Invoice> invoices,
  required double pointValue,
}) {
  final activeCustomers = customers
      .where((customer) => customer.isActive)
      .toList();
  final rows =
      activeCustomers.map((customer) {
        return LoyaltyCustomerRow(
          customer: customer,
          pointsBalance: customer.loyaltyPointsBalance,
          lifetimeEarned: customer.lifetimePointsEarned,
          lifetimeRedeemed: customer.lifetimePointsRedeemed,
          totalBilled: customer.totalBilled,
          outstandingAmount: customer.outstandingAmount,
          redeemableValue: customer.loyaltyPointsBalance * pointValue,
        );
      }).toList()..sort((a, b) {
        final byPoints = b.pointsBalance.compareTo(a.pointsBalance);
        if (byPoints != 0) return byPoints;
        return a.customer.name.toLowerCase().compareTo(
          b.customer.name.toLowerCase(),
        );
      });

  final customerNamesById = {
    for (final customer in activeCustomers) customer.id: customer.name,
  };
  final awards =
      invoices
          .where(
            (invoice) =>
                invoice.loyaltyPointsAwarded && invoice.pointsEarned > 0,
          )
          .map((invoice) {
            final snapshotName =
                invoice.customerSnapshot['name']?.toString().trim() ?? '';
            return LoyaltyAwardRow(
              invoice: invoice,
              customerName: snapshotName.isNotEmpty
                  ? snapshotName
                  : customerNamesById[invoice.customerId] ?? 'Unknown customer',
              pointsEarned: invoice.pointsEarned,
            );
          })
          .toList()
        ..sort(
          (a, b) => b.invoice.invoiceDate.compareTo(a.invoice.invoiceDate),
        );

  final pointsOutstanding = rows.fold<int>(
    0,
    (total, row) => total + row.pointsBalance,
  );
  return LoyaltyReport(
    customers: rows,
    recentAwards: awards.take(20).toList(),
    totalCustomers: activeCustomers.length,
    activeMembers: rows.where((row) => row.customer.loyaltyEnabled).length,
    pointsOutstanding: pointsOutstanding,
    lifetimePointsEarned: rows.fold<int>(
      0,
      (total, row) => total + row.lifetimeEarned,
    ),
    lifetimePointsRedeemed: rows.fold<int>(
      0,
      (total, row) => total + row.lifetimeRedeemed,
    ),
    outstandingValue: pointsOutstanding * pointValue,
  );
}

List<LoyaltyCustomerRow> filterLoyaltyCustomers(
  List<LoyaltyCustomerRow> customers,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return customers;
  return customers.where((row) {
    final customer = row.customer;
    return customer.name.toLowerCase().contains(normalized) ||
        customer.phone.toLowerCase().contains(normalized) ||
        customer.email.toLowerCase().contains(normalized) ||
        customer.gstin.toLowerCase().contains(normalized) ||
        row.pointsBalance.toString().contains(normalized);
  }).toList();
}
