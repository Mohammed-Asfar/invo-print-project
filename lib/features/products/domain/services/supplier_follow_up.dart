import '../entities/purchase_entry.dart';
import '../entities/supplier.dart';

class SupplierFollowUpQueue {
  const SupplierFollowUpQueue({
    required this.rows,
    required this.actionCount,
    required this.overdueSupplierCount,
    required this.reminderDueCount,
    required this.totalOverdueAmount,
  });

  final List<SupplierFollowUpRow> rows;
  final int actionCount;
  final int overdueSupplierCount;
  final int reminderDueCount;
  final double totalOverdueAmount;
}

String buildSupplierFollowUpCsv(SupplierFollowUpQueue queue) {
  final rows = [
    [
      'Supplier',
      'Status',
      'Outstanding',
      'Overdue Amount',
      'Overdue Bills',
      'Reminder Due',
      'Last Purchase',
      'Last Contacted',
      'Next Follow-up',
      'Follow-up Notes',
    ],
    for (final row in queue.rows)
      [
        row.supplier.name,
        row.supplier.followUpStatus.label,
        _money(row.outstandingBalance).toStringAsFixed(2),
        _money(row.overdueAmount).toStringAsFixed(2),
        row.overdueBillCount.toString(),
        row.reminderDue ? 'Yes' : 'No',
        row.lastPurchaseDate == null ? '' : _date(row.lastPurchaseDate!),
        row.supplier.lastContactedAt == null
            ? ''
            : _date(row.supplier.lastContactedAt!),
        row.supplier.nextFollowUpDate == null
            ? ''
            : _date(row.supplier.nextFollowUpDate!),
        row.supplier.followUpNotes,
      ],
    [],
    ['Summary'],
    ['Action Queue', queue.actionCount.toString()],
    ['Overdue Suppliers', queue.overdueSupplierCount.toString()],
    ['Reminders Due', queue.reminderDueCount.toString()],
    ['Overdue Amount', _money(queue.totalOverdueAmount).toStringAsFixed(2)],
  ];

  return rows
      .map((row) => row.map((cell) => _csvCell(cell.toString())).join(','))
      .join('\n');
}

class SupplierFollowUpRow {
  const SupplierFollowUpRow({
    required this.supplier,
    required this.outstandingBalance,
    required this.overdueAmount,
    required this.overdueBillCount,
    required this.lastPurchaseDate,
    required this.reminderDue,
    required this.needsAction,
  });

  final Supplier supplier;
  final double outstandingBalance;
  final double overdueAmount;
  final int overdueBillCount;
  final DateTime? lastPurchaseDate;
  final bool reminderDue;
  final bool needsAction;
}

SupplierFollowUpQueue buildSupplierFollowUpQueue({
  required Iterable<Supplier> suppliers,
  required Iterable<PurchaseEntry> purchaseEntries,
  DateTime? today,
}) {
  final effectiveToday = _dateOnly(today ?? DateTime.now());
  final activeSuppliers = suppliers.where((supplier) => supplier.isActive);
  final rows = <SupplierFollowUpRow>[];

  for (final supplier in activeSuppliers) {
    final matchingEntries =
        purchaseEntries
            .where((entry) => entry.isActive)
            .where((entry) => _belongsToSupplier(entry, supplier))
            .toList()
          ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

    final outstandingBalance = _money(
      matchingEntries.fold<double>(0, (sum, entry) => sum + entry.balanceDue),
    );
    final overdueEntries = matchingEntries
        .where((entry) => entry.isOverdue(today: effectiveToday))
        .toList();
    final overdueAmount = _money(
      overdueEntries.fold<double>(0, (sum, entry) => sum + entry.balanceDue),
    );
    final reminderDue =
        supplier.nextFollowUpDate != null &&
        !_dateOnly(supplier.nextFollowUpDate!).isAfter(effectiveToday);
    final hasOpenPayables = outstandingBalance > 0;
    final needsAction =
        overdueAmount > 0 ||
        reminderDue ||
        (hasOpenPayables &&
            supplier.followUpStatus == SupplierFollowUpStatus.pending);
    if (!needsAction && !hasOpenPayables) {
      continue;
    }

    rows.add(
      SupplierFollowUpRow(
        supplier: supplier,
        outstandingBalance: outstandingBalance,
        overdueAmount: overdueAmount,
        overdueBillCount: overdueEntries.length,
        lastPurchaseDate: matchingEntries.isEmpty
            ? null
            : matchingEntries.first.purchaseDate,
        reminderDue: reminderDue,
        needsAction: needsAction,
      ),
    );
  }

  rows.sort((a, b) {
    if (a.needsAction != b.needsAction) {
      return a.needsAction ? -1 : 1;
    }
    if (a.reminderDue != b.reminderDue) {
      return a.reminderDue ? -1 : 1;
    }
    final overdueCompare = b.overdueAmount.compareTo(a.overdueAmount);
    if (overdueCompare != 0) return overdueCompare;
    final outstandingCompare = b.outstandingBalance.compareTo(
      a.outstandingBalance,
    );
    if (outstandingCompare != 0) return outstandingCompare;
    return a.supplier.name.toLowerCase().compareTo(
      b.supplier.name.toLowerCase(),
    );
  });

  return SupplierFollowUpQueue(
    rows: rows,
    actionCount: rows.where((row) => row.needsAction).length,
    overdueSupplierCount: rows.where((row) => row.overdueAmount > 0).length,
    reminderDueCount: rows.where((row) => row.reminderDue).length,
    totalOverdueAmount: _money(
      rows.fold<double>(0, (sum, row) => sum + row.overdueAmount),
    ),
  );
}

bool _belongsToSupplier(PurchaseEntry entry, Supplier supplier) {
  if (entry.supplierId.isNotEmpty) {
    return entry.supplierId == supplier.id;
  }
  return entry.supplierName.trim().toLowerCase() ==
      supplier.name.trim().toLowerCase();
}

double _money(double value) => double.parse(value.toStringAsFixed(2));

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _csvCell(String value) {
  if (!value.contains(',') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}
