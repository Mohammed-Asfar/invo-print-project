import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';
import 'package:invo_print/features/dashboard/domain/services/dashboard_report.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';
import 'package:invo_print/features/products/domain/entities/purchase_entry.dart';
import 'package:invo_print/features/quotations/domain/entities/quotation.dart';

void main() {
  group('buildDashboardReport', () {
    test('summarizes live business metrics and attention items', () {
      final today = DateTime(2026, 6, 7);
      final report = buildDashboardReport(
        today: today,
        invoices: [
          _invoice(
            id: 'inv_overdue',
            invoiceNumber: 'INV-001',
            dueDate: DateTime(2026, 6, 1),
            grandTotal: 1180,
            amountPaid: 180,
            balanceDue: 1000,
          ),
          _invoice(
            id: 'inv_paid',
            invoiceNumber: 'INV-002',
            status: InvoiceStatus.paid,
            dueDate: DateTime(2026, 6, 20),
            grandTotal: 500,
            amountPaid: 500,
            balanceDue: 0,
          ),
          _invoice(
            id: 'inv_draft',
            invoiceNumber: 'DRAFT',
            status: InvoiceStatus.draft,
            grandTotal: 9999,
            balanceDue: 9999,
          ),
        ],
        quotations: [
          _quotation(id: 'quo_sent', grandTotal: 2500),
          _quotation(
            id: 'quo_accepted',
            status: QuotationStatus.accepted,
            grandTotal: 1000,
          ),
          _quotation(
            id: 'quo_rejected',
            status: QuotationStatus.rejected,
            grandTotal: 9999,
          ),
        ],
        customers: [
          _customer(id: 'cust_1'),
          _customer(id: 'archived', active: false),
        ],
        products: [
          _product(name: 'Thermal Printer', stock: 1, reorder: 5),
          _product(id: 'prod_ok', name: 'Paper Roll', stock: 10, reorder: 5),
        ],
        purchaseEntries: [
          _purchase(
            id: 'pur_overdue',
            dueDate: DateTime(2026, 6, 1),
            totalAmount: 700,
            amountPaid: 200,
          ),
          _purchase(
            id: 'pur_paid',
            dueDate: DateTime(2026, 6, 1),
            totalAmount: 300,
            amountPaid: 300,
          ),
        ],
      );

      expect(report.invoiceCount, 2);
      expect(report.totalInvoiced, 1680);
      expect(report.totalPaid, 680);
      expect(report.outstandingAmount, 1000);
      expect(report.overdueInvoiceCount, 1);
      expect(report.overdueInvoiceAmount, 1000);
      expect(report.quotationCount, 2);
      expect(report.pendingQuotationCount, 1);
      expect(report.pendingQuotationValue, 2500);
      expect(report.customerCount, 1);
      expect(report.lowStockCount, 1);
      expect(report.purchasePayableAmount, 500);
      expect(report.overduePurchaseCount, 1);
      expect(report.recentInvoices.map((invoice) => invoice.invoiceNumber), [
        'INV-001',
        'INV-002',
      ]);
      expect(
        report.attentionItems.map((item) => item.title),
        containsAll([
          'Overdue invoice INV-001',
          'Thermal Printer is low stock',
          'Supplier bill overdue',
          'Quotation QUO-001 pending',
        ]),
      );
    });

    test('excludes paid zero-balance invoices from overdue attention', () {
      final report = buildDashboardReport(
        today: DateTime(2026, 6, 7),
        invoices: [
          _invoice(
            id: 'paid',
            status: InvoiceStatus.paid,
            dueDate: DateTime(2026, 6, 1),
            balanceDue: 0,
          ),
        ],
        quotations: const [],
        customers: const [],
        products: const [],
        purchaseEntries: const [],
      );

      expect(report.overdueInvoiceCount, 0);
      expect(report.attentionItems, isEmpty);
    });
  });
}

Customer _customer({required String id, bool active = true}) {
  final now = DateTime(2026, 6, 1);
  return Customer(
    id: id,
    name: 'TBS Enterprises',
    phone: '',
    email: '',
    billingAddress: '',
    shippingAddress: '',
    gstin: '',
    state: '',
    defaultDiscountType: 'none',
    defaultDiscountValue: 0,
    loyaltyEnabled: true,
    loyaltyPointsBalance: 0,
    lifetimePointsEarned: 0,
    lifetimePointsRedeemed: 0,
    totalBilled: 0,
    totalPaid: 0,
    outstandingAmount: 0,
    notes: '',
    defaultInvoiceTerms: '',
    isActive: active,
    createdAt: now,
    updatedAt: now,
  );
}

Invoice _invoice({
  required String id,
  String invoiceNumber = 'INV-001',
  InvoiceStatus status = InvoiceStatus.unpaid,
  DateTime? invoiceDate,
  DateTime? dueDate,
  double grandTotal = 1180,
  double amountPaid = 0,
  double balanceDue = 1180,
}) {
  final date = invoiceDate ?? DateTime(2026, 6, 2);
  return Invoice(
    id: id,
    invoiceNumber: invoiceNumber,
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: date,
    dueDate: dueDate ?? date.add(const Duration(days: 15)),
    customerId: 'cust_1',
    customerSnapshot: const {'name': 'TBS Enterprises'},
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: [InvoiceItem.empty()],
    taxMode: TaxMode.none,
    status: status,
    subtotal: grandTotal,
    discountType: 'none',
    discountValue: 0,
    discountTotal: 0,
    extraCharges: const [],
    extraChargeTotal: 0,
    taxableAmount: grandTotal,
    cgstAmount: 0,
    sgstAmount: 0,
    igstAmount: 0,
    roundOffEnabled: false,
    roundOffAmount: 0,
    grandTotal: grandTotal,
    amountPaid: amountPaid,
    balanceDue: balanceDue,
    notes: '',
    terms: '',
    paymentHistory: const [],
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: date,
    updatedAt: date,
  );
}

Quotation _quotation({
  required String id,
  QuotationStatus status = QuotationStatus.sent,
  double grandTotal = 2500,
}) {
  final now = DateTime(2026, 6, 2);
  return Quotation(
    id: id,
    quotationNumber: 'QUO-001',
    quotationSequence: 1,
    financialYear: '2026-27',
    quotationDate: now,
    validUntil: now.add(const Duration(days: 15)),
    customerId: 'cust_1',
    customerSnapshot: const {'name': 'TBS Enterprises'},
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: [InvoiceItem.empty()],
    taxMode: TaxMode.none,
    status: status,
    subtotal: grandTotal,
    discountType: 'none',
    discountValue: 0,
    discountTotal: 0,
    extraCharges: const [],
    extraChargeTotal: 0,
    taxableAmount: grandTotal,
    cgstAmount: 0,
    sgstAmount: 0,
    igstAmount: 0,
    roundOffEnabled: false,
    roundOffAmount: 0,
    grandTotal: grandTotal,
    notes: '',
    terms: '',
    createdAt: now,
    updatedAt: now,
  );
}

ProductService _product({
  String id = 'prod_1',
  required String name,
  required double stock,
  required double reorder,
}) {
  final now = DateTime(2026, 6, 1);
  return ProductService(
    id: id,
    name: name,
    description: '',
    type: ProductServiceType.product,
    sku: '',
    unit: 'pcs',
    defaultRate: 100,
    hsnSac: '',
    gstRate: 18,
    trackInventory: true,
    costPrice: 50,
    stockQuantity: stock,
    reorderLevel: reorder,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

PurchaseEntry _purchase({
  required String id,
  required DateTime dueDate,
  required double totalAmount,
  required double amountPaid,
}) {
  final now = DateTime(2026, 6, 1);
  return PurchaseEntry(
    id: id,
    entryNumber: 'PUR-001',
    supplierId: 'sup_1',
    supplierName: 'ABC Supplier',
    billReference: '',
    purchaseDate: now,
    dueDate: dueDate,
    items: const [],
    notes: '',
    totalAmount: totalAmount,
    amountPaid: amountPaid,
    paymentHistory: const [],
    status: amountPaid >= totalAmount
        ? PurchasePaymentStatus.paid
        : PurchasePaymentStatus.partial,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}
