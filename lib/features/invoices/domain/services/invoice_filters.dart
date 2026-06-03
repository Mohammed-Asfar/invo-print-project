import '../entities/invoice.dart';

bool matchesInvoiceSearch(Invoice invoice, String query, {DateTime? today}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;

  final customerName =
      invoice.customerSnapshot['name']?.toString().toLowerCase() ?? '';
  if (invoice.invoiceNumber.toLowerCase().contains(normalizedQuery) ||
      customerName.contains(normalizedQuery)) {
    return true;
  }

  final statusTokens = _invoiceStatusTokens(invoice, today: today);
  return statusTokens.contains(normalizedQuery);
}

bool isInvoiceOverdue(Invoice invoice, {DateTime? today}) {
  if (invoice.status == InvoiceStatus.paid ||
      invoice.status == InvoiceStatus.cancelled) {
    return false;
  }
  if (invoice.balanceDue <= 0) return false;
  final compareDay = _dateOnly(today ?? DateTime.now());
  return _dateOnly(invoice.dueDate).isBefore(compareDay);
}

bool isInvoiceFromLastMonth(DateTime value, {DateTime? today}) {
  final compareDay = _dateOnly(today ?? DateTime.now());
  final month = compareDay.month == 1 ? 12 : compareDay.month - 1;
  final year = compareDay.month == 1 ? compareDay.year - 1 : compareDay.year;
  return value.year == year && value.month == month;
}

bool isInvoiceDueThisWeek(Invoice invoice, {DateTime? today}) {
  if (invoice.status == InvoiceStatus.paid ||
      invoice.status == InvoiceStatus.cancelled ||
      invoice.balanceDue <= 0) {
    return false;
  }
  final compareDay = _dateOnly(today ?? DateTime.now());
  final dueDay = _dateOnly(invoice.dueDate);
  return !dueDay.isBefore(compareDay) &&
      !dueDay.isAfter(compareDay.add(const Duration(days: 7)));
}

Set<String> _invoiceStatusTokens(Invoice invoice, {DateTime? today}) {
  final tokens = switch (invoice.status) {
    InvoiceStatus.draft => {'draft'},
    InvoiceStatus.unpaid => {'unpaid'},
    InvoiceStatus.partialPaid => {'partial', 'partial paid'},
    InvoiceStatus.paid => {'paid'},
    InvoiceStatus.cancelled => {'cancelled', 'canceled'},
  };
  if (isInvoiceOverdue(invoice, today: today)) {
    return {...tokens, 'overdue'};
  }
  return tokens;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
