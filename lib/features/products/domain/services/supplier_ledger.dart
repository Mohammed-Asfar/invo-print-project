import '../entities/purchase_entry.dart';
import '../entities/supplier.dart';

class SupplierLedger {
  const SupplierLedger({
    required this.supplier,
    required this.purchaseEntries,
    required this.entries,
    required this.totalPurchased,
    required this.totalPaid,
    required this.outstandingBalance,
  });

  final Supplier supplier;
  final List<PurchaseEntry> purchaseEntries;
  final List<SupplierLedgerEntry> entries;
  final double totalPurchased;
  final double totalPaid;
  final double outstandingBalance;
}

class SupplierLedgerEntry {
  const SupplierLedgerEntry({
    required this.date,
    required this.type,
    required this.reference,
    required this.amount,
    this.description = '',
  });

  final DateTime date;
  final SupplierLedgerEntryType type;
  final String reference;
  final double amount;
  final String description;
}

enum SupplierLedgerEntryType {
  purchase,
  returnEntry,
  payment;

  String get label => switch (this) {
    SupplierLedgerEntryType.purchase => 'Purchase',
    SupplierLedgerEntryType.returnEntry => 'Return',
    SupplierLedgerEntryType.payment => 'Payment',
  };
}

SupplierLedger buildSupplierLedger({
  required Supplier supplier,
  required Iterable<PurchaseEntry> purchaseEntries,
}) {
  final supplierEntries =
      purchaseEntries
          .where((entry) => _belongsToSupplier(entry, supplier))
          .where((entry) => entry.isActive)
          .toList()
        ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

  final ledgerEntries = <SupplierLedgerEntry>[];
  var totalPurchased = 0.0;
  var totalPaid = 0.0;
  var outstandingBalance = 0.0;

  for (final entry in supplierEntries) {
    totalPurchased += entry.totalAmount;
    totalPaid += entry.amountPaid;
    outstandingBalance += entry.balanceDue;

    ledgerEntries.add(
      SupplierLedgerEntry(
        date: entry.purchaseDate,
        type: SupplierLedgerEntryType.purchase,
        reference: entry.entryNumber,
        amount: entry.totalAmount,
        description: entry.billReference.trim(),
      ),
    );

    for (final supplierReturn in entry.returnHistory) {
      ledgerEntries.add(
        SupplierLedgerEntry(
          date: supplierReturn.returnedAt,
          type: SupplierLedgerEntryType.returnEntry,
          reference: supplierReturn.reference.trim().isNotEmpty
              ? supplierReturn.reference.trim()
              : entry.entryNumber,
          amount: -supplierReturn.totalAmount,
          description: supplierReturn.notes.trim().isNotEmpty
              ? supplierReturn.notes.trim()
              : supplierReturn.reducesPayable
              ? 'Supplier return'
              : 'Supplier return without payable reduction',
        ),
      );
    }

    for (final payment in entry.paymentHistory) {
      ledgerEntries.add(
        SupplierLedgerEntry(
          date: payment.paidAt,
          type: SupplierLedgerEntryType.payment,
          reference: payment.reference.trim().isNotEmpty
              ? payment.reference.trim()
              : entry.entryNumber,
          amount: -payment.amount,
          description: payment.method.trim(),
        ),
      );
    }
  }

  ledgerEntries.sort((a, b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;
    return a.type.index.compareTo(b.type.index);
  });

  return SupplierLedger(
    supplier: supplier,
    purchaseEntries: supplierEntries,
    entries: ledgerEntries,
    totalPurchased: _money(totalPurchased),
    totalPaid: _money(totalPaid),
    outstandingBalance: _money(outstandingBalance),
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
