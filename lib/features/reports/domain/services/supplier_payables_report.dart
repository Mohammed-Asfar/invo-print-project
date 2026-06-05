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
    required this.currentBucketTotal,
    required this.days31To60BucketTotal,
    required this.days61To90BucketTotal,
    required this.days90PlusBucketTotal,
    required this.asOfDate,
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
  final double currentBucketTotal;
  final double days31To60BucketTotal;
  final double days61To90BucketTotal;
  final double days90PlusBucketTotal;
  final DateTime asOfDate;
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
    required this.currentBucketAmount,
    required this.days31To60BucketAmount,
    required this.days61To90BucketAmount,
    required this.days90PlusBucketAmount,
  });

  final String supplierId;
  final String supplierName;
  final int billCount;
  final int openBillCount;
  final double totalPurchased;
  final double totalPaid;
  final double outstandingBalance;
  final DateTime? lastPurchaseDate;
  final double currentBucketAmount;
  final double days31To60BucketAmount;
  final double days61To90BucketAmount;
  final double days90PlusBucketAmount;
}

SupplierPayablesReport buildSupplierPayablesReport({
  required Iterable<PurchaseEntry> purchaseEntries,
  required Iterable<Supplier> suppliers,
  DateTime? asOfDate,
}) {
  final effectiveAsOfDate = _dateOnly(asOfDate ?? DateTime.now());
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
        var currentBucketAmount = 0.0;
        var days31To60BucketAmount = 0.0;
        var days61To90BucketAmount = 0.0;
        var days90PlusBucketAmount = 0.0;
        for (final entry in entries.where((entry) => entry.balanceDue > 0)) {
          final age = effectiveAsOfDate
              .difference(_dateOnly(entry.purchaseDate))
              .inDays;
          if (age <= 30) {
            currentBucketAmount += entry.balanceDue;
          } else if (age <= 60) {
            days31To60BucketAmount += entry.balanceDue;
          } else if (age <= 90) {
            days61To90BucketAmount += entry.balanceDue;
          } else {
            days90PlusBucketAmount += entry.balanceDue;
          }
        }
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
          currentBucketAmount: _money(currentBucketAmount),
          days31To60BucketAmount: _money(days31To60BucketAmount),
          days61To90BucketAmount: _money(days61To90BucketAmount),
          days90PlusBucketAmount: _money(days90PlusBucketAmount),
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
    currentBucketTotal: _money(
      rows.fold<double>(0, (sum, row) => sum + row.currentBucketAmount),
    ),
    days31To60BucketTotal: _money(
      rows.fold<double>(0, (sum, row) => sum + row.days31To60BucketAmount),
    ),
    days61To90BucketTotal: _money(
      rows.fold<double>(0, (sum, row) => sum + row.days61To90BucketAmount),
    ),
    days90PlusBucketTotal: _money(
      rows.fold<double>(0, (sum, row) => sum + row.days90PlusBucketAmount),
    ),
    asOfDate: effectiveAsOfDate,
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
      '0-30 Days',
      '31-60 Days',
      '61-90 Days',
      '90+ Days',
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
        _formatMoney(row.currentBucketAmount),
        _formatMoney(row.days31To60BucketAmount),
        _formatMoney(row.days61To90BucketAmount),
        _formatMoney(row.days90PlusBucketAmount),
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
    ['0-30 Days', _formatMoney(report.currentBucketTotal)],
    ['31-60 Days', _formatMoney(report.days31To60BucketTotal)],
    ['61-90 Days', _formatMoney(report.days61To90BucketTotal)],
    ['90+ Days', _formatMoney(report.days90PlusBucketTotal)],
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

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
