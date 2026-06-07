import 'package:flutter_test/flutter_test.dart';
import 'package:invo_print/features/customers/domain/entities/customer.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice.dart';
import 'package:invo_print/features/invoices/domain/entities/invoice_item.dart';
import 'package:invo_print/features/products/domain/entities/product_service.dart';
import 'package:invo_print/features/reports/domain/services/customer_aging_report.dart';
import 'package:invo_print/features/reports/domain/services/gst_summary_report.dart';
import 'package:invo_print/features/reports/domain/services/inventory_valuation_report.dart';
import 'package:invo_print/features/reports/domain/services/profit_margin_report.dart';

void main() {
  group('buildCustomerAgingReport', () {
    test('summarizes customer receivables by aging bucket', () {
      final customer = _customer(id: 'cust_1', name: 'TBS Enterprises');
      final report = buildCustomerAgingReport(
        customers: [customer],
        invoices: [
          _invoice(
            id: 'current',
            customerId: customer.id,
            balanceDue: 100,
            dueDate: DateTime(2026, 7, 1),
          ),
          _invoice(
            id: 'd30',
            customerId: customer.id,
            balanceDue: 200,
            dueDate: DateTime(2026, 6, 1),
          ),
          _invoice(
            id: 'd60',
            customerId: customer.id,
            balanceDue: 300,
            dueDate: DateTime(2026, 5, 1),
          ),
          _invoice(
            id: 'd90',
            customerId: customer.id,
            balanceDue: 400,
            dueDate: DateTime(2026, 4, 1),
          ),
          _invoice(
            id: 'd90_plus',
            customerId: customer.id,
            balanceDue: 500,
            dueDate: DateTime(2026, 3, 1),
          ),
        ],
        asOfDate: DateTime(2026, 6, 30),
      );

      final row = report.rows.single;
      expect(report.customerCount, 1);
      expect(report.openInvoiceCount, 5);
      expect(report.totalOutstanding, 1500);
      expect(row.currentAmount, 100);
      expect(row.days0To30Amount, 200);
      expect(row.days31To60Amount, 300);
      expect(row.days61To90Amount, 400);
      expect(row.days90PlusAmount, 500);
      expect(row.oldestOverdueDays, 121);
    });
  });

  group('buildInventoryValuationReport', () {
    test('values only active tracked products and flags low stock', () {
      final report = buildInventoryValuationReport(
        products: [
          _product(
            id: 'prod_1',
            name: 'Printer',
            stockQuantity: 3,
            costPrice: 5000,
            reorderLevel: 5,
          ),
          _product(
            id: 'prod_2',
            name: 'Cable',
            stockQuantity: 10,
            costPrice: 50,
            reorderLevel: 2,
          ),
          _product(
            id: 'svc_1',
            name: 'Installation',
            trackInventory: false,
            stockQuantity: 100,
            costPrice: 100,
          ),
        ],
      );

      expect(report.productCount, 2);
      expect(report.lowStockCount, 1);
      expect(report.totalQuantity, 13);
      expect(report.totalValue, 15500);
      expect(report.restockValue, 10000);
      expect(report.rows.first.name, 'Printer');
    });
  });

  group('buildProfitMarginReport', () {
    test('uses product costs and reports unknown-cost lines', () {
      final report = buildProfitMarginReport(
        products: [_product(id: 'prod_1', name: 'Printer', costPrice: 6000)],
        invoices: [
          _invoice(
            id: 'inv_1',
            items: [
              _item(
                productId: 'prod_1',
                name: 'Printer',
                quantity: 2,
                taxableAmount: 16000,
              ),
              _item(
                productId: '',
                name: 'Setup',
                quantity: 1,
                taxableAmount: 2000,
              ),
            ],
          ),
        ],
      );

      expect(report.invoiceCount, 1);
      expect(report.lineCount, 2);
      expect(report.unknownCostLineCount, 1);
      expect(report.totalRevenue, 18000);
      expect(report.totalCost, 12000);
      expect(report.grossProfit, 6000);
      expect(report.marginPercent, 33.33);
    });
  });

  group('buildGstSummaryReport', () {
    test('groups GST by tax mode and GST rate', () {
      final report = buildGstSummaryReport(
        invoices: [
          _invoice(
            id: 'cgst',
            taxMode: TaxMode.cgstSgst,
            taxableAmount: 1000,
            cgstAmount: 90,
            sgstAmount: 90,
            items: [
              _item(
                name: 'Printer',
                gstRate: 18,
                taxableAmount: 1000,
                cgstAmount: 90,
                sgstAmount: 90,
              ),
            ],
          ),
          _invoice(
            id: 'igst',
            taxMode: TaxMode.igst,
            taxableAmount: 2000,
            cgstAmount: 0,
            sgstAmount: 0,
            igstAmount: 360,
            items: [
              _item(
                name: 'Monitor',
                gstRate: 18,
                taxableAmount: 2000,
                igstAmount: 360,
              ),
            ],
          ),
          _invoice(id: 'draft', status: InvoiceStatus.draft),
        ],
      );

      expect(report.invoiceCount, 2);
      expect(report.taxableTotal, 3000);
      expect(report.cgstTotal, 90);
      expect(report.sgstTotal, 90);
      expect(report.igstTotal, 360);
      expect(report.gstTotal, 540);
      expect(report.rows.map((row) => row.taxMode), [
        TaxMode.cgstSgst,
        TaxMode.igst,
      ]);
      expect(report.rateRows.single.gstRate, 18);
      expect(report.rateRows.single.taxableAmount, 3000);
    });
  });
}

Customer _customer({required String id, required String name}) {
  final now = DateTime(2026, 6, 1);
  return Customer(
    id: id,
    name: name,
    phone: '9655246269',
    email: 'customer@test.com',
    billingAddress: 'Billing address',
    shippingAddress: '',
    gstin: '',
    state: 'Tamil Nadu',
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
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

ProductService _product({
  required String id,
  required String name,
  bool trackInventory = true,
  double stockQuantity = 0,
  double costPrice = 0,
  double reorderLevel = 0,
}) {
  final now = DateTime(2026, 6, 1);
  return ProductService(
    id: id,
    name: name,
    description: '',
    type: trackInventory
        ? ProductServiceType.product
        : ProductServiceType.service,
    sku: '',
    unit: trackInventory ? 'pcs' : 'service',
    defaultRate: 0,
    hsnSac: '',
    gstRate: 18,
    trackInventory: trackInventory,
    costPrice: costPrice,
    stockQuantity: stockQuantity,
    reorderLevel: reorderLevel,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Invoice _invoice({
  String id = 'one',
  String customerId = 'cust_1',
  DateTime? dueDate,
  InvoiceStatus status = InvoiceStatus.unpaid,
  TaxMode taxMode = TaxMode.cgstSgst,
  double balanceDue = 1180,
  double taxableAmount = 1000,
  double cgstAmount = 90,
  double sgstAmount = 90,
  double igstAmount = 0,
  List<InvoiceItem>? items,
}) {
  final date = DateTime(2026, 6, 2);
  final lineItems =
      items ??
      [
        _item(
          name: 'Service',
          taxableAmount: taxableAmount,
          cgstAmount: cgstAmount,
          sgstAmount: sgstAmount,
          igstAmount: igstAmount,
        ),
      ];
  final grandTotal = taxableAmount + cgstAmount + sgstAmount + igstAmount;
  return Invoice(
    id: id,
    invoiceNumber: 'INV-$id',
    invoiceSequence: 1,
    financialYear: '2026-27',
    invoiceDate: date,
    dueDate: dueDate ?? date.add(const Duration(days: 15)),
    customerId: customerId,
    customerSnapshot: const {'name': 'TBS Enterprises', 'phone': '9655246269'},
    companySnapshot: const {'businessName': 'CompanyTest'},
    items: lineItems,
    taxMode: taxMode,
    status: status,
    subtotal: taxableAmount,
    discountType: 'none',
    discountValue: 0,
    discountTotal: 0,
    extraCharges: const [],
    extraChargeTotal: 0,
    taxableAmount: taxableAmount,
    cgstAmount: cgstAmount,
    sgstAmount: sgstAmount,
    igstAmount: igstAmount,
    roundOffEnabled: false,
    roundOffAmount: 0,
    grandTotal: grandTotal,
    amountPaid: 0,
    balanceDue: balanceDue,
    creditTotal: 0,
    notes: '',
    terms: '',
    paymentHistory: const [],
    creditNotes: const [],
    loyaltyPointsAwarded: false,
    pointsEarned: 0,
    createdAt: date,
    updatedAt: date,
  );
}

InvoiceItem _item({
  String productId = '',
  String name = 'Item',
  double quantity = 1,
  double rate = 1000,
  double taxableAmount = 1000,
  double gstRate = 18,
  double cgstAmount = 0,
  double sgstAmount = 0,
  double igstAmount = 0,
}) {
  return InvoiceItem.empty().copyWith(
    productId: productId,
    name: name,
    quantity: quantity,
    rate: rate,
    gstRate: gstRate,
    taxableAmount: taxableAmount,
    cgstAmount: cgstAmount,
    sgstAmount: sgstAmount,
    igstAmount: igstAmount,
    total: taxableAmount + cgstAmount + sgstAmount + igstAmount,
  );
}
