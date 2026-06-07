import '../../../customers/domain/entities/customer.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../products/domain/entities/product_service.dart';
import '../../../products/domain/entities/purchase_entry.dart';
import '../../../quotations/domain/entities/quotation.dart';

class DashboardReport {
  const DashboardReport({
    required this.today,
    required this.invoiceCount,
    required this.totalInvoiced,
    required this.totalPaid,
    required this.outstandingAmount,
    required this.overdueInvoiceCount,
    required this.overdueInvoiceAmount,
    required this.quotationCount,
    required this.pendingQuotationCount,
    required this.pendingQuotationValue,
    required this.customerCount,
    required this.lowStockCount,
    required this.purchasePayableAmount,
    required this.overduePurchaseCount,
    required this.recentInvoices,
    required this.attentionItems,
  });

  final DateTime today;
  final int invoiceCount;
  final double totalInvoiced;
  final double totalPaid;
  final double outstandingAmount;
  final int overdueInvoiceCount;
  final double overdueInvoiceAmount;
  final int quotationCount;
  final int pendingQuotationCount;
  final double pendingQuotationValue;
  final int customerCount;
  final int lowStockCount;
  final double purchasePayableAmount;
  final int overduePurchaseCount;
  final List<Invoice> recentInvoices;
  final List<DashboardAttentionItem> attentionItems;
}

class DashboardAttentionItem {
  const DashboardAttentionItem({
    required this.title,
    required this.subtitle,
    required this.severity,
  });

  final String title;
  final String subtitle;
  final DashboardAttentionSeverity severity;
}

enum DashboardAttentionSeverity { info, warning, danger }

DashboardReport buildDashboardReport({
  required List<Invoice> invoices,
  required List<Quotation> quotations,
  required List<Customer> customers,
  required List<ProductService> products,
  required List<PurchaseEntry> purchaseEntries,
  DateTime? today,
}) {
  final currentDay = _dateOnly(today ?? DateTime.now());
  final activeInvoices = invoices
      .where(
        (invoice) =>
            invoice.status != InvoiceStatus.draft &&
            invoice.status != InvoiceStatus.cancelled,
      )
      .toList();
  final activeQuotations = quotations
      .where(
        (quotation) =>
            quotation.status != QuotationStatus.rejected &&
            quotation.status != QuotationStatus.expired,
      )
      .toList();
  final pendingQuotations = activeQuotations
      .where(
        (quotation) =>
            quotation.status == QuotationStatus.sent ||
            quotation.status == QuotationStatus.draft,
      )
      .toList();
  final activePurchases = purchaseEntries
      .where((entry) => entry.isActive)
      .toList();
  final overdueInvoices = activeInvoices
      .where((invoice) => _isInvoiceOverdue(invoice, currentDay))
      .toList();
  final overduePurchases = activePurchases
      .where((entry) => entry.isOverdue(today: currentDay))
      .toList();
  final lowStockProducts =
      products
          .where((product) => product.isActive && product.isLowStock)
          .toList()
        ..sort((a, b) {
          final restockCompare = b.recommendedRestockQuantity.compareTo(
            a.recommendedRestockQuantity,
          );
          if (restockCompare != 0) return restockCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
  final recentInvoices = [...activeInvoices]
    ..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

  return DashboardReport(
    today: currentDay,
    invoiceCount: activeInvoices.length,
    totalInvoiced: _money(
      activeInvoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.grandTotal,
      ),
    ),
    totalPaid: _money(
      activeInvoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.amountPaid,
      ),
    ),
    outstandingAmount: _money(
      activeInvoices.fold<double>(
        0,
        (sum, invoice) =>
            sum + (invoice.balanceDue > 0 ? invoice.balanceDue : 0),
      ),
    ),
    overdueInvoiceCount: overdueInvoices.length,
    overdueInvoiceAmount: _money(
      overdueInvoices.fold<double>(
        0,
        (sum, invoice) => sum + invoice.balanceDue,
      ),
    ),
    quotationCount: activeQuotations.length,
    pendingQuotationCount: pendingQuotations.length,
    pendingQuotationValue: _money(
      pendingQuotations.fold<double>(
        0,
        (sum, quotation) => sum + quotation.grandTotal,
      ),
    ),
    customerCount: customers.where((customer) => customer.isActive).length,
    lowStockCount: lowStockProducts.length,
    purchasePayableAmount: _money(
      activePurchases.fold<double>(0, (sum, entry) => sum + entry.balanceDue),
    ),
    overduePurchaseCount: overduePurchases.length,
    recentInvoices: recentInvoices.take(5).toList(),
    attentionItems: _attentionItems(
      overdueInvoices: overdueInvoices,
      overduePurchases: overduePurchases,
      lowStockProducts: lowStockProducts,
      pendingQuotations: pendingQuotations,
    ),
  );
}

bool _isInvoiceOverdue(Invoice invoice, DateTime today) {
  if (invoice.balanceDue <= 0) return false;
  if (invoice.status == InvoiceStatus.paid ||
      invoice.status == InvoiceStatus.cancelled ||
      invoice.status == InvoiceStatus.draft) {
    return false;
  }
  return _dateOnly(invoice.dueDate).isBefore(today);
}

List<DashboardAttentionItem> _attentionItems({
  required List<Invoice> overdueInvoices,
  required List<PurchaseEntry> overduePurchases,
  required List<ProductService> lowStockProducts,
  required List<Quotation> pendingQuotations,
}) {
  final items = <DashboardAttentionItem>[];
  for (final invoice in overdueInvoices.take(3)) {
    items.add(
      DashboardAttentionItem(
        title: 'Overdue invoice ${invoice.invoiceNumber}',
        subtitle:
            '${_customerName(invoice.customerSnapshot)} has ${invoice.balanceDue.toStringAsFixed(2)} due',
        severity: DashboardAttentionSeverity.danger,
      ),
    );
  }
  for (final product in lowStockProducts.take(3)) {
    items.add(
      DashboardAttentionItem(
        title: '${product.name} is low stock',
        subtitle:
            '${product.stockQuantity.toStringAsFixed(2)} ${product.unit} left, reorder ${product.recommendedRestockQuantity.toStringAsFixed(2)}',
        severity: DashboardAttentionSeverity.warning,
      ),
    );
  }
  for (final entry in overduePurchases.take(2)) {
    items.add(
      DashboardAttentionItem(
        title: 'Supplier bill overdue',
        subtitle:
            '${entry.supplierName} has ${entry.balanceDue.toStringAsFixed(2)} payable',
        severity: DashboardAttentionSeverity.warning,
      ),
    );
  }
  for (final quotation in pendingQuotations.take(2)) {
    items.add(
      DashboardAttentionItem(
        title: quotation.quotationNumber.trim().isEmpty
            ? 'Draft quotation pending'
            : 'Quotation ${quotation.quotationNumber} pending',
        subtitle:
            '${quotation.customerName.isEmpty ? 'No customer' : quotation.customerName} - ${quotation.grandTotal.toStringAsFixed(2)}',
        severity: DashboardAttentionSeverity.info,
      ),
    );
  }
  return items.take(8).toList();
}

String _customerName(Map<String, dynamic> snapshot) {
  final name = snapshot['name']?.toString().trim() ?? '';
  return name.isEmpty ? 'Customer' : name;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

double _money(double value) => double.parse(value.toStringAsFixed(2));
