import '../../../products/domain/entities/purchase_entry.dart';
import '../../../products/domain/entities/supplier.dart';

class SupplierPayablesReport {
  const SupplierPayablesReport({
    required this.rows,
    required this.supplierCount,
    required this.billCount,
    required this.openBillCount,
    required this.unpaidBillCount,
    required this.partialBillCount,
    required this.totalPurchased,
    required this.totalPaid,
    required this.totalOutstanding,
  });

  final List<SupplierPayablesRow> rows;
  final int supplierCount;
  final int billCount;
  final int openBillCount;
  final int unpaidBillCount;
  final int partialBillCount;
  final double totalPurchased;
  final double totalPaid;
  final double totalOutstanding;
}

class SupplierPayablesRow {
  const SupplierPayablesRow({
    required this.supplierId,
    required this.supplierName,
    required this.billCount,
    required this.openBillCount,
    required this.totalPurchased,
    required this.totalPaid,
    required this.outstandingBalance,
    required this.lastPurchaseDate,
  });

  final String supplierId;
  final String supplierName;
  final int billCount;
  final int openBillCount;
  final double totalPurchased;
  final double totalPaid;
  final double outstandingBalance;
  final DateTime? lastPurchaseDate;
}

SupplierPayablesReport buildSupplierPayablesReport({
  required Iterable<PurchaseEntry> purchaseEntries,
  required Iterable<Supplier> suppliers,
}) {
  final supplierNamesById = {
    for (final supplier in suppliers.where((supplier) => supplier.isActive))
      supplier.id: supplier.name.trim(),
  };
  final supplierIdsByName = {
    for (final supplier in suppliers.where((supplier) => supplier.isActive))
      supplier.name.trim().toLowerCase(): supplier.id,
  };
  final activeEntries = purchaseEntries
      .where((entry) => entry.isActive)
      .toList();
  final grouped = <String, List<PurchaseEntry>>{};

  for (final entry in activeEntries) {
    final supplierKey = entry.supplierId.isNotEmpty
        ? entry.supplierId
        : supplierIdsByName[entry.supplierName.trim().toLowerCase()] ??
              entry.supplierName.trim().toLowerCase();
    grouped.putIfAbsent(supplierKey, () => []).add(entry);
  }

  final rows =
      grouped.entries.map((group) {
        final entries = group.value
          ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
        final representative = entries.first;
        final supplierName = representative.supplierId.isNotEmpty
            ? (supplierNamesById[representative.supplierId]
                          ?.trim()
                          .isNotEmpty ??
                      false)
                  ? supplierNamesById[representative.supplierId]!.trim()
                  : representative.supplierName.trim()
            : representative.supplierName.trim();
        final totalPurchased = _money(
          entries.fold<double>(0, (sum, entry) => sum + entry.totalAmount),
        );
        final totalPaid = _money(
          entries.fold<double>(0, (sum, entry) => sum + entry.amountPaid),
        );
        final outstanding = _money(
          entries.fold<double>(0, (sum, entry) => sum + entry.balanceDue),
        );
        final openBillCount = entries
            .where((entry) => entry.balanceDue > 0)
            .length;
        return SupplierPayablesRow(
          supplierId: representative.supplierId,
          supplierName: supplierName,
          billCount: entries.length,
          openBillCount: openBillCount,
          totalPurchased: totalPurchased,
          totalPaid: totalPaid,
          outstandingBalance: outstanding,
          lastPurchaseDate: entries.first.purchaseDate,
        );
      }).toList()..sort((a, b) {
        final balanceCompare = b.outstandingBalance.compareTo(
          a.outstandingBalance,
        );
        if (balanceCompare != 0) return balanceCompare;
        return a.supplierName.toLowerCase().compareTo(
          b.supplierName.toLowerCase(),
        );
      });

  return SupplierPayablesReport(
    rows: rows,
    supplierCount: rows.length,
    billCount: activeEntries.length,
    openBillCount: activeEntries.where((entry) => entry.balanceDue > 0).length,
    unpaidBillCount: activeEntries
        .where((entry) => entry.status == PurchasePaymentStatus.unpaid)
        .length,
    partialBillCount: activeEntries
        .where((entry) => entry.status == PurchasePaymentStatus.partial)
        .length,
    totalPurchased: _money(
      activeEntries.fold<double>(0, (sum, entry) => sum + entry.totalAmount),
    ),
    totalPaid: _money(
      activeEntries.fold<double>(0, (sum, entry) => sum + entry.amountPaid),
    ),
    totalOutstanding: _money(
      activeEntries.fold<double>(0, (sum, entry) => sum + entry.balanceDue),
    ),
  );
}

String buildSupplierPayablesCsv(SupplierPayablesReport report) {
  final rows = [
    [
      'Supplier',
      'Bills',
      'Open Bills',
      'Total Purchased',
      'Total Paid',
      'Outstanding',
      'Last Purchase Date',
    ],
    for (final row in report.rows)
      [
        row.supplierName,
        row.billCount.toString(),
        row.openBillCount.toString(),
        _formatMoney(row.totalPurchased),
        _formatMoney(row.totalPaid),
        _formatMoney(row.outstandingBalance),
        row.lastPurchaseDate == null ? '' : _formatDate(row.lastPurchaseDate!),
      ],
    [],
    ['Summary'],
    ['Suppliers', report.supplierCount.toString()],
    ['Bills', report.billCount.toString()],
    ['Open Bills', report.openBillCount.toString()],
    ['Unpaid Bills', report.unpaidBillCount.toString()],
    ['Partial Bills', report.partialBillCount.toString()],
    ['Total Purchased', _formatMoney(report.totalPurchased)],
    ['Total Paid', _formatMoney(report.totalPaid)],
    ['Total Outstanding', _formatMoney(report.totalOutstanding)],
  ];

  return rows
      .map((row) => row.map((cell) => _csvCell(cell.toString())).join(','))
      .join('\n');
}

String _csvCell(String value) {
  if (!value.contains(',') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatMoney(double value) => value.toStringAsFixed(2);

double _money(double value) => double.parse(value.toStringAsFixed(2));
