import '../../domain/entities/invoice.dart';

List<String> buildBulkInvoicePdfFileNames(Iterable<Invoice> invoices) {
  final usedCounts = <String, int>{};
  return [
    for (final invoice in invoices)
      _nextUniquePdfFileName(
        sanitizeInvoicePdfBaseName(invoice.invoiceNumber),
        usedCounts,
      ),
  ];
}

String sanitizeInvoicePdfBaseName(String value) {
  final sanitized = value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .trim()
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return sanitized.isEmpty ? 'invoice' : sanitized;
}

String _nextUniquePdfFileName(String baseName, Map<String, int> usedCounts) {
  final nextCount = (usedCounts[baseName] ?? 0) + 1;
  usedCounts[baseName] = nextCount;
  return nextCount == 1 ? '$baseName.pdf' : '$baseName ($nextCount).pdf';
}
