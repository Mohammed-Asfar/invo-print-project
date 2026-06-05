import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/product_inventory_entry.dart';
import '../../domain/entities/purchase_entry.dart';
import '../../domain/entities/product_service.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/services/inventory_activity_report.dart';
import '../../domain/services/supplier_ledger.dart';
import '../../domain/services/supplier_statement_pdf_service.dart';
import '../../../reports/domain/services/supplier_payables_report.dart';
import '../cubit/product_cubit.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  static const routePath = '/products';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductCubit>()..load(),
      child: const _ProductsView(),
    );
  }
}

class _ProductsView extends StatefulWidget {
  const _ProductsView();

  @override
  State<_ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<_ProductsView> {
  String _inventorySearchQuery = '';
  String _selectedInventoryProductId = '';
  ProductInventoryEntryType? _selectedInventoryType;
  String _purchaseSearchQuery = '';
  PurchaseStatusFilter _purchaseStatusFilter = PurchaseStatusFilter.all;
  String _selectedPurchaseSupplierId = '';

  Future<void> _exportInventoryCsv(ProductState state) async {
    final report = buildInventoryActivityReport(
      products: state.products,
      entries: state.inventoryEntries,
      productId: _selectedInventoryProductId,
      type: _selectedInventoryType,
      searchQuery: _inventorySearchQuery,
    );
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save inventory activity CSV',
      fileName: 'inventory-activity.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (!mounted || path == null) return;
    await File(
      path,
    ).writeAsString(buildInventoryActivityCsv(report), flush: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Inventory activity exported.'),
          backgroundColor: AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductCubit, ProductState>(
      listener: (context, state) {
        if (state.status == ProductStatus.failure ||
            state.status == ProductStatus.saved) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message ?? 'Done'),
                backgroundColor: state.status == ProductStatus.failure
                    ? AppColors.error
                    : AppColors.success,
              ),
            );
        }
      },
      builder: (context, state) {
        return ColoredBox(
          color: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductsHeader(state: state),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: DefaultTabController(
                    length: 4,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const TabBar(
                            tabs: [
                              Tab(text: 'Catalog'),
                              Tab(text: 'Inventory'),
                              Tab(text: 'Suppliers'),
                              Tab(text: 'Purchases'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Expanded(
                          child: state.status == ProductStatus.loading
                              ? const Center(child: CircularProgressIndicator())
                              : TabBarView(
                                  children: [
                                    _CatalogTab(state: state),
                                    _InventoryTab(
                                      state: state,
                                      searchQuery: _inventorySearchQuery,
                                      selectedProductId:
                                          _selectedInventoryProductId,
                                      selectedType: _selectedInventoryType,
                                      onSearchChanged: (value) {
                                        setState(
                                          () => _inventorySearchQuery = value,
                                        );
                                      },
                                      onProductChanged: (value) {
                                        setState(
                                          () => _selectedInventoryProductId =
                                              value,
                                        );
                                      },
                                      onTypeChanged: (value) {
                                        setState(
                                          () => _selectedInventoryType = value,
                                        );
                                      },
                                      onExport: state.inventoryEntries.isEmpty
                                          ? null
                                          : () => _exportInventoryCsv(state),
                                    ),
                                    _SuppliersTab(state: state),
                                    _PurchasesTab(
                                      state: state,
                                      searchQuery: _purchaseSearchQuery,
                                      statusFilter: _purchaseStatusFilter,
                                      selectedSupplierId:
                                          _selectedPurchaseSupplierId,
                                      onSearchChanged: (value) {
                                        setState(
                                          () => _purchaseSearchQuery = value,
                                        );
                                        context
                                            .read<ProductCubit>()
                                            .searchPurchases(value);
                                      },
                                      onStatusChanged: (value) {
                                        setState(
                                          () => _purchaseStatusFilter = value,
                                        );
                                        context
                                            .read<ProductCubit>()
                                            .setPurchaseStatusFilter(value);
                                      },
                                      onSupplierChanged: (value) {
                                        setState(
                                          () => _selectedPurchaseSupplierId =
                                              value,
                                        );
                                        context
                                            .read<ProductCubit>()
                                            .setPurchaseSupplierFilter(value);
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CatalogTab extends StatelessWidget {
  const _CatalogTab({required this.state});

  final ProductState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: context.read<ProductCubit>().search,
          decoration: const InputDecoration(
            labelText: 'Search products and services',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(child: _ProductGrid(products: state.filteredProducts)),
      ],
    );
  }
}

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({
    required this.state,
    required this.searchQuery,
    required this.selectedProductId,
    required this.selectedType,
    required this.onSearchChanged,
    required this.onProductChanged,
    required this.onTypeChanged,
    required this.onExport,
  });

  final ProductState state;
  final String searchQuery;
  final String selectedProductId;
  final ProductInventoryEntryType? selectedType;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onProductChanged;
  final ValueChanged<ProductInventoryEntryType?> onTypeChanged;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final trackedProducts =
        state.products.where((product) => product.trackInventory).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final report = buildInventoryActivityReport(
      products: state.products,
      entries: state.inventoryEntries,
      productId: selectedProductId,
      type: selectedType,
      searchQuery: searchQuery,
    );
    final lowStockProducts =
        trackedProducts.where((product) => product.isLowStock).toList()
          ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

    return Column(
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export CSV'),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Search movements',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: selectedProductId,
                decoration: const InputDecoration(
                  labelText: 'Product',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('All tracked products'),
                  ),
                  for (final product in trackedProducts)
                    DropdownMenuItem<String>(
                      value: product.id,
                      child: Text(product.name),
                    ),
                ],
                onChanged: (value) => onProductChanged(value ?? ''),
              ),
            ),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<ProductInventoryEntryType?>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Movement Type',
                  prefixIcon: Icon(Icons.compare_arrows_outlined),
                ),
                items: [
                  const DropdownMenuItem<ProductInventoryEntryType?>(
                    child: Text('All movement types'),
                  ),
                  for (final type in ProductInventoryEntryType.values)
                    DropdownMenuItem<ProductInventoryEntryType?>(
                      value: type,
                      child: Text(type.label),
                    ),
                ],
                onChanged: onTypeChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _InventoryMetrics(report: report),
        if (report.reasonBreakdown.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _InventoryReasonPanel(reasonBreakdown: report.reasonBreakdown),
        ],
        if (lowStockProducts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _LowStockPanel(products: lowStockProducts),
        ],
        const SizedBox(height: AppSpacing.lg),
        Expanded(child: _InventoryActivityTable(rows: report.rows)),
      ],
    );
  }
}

class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab({required this.state});

  final ProductState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: context.read<ProductCubit>().searchSuppliers,
                decoration: const InputDecoration(
                  labelText: 'Search suppliers',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => _showSupplierDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Supplier'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(child: _SupplierTable(suppliers: state.filteredSuppliers)),
      ],
    );
  }

  void _showSupplierDialog(BuildContext context, {Supplier? supplier}) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductCubit>(),
        child: _SupplierDialog(supplier: supplier),
      ),
    );
  }
}

class _PurchasesTab extends StatelessWidget {
  const _PurchasesTab({
    required this.state,
    required this.searchQuery,
    required this.statusFilter,
    required this.selectedSupplierId,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onSupplierChanged,
  });

  final ProductState state;
  final String searchQuery;
  final PurchaseStatusFilter statusFilter;
  final String selectedSupplierId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PurchaseStatusFilter> onStatusChanged;
  final ValueChanged<String> onSupplierChanged;

  @override
  Widget build(BuildContext context) {
    final suppliers = [...state.suppliers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Column(
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Search purchase entries',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<PurchaseStatusFilter>(
                initialValue: statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Bill Status',
                  prefixIcon: Icon(Icons.filter_list_outlined),
                ),
                items: [
                  for (final value in PurchaseStatusFilter.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) onStatusChanged(value);
                },
              ),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: selectedSupplierId,
                decoration: const InputDecoration(
                  labelText: 'Supplier',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('All suppliers'),
                  ),
                  for (final supplier in suppliers)
                    DropdownMenuItem<String>(
                      value: supplier.id,
                      child: Text(supplier.name),
                    ),
                ],
                onChanged: (value) => onSupplierChanged(value ?? ''),
              ),
            ),
            ElevatedButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => _showPurchaseDialog(context, state),
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('New Purchase'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _PurchasePayablesSummary(state: state),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: _PurchaseEntryTable(entries: state.filteredPurchaseEntries),
        ),
      ],
    );
  }

  void _showPurchaseDialog(BuildContext context, ProductState state) {
    _openPurchaseDialog(context, state);
  }

  void _openPurchaseDialog(
    BuildContext context,
    ProductState state, {
    PurchaseEntry? existingEntry,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductCubit>(),
        child: _PurchaseEntryDialog(
          suppliers: state.suppliers,
          products: state.products
              .where((product) => product.trackInventory)
              .toList(),
          existingCount: state.purchaseEntries.length,
          existingEntry: existingEntry,
        ),
      ),
    );
  }
}

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader({required this.state});

  final ProductState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products & Services',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Create optional item shortcuts. Invoices can still use manual line items anytime.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: state.isBusy ? null : () => _showProductDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New Item'),
          ),
        ],
      ),
    );
  }

  void _showProductDialog(BuildContext context, {ProductService? product}) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductCubit>(),
        child: _ProductDialog(product: product),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<ProductService> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Text(
          'No products or services yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 430,
        mainAxisExtent: 194,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductCard(product: product);
      },
    );
  }
}

class _SupplierTable extends StatelessWidget {
  const _SupplierTable({required this.suppliers});

  final List<Supplier> suppliers;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      return Center(
        child: Text(
          'No suppliers yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        itemCount: suppliers.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, thickness: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final supplier = suppliers[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                supplier.name.isEmpty ? '?' : supplier.name[0].toUpperCase(),
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(supplier.name),
            subtitle: Text(
              [
                if (supplier.phone.isNotEmpty) supplier.phone,
                if (supplier.email.isNotEmpty) supplier.email,
                if (supplier.gstin.isNotEmpty) 'GSTIN ${supplier.gstin}',
              ].join('  |  '),
            ),
            trailing: Wrap(
              spacing: AppSpacing.sm,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _showSupplierDialog(context, supplier),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Ledger',
                  onPressed: () => _showSupplierLedger(context, supplier),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                IconButton(
                  tooltip: 'Archive',
                  onPressed: () =>
                      context.read<ProductCubit>().archiveSupplier(supplier),
                  icon: const Icon(Icons.archive_outlined),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSupplierDialog(BuildContext context, Supplier supplier) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductCubit>(),
        child: _SupplierDialog(supplier: supplier),
      ),
    );
  }

  void _showSupplierLedger(BuildContext context, Supplier supplier) {
    final cubit = context.read<ProductCubit>();
    final ledger = cubit.supplierLedgerFor(supplier);
    final payablesRows = buildSupplierPayablesReport(
      purchaseEntries: cubit.state.purchaseEntries,
      suppliers: cubit.state.suppliers,
    ).rows;
    SupplierPayablesRow? payablesRow;
    for (final row in payablesRows) {
      if (row.supplierId == supplier.id ||
          row.supplierName.trim().toLowerCase() ==
              supplier.name.trim().toLowerCase()) {
        payablesRow = row;
        break;
      }
    }
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _SupplierLedgerDialog(ledger: ledger, payablesRow: payablesRow),
      ),
    );
  }
}

class _PurchaseEntryTable extends StatelessWidget {
  const _PurchaseEntryTable({required this.entries});

  final List<PurchaseEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No purchase entries yet.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, thickness: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final overdue = isPurchaseOverdue(entry);
          return ListTile(
            title: Text(entry.entryNumber),
            subtitle: Text(
              [
                entry.supplierName,
                if (entry.billReference.isNotEmpty)
                  'Bill ${entry.billReference}',
                '${entry.items.length} item${entry.items.length == 1 ? '' : 's'}',
                if (overdue) 'Overdue by ${entry.daysOverdue()}d',
              ].join('  |  '),
            ),
            leading: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color:
                    (overdue
                            ? AppColors.error
                            : _purchaseStatusColor(entry.status))
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                overdue ? 'Overdue' : entry.status.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: overdue
                      ? AppColors.error
                      : _purchaseStatusColor(entry.status),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMoney(entry.totalAmount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Due ${_formatDateOnly(entry.effectiveDueDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: overdue ? AppColors.error : AppColors.textSecondary,
                    fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                Text(
                  'Due ${_formatMoney(entry.balanceDue)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: entry.balanceDue > 0
                        ? (overdue ? AppColors.error : AppColors.warning)
                        : AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            onTap: () => _showPurchaseDetailDialog(context, entry),
          );
        },
      ),
    );
  }

  void _showPurchaseDetailDialog(BuildContext context, PurchaseEntry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductCubit>(),
        child: _PurchaseEntryDetailDialog(entry: entry),
      ),
    );
  }
}

class _PurchasePayablesSummary extends StatelessWidget {
  const _PurchasePayablesSummary({required this.state});

  final ProductState state;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 96,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _InventoryMetricCard(
          icon: Icons.receipt_long_outlined,
          label: 'Open Bills',
          value: state.openPurchaseCount.toString(),
          valueColor: state.openPurchaseCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _InventoryMetricCard(
          icon: Icons.hourglass_empty_outlined,
          label: 'Unpaid',
          value: state.unpaidPurchaseCount.toString(),
          valueColor: state.unpaidPurchaseCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _InventoryMetricCard(
          icon: Icons.published_with_changes_outlined,
          label: 'Partial',
          value: state.partialPurchaseCount.toString(),
          valueColor: state.partialPurchaseCount > 0
              ? AppColors.primaryPurple
              : AppColors.textPrimary,
        ),
        _InventoryMetricCard(
          icon: Icons.error_outline,
          label: 'Overdue Bills',
          value: state.overduePurchaseCount.toString(),
          valueColor: state.overduePurchaseCount > 0
              ? AppColors.error
              : AppColors.textPrimary,
        ),
        _InventoryMetricCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Outstanding',
          value: _formatMoney(state.totalPurchaseOutstanding),
          valueColor: state.totalPurchaseOutstanding > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final ProductService product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  product.type.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => _showProductDialog(context, product: product),
                icon: const Icon(Icons.edit_outlined),
              ),
              if (product.trackInventory) ...[
                IconButton(
                  tooltip: 'Adjust stock',
                  onPressed: () => _showAdjustStockDialog(context, product),
                  icon: const Icon(Icons.tune_outlined),
                ),
                IconButton(
                  tooltip: 'History',
                  onPressed: () => _showHistoryDialog(context, product),
                  icon: const Icon(Icons.history),
                ),
              ],
              IconButton(
                tooltip: 'Archive',
                onPressed: () => context.read<ProductCubit>().archive(product),
                icon: const Icon(Icons.archive_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            product.description.isEmpty
                ? 'No description'
                : product.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Row(
            children: [
              _Metric(label: 'Rate', value: product.defaultRate.toString()),
              const SizedBox(width: AppSpacing.lg),
              _Metric(
                label: product.trackInventory ? 'Cost' : 'GST',
                value: product.trackInventory
                    ? product.costPrice.toStringAsFixed(2)
                    : '${product.gstRate}%',
              ),
              const SizedBox(width: AppSpacing.lg),
              _Metric(
                label: product.trackInventory ? 'Stock' : 'Unit',
                value: product.trackInventory
                    ? _stockLabel(product)
                    : product.unit,
                highlight: product.isLowStock,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProductDialog(
    BuildContext context, {
    required ProductService product,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductCubit>(),
        child: _ProductDialog(product: product),
      ),
    );
  }

  void _showAdjustStockDialog(BuildContext context, ProductService product) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductCubit>(),
        child: _StockAdjustmentDialog(product: product),
      ),
    );
  }

  void _showHistoryDialog(BuildContext context, ProductService product) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductCubit>(),
        child: _InventoryHistoryDialog(product: product),
      ),
    );
  }

  String _stockLabel(ProductService product) {
    final quantity = product.stockQuantity.toStringAsFixed(
      product.stockQuantity.truncateToDouble() == product.stockQuantity ? 0 : 2,
    );
    return '$quantity ${product.unit}';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: highlight ? AppColors.warning : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryMetrics extends StatelessWidget {
  const _InventoryMetrics({required this.report});

  final InventoryActivityReport report;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 104,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [
        _InventoryMetricCard(
          icon: Icons.inventory_outlined,
          label: 'Tracked Products',
          value: report.trackedProductCount.toString(),
        ),
        _InventoryMetricCard(
          icon: Icons.warning_amber_outlined,
          label: 'Low Stock',
          value: report.lowStockCount.toString(),
          valueColor: report.lowStockCount > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
        _InventoryMetricCard(
          icon: Icons.swap_vert_circle_outlined,
          label: 'Movements',
          value: report.movementCount.toString(),
        ),
        _InventoryMetricCard(
          icon: Icons.tune_outlined,
          label: 'Manual Adjustments',
          value: report.manualAdjustmentCount.toString(),
        ),
        _InventoryMetricCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Inventory Value',
          value: report.totalStockValue.toStringAsFixed(2),
        ),
        _InventoryMetricCard(
          icon: Icons.local_shipping_outlined,
          label: 'Restock Qty',
          value: report.totalRecommendedRestockQuantity.toStringAsFixed(2),
          valueColor: report.totalRecommendedRestockQuantity > 0
              ? AppColors.warning
              : AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _InventoryMetricCard extends StatelessWidget {
  const _InventoryMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryReasonPanel extends StatelessWidget {
  const _InventoryReasonPanel({required this.reasonBreakdown});

  final List<InventoryReasonSummary> reasonBreakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Movement Reasons',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final summary in reasonBreakdown.take(8))
                Container(
                  width: 220,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${summary.count} movement${summary.count == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Net ${summary.netQuantityDelta > 0 ? '+' : ''}${_formatQuantity(summary.netQuantityDelta)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: summary.netQuantityDelta >= 0
                              ? AppColors.success
                              : AppColors.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LowStockPanel extends StatelessWidget {
  const _LowStockPanel({required this.products});

  final List<ProductService> products;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Needs Attention',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final product in products)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${product.name}  •  ${_formatQuantity(product.stockQuantity)} ${product.unit}  •  Restock ${_formatQuantity(product.recommendedRestockQuantity)} ${product.unit}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryActivityTable extends StatelessWidget {
  const _InventoryActivityTable({required this.rows});

  final List<InventoryActivityRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'No stock movements match these filters.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(AppColors.surfaceSoft),
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Reference')),
                DataColumn(label: Text('Supplier')),
                DataColumn(label: Text('Reason')),
                DataColumn(numeric: true, label: Text('Unit Cost')),
                DataColumn(numeric: true, label: Text('Total Cost')),
                DataColumn(numeric: true, label: Text('Delta')),
                DataColumn(numeric: true, label: Text('Balance')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(_formatDateTime(row.entry.createdAt))),
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.productName),
                            if (row.sku.isNotEmpty)
                              Text(
                                row.sku,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      DataCell(Text(row.entry.type.label)),
                      DataCell(
                        Text(
                          row.entry.reference.isEmpty
                              ? '—'
                              : [
                                  row.entry.reference,
                                  if (row.entry.secondaryReference.isNotEmpty)
                                    row.entry.secondaryReference,
                                ].join('\n'),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.entry.supplierName.isEmpty
                              ? '—'
                              : row.entry.supplierName,
                        ),
                      ),
                      DataCell(
                        Text(
                          row.entry.reason.isNotEmpty
                              ? row.entry.reason
                              : (row.entry.note.isNotEmpty
                                    ? row.entry.note
                                    : '—'),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.entry.unitCost > 0
                              ? _formatMoney(row.entry.unitCost)
                              : '—',
                        ),
                      ),
                      DataCell(
                        Text(
                          row.entry.totalCost > 0
                              ? _formatMoney(row.entry.totalCost)
                              : '—',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${row.entry.isIncrease ? '+' : ''}${_formatQuantity(row.entry.quantityDelta)}',
                          style: TextStyle(
                            color: row.entry.isIncrease
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${_formatQuantity(row.entry.balanceAfter)}${row.unit.isEmpty ? '' : ' ${row.unit}'}',
                          style: TextStyle(
                            color: row.isLowStock
                                ? AppColors.warning
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});

  final ProductService? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _sku = TextEditingController();
  final _unit = TextEditingController();
  final _rate = TextEditingController();
  final _hsnSac = TextEditingController();
  final _gstRate = TextEditingController();
  final _costPrice = TextEditingController();
  final _stockQuantity = TextEditingController();
  final _reorderLevel = TextEditingController();
  ProductServiceType _type = ProductServiceType.service;
  bool _trackInventory = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) {
      _unit.text = 'service';
      _rate.text = '0';
      _gstRate.text = '0';
      _costPrice.text = '0';
      return;
    }
    _name.text = product.name;
    _description.text = product.description;
    _type = product.type;
    _sku.text = product.sku;
    _unit.text = product.unit;
    _rate.text = product.defaultRate.toString();
    _hsnSac.text = product.hsnSac;
    _gstRate.text = product.gstRate.toString();
    _trackInventory = product.trackInventory;
    _costPrice.text = product.costPrice.toString();
    _stockQuantity.text = product.stockQuantity.toString();
    _reorderLevel.text = product.reorderLevel.toString();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _sku,
      _unit,
      _rate,
      _hsnSac,
      _gstRate,
      _costPrice,
      _stockQuantity,
      _reorderLevel,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'New Product/Service' : 'Edit Item'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: [
                SizedBox(
                  width: 330,
                  child: DropdownButtonFormField<ProductServiceType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: ProductServiceType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _type = value;
                        if (_unit.text.trim().isEmpty ||
                            _unit.text.trim() == 'service') {
                          _unit.text = value == ProductServiceType.product
                              ? 'pcs'
                              : 'service';
                        }
                      });
                    },
                  ),
                ),
                _DialogField(_name, 'Name', required: true),
                _DialogField(_sku, 'SKU'),
                _DialogField(_unit, 'Unit', required: true),
                _DialogField(_rate, 'Default Rate', numeric: true),
                _DialogField(_gstRate, 'GST Rate %', numeric: true),
                _DialogField(_hsnSac, 'HSN/SAC'),
                SizedBox(
                  width: 680,
                  child: SwitchListTile(
                    value: _trackInventory,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Track inventory'),
                    subtitle: const Text(
                      'Enable only for physical items where stock matters.',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _trackInventory = value;
                        if (value && _type == ProductServiceType.service) {
                          _type = ProductServiceType.product;
                        }
                      });
                    },
                  ),
                ),
                if (_trackInventory) ...[
                  _DialogField(_costPrice, 'Cost Price', numeric: true),
                  _DialogField(_stockQuantity, 'Current Stock', numeric: true),
                  _DialogField(_reorderLevel, 'Reorder Level', numeric: true),
                ],
                _DialogField(_description, 'Description', maxLines: 3),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.product ?? ProductService.empty();
    context.read<ProductCubit>().save(
      ProductService(
        id: existing.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        type: _type,
        sku: _sku.text.trim(),
        unit: _unit.text.trim(),
        defaultRate: _doubleValue(_rate),
        hsnSac: _hsnSac.text.trim(),
        gstRate: _doubleValue(_gstRate),
        trackInventory: _trackInventory,
        costPrice: _trackInventory ? _doubleValue(_costPrice) : 0,
        stockQuantity: _trackInventory ? _doubleValue(_stockQuantity) : 0,
        reorderLevel: _trackInventory ? _doubleValue(_reorderLevel) : 0,
        isActive: true,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
  }

  double _doubleValue(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField(
    this.controller,
    this.label, {
    this.required = false,
    this.numeric = false,
    this.maxLines = 1,
    this.width,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool numeric;
  final int maxLines;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? (maxLines > 1 ? 680 : 330),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return '$label is required';
          if (numeric && text.isNotEmpty && double.tryParse(text) == null) {
            return 'Enter a valid number';
          }
          return null;
        },
      ),
    );
  }
}

class _PurchaseEntryDialog extends StatefulWidget {
  const _PurchaseEntryDialog({
    required this.suppliers,
    required this.products,
    required this.existingCount,
    this.existingEntry,
  });

  final List<Supplier> suppliers;
  final List<ProductService> products;
  final int existingCount;
  final PurchaseEntry? existingEntry;

  @override
  State<_PurchaseEntryDialog> createState() => _PurchaseEntryDialogState();
}

class _PurchaseEntryDialogState extends State<_PurchaseEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _entryNumber = TextEditingController();
  final _billReference = TextEditingController();
  final _supplierName = TextEditingController();
  final _notes = TextEditingController();
  final List<_PurchaseItemDraft> _items = [_PurchaseItemDraft()];
  DateTime _purchaseDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  String _supplierId = '';

  @override
  void initState() {
    super.initState();
    final existingEntry = widget.existingEntry;
    if (existingEntry != null) {
      _items.first.dispose();
      _entryNumber.text = existingEntry.entryNumber;
      _billReference.text = existingEntry.billReference;
      _supplierName.text = existingEntry.supplierName;
      _notes.text = existingEntry.notes;
      _purchaseDate = existingEntry.purchaseDate;
      _dueDate = existingEntry.dueDate ?? existingEntry.purchaseDate;
      _supplierId = existingEntry.supplierId;
      _items
        ..clear()
        ..addAll(
          existingEntry.items.map((item) {
            ProductService? product;
            for (final candidate in widget.products) {
              if (candidate.id == item.productId) {
                product = candidate;
                break;
              }
            }
            return _PurchaseItemDraft.fromEntryItem(item, product: product);
          }),
        );
      if (_items.isEmpty) {
        _items.add(_PurchaseItemDraft());
      }
      return;
    }

    final seq = (widget.existingCount + 1).toString().padLeft(3, '0');
    _entryNumber.text =
        'PUR-${_purchaseDate.year}${_purchaseDate.month.toString().padLeft(2, '0')}-$seq';
  }

  @override
  void dispose() {
    _entryNumber.dispose();
    _billReference.dispose();
    _supplierName.dispose();
    _notes.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = [...widget.suppliers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final products = [...widget.products]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return AlertDialog(
      title: Text(
        widget.existingEntry == null
            ? 'New Purchase Entry'
            : 'Edit Purchase Bill',
      ),
      content: SizedBox(
        width: 920,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    _DialogField(
                      _entryNumber,
                      'Purchase Entry No.',
                      required: true,
                    ),
                    _DialogField(_billReference, 'Supplier Bill Ref.'),
                    SizedBox(
                      width: 330,
                      child: DropdownButtonFormField<String>(
                        initialValue: _supplierId.isEmpty ? '' : _supplierId,
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
                          prefixIcon: Icon(Icons.local_shipping_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Manual supplier entry'),
                          ),
                          ...suppliers.map(
                            (supplier) => DropdownMenuItem<String>(
                              value: supplier.id,
                              child: Text(supplier.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          final supplierId = value ?? '';
                          Supplier? supplier;
                          for (final item in suppliers) {
                            if (item.id == supplierId) {
                              supplier = item;
                              break;
                            }
                          }
                          setState(() {
                            _supplierId = supplierId;
                            _supplierName.text = supplier?.name ?? '';
                          });
                        },
                      ),
                    ),
                    _DialogField(
                      _supplierName,
                      'Supplier Name',
                      required: true,
                    ),
                    InkWell(
                      onTap: _pickPurchaseDate,
                      child: SizedBox(
                        width: 330,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Purchase Date',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(_formatDateOnly(_purchaseDate)),
                              ),
                              const Icon(Icons.edit_calendar_outlined),
                            ],
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _pickDueDate,
                      child: SizedBox(
                        width: 330,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Due Date',
                            prefixIcon: Icon(Icons.event_available_outlined),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(_formatDateOnly(_dueDate))),
                              const Icon(Icons.edit_calendar_outlined),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _items.add(_PurchaseItemDraft()));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (var index = 0; index < _items.length; index++) ...[
                  _PurchaseItemEditor(
                    key: ValueKey('purchase-item-$index'),
                    draft: _items[index],
                    products: products,
                    canRemove: _items.length > 1,
                    onRemove: () {
                      setState(() {
                        _items[index].dispose();
                        _items.removeAt(index);
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _DialogField(_notes, 'Notes', maxLines: 3),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: Text(
            widget.existingEntry == null ? 'Save Purchase' : 'Update Purchase',
          ),
        ),
      ],
    );
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _purchaseDate = picked;
      if (_dueDate.isBefore(_purchaseDate)) {
        _dueDate = _purchaseDate;
      }
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(_purchaseDate) ? _purchaseDate : _dueDate,
      firstDate: _purchaseDate,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final items = <PurchaseEntryItem>[];
    for (final draft in _items) {
      final product = draft.product;
      final quantity = double.tryParse(draft.quantity.text.trim()) ?? 0;
      final unitCost = double.tryParse(draft.unitCost.text.trim()) ?? 0;
      if (product == null || quantity <= 0 || unitCost < 0) {
        continue;
      }
      items.add(
        PurchaseEntryItem(
          productId: product.id,
          productName: product.name,
          sku: product.sku,
          unit: product.unit,
          quantity: quantity,
          unitCost: unitCost,
          lineTotal: _roundCurrency(quantity * unitCost),
        ),
      );
    }
    context.read<ProductCubit>().savePurchaseEntry(
      PurchaseEntry(
        id: widget.existingEntry?.id ?? '',
        entryNumber: _entryNumber.text.trim(),
        supplierId: _supplierId,
        supplierName: _supplierName.text.trim(),
        billReference: _billReference.text.trim(),
        purchaseDate: _purchaseDate,
        dueDate: _dueDate,
        items: items,
        notes: _notes.text.trim(),
        totalAmount: _roundCurrency(
          items.fold<double>(0, (sum, item) => sum + item.lineTotal),
        ),
        amountPaid: widget.existingEntry?.amountPaid ?? 0,
        paymentHistory: widget.existingEntry?.paymentHistory ?? const [],
        status: widget.existingEntry?.status ?? PurchasePaymentStatus.unpaid,
        isActive: widget.existingEntry?.isActive ?? true,
        createdAt: widget.existingEntry?.createdAt ?? DateTime.now(),
        updatedAt: widget.existingEntry?.updatedAt ?? DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
  }
}

class _PurchaseItemDraft {
  _PurchaseItemDraft({
    this.product,
    String quantity = '1',
    String unitCost = '0',
  }) : quantity = TextEditingController(text: quantity),
       unitCost = TextEditingController(text: unitCost);

  factory _PurchaseItemDraft.fromEntryItem(
    PurchaseEntryItem item, {
    ProductService? product,
  }) {
    return _PurchaseItemDraft(
      product: product,
      quantity: _formatQuantity(item.quantity),
      unitCost: item.unitCost.toStringAsFixed(2),
    );
  }

  ProductService? product;
  final TextEditingController quantity;
  final TextEditingController unitCost;

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
  }
}

class _PurchaseItemEditor extends StatefulWidget {
  const _PurchaseItemEditor({
    super.key,
    required this.draft,
    required this.products,
    required this.canRemove,
    required this.onRemove,
  });

  final _PurchaseItemDraft draft;
  final List<ProductService> products;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  State<_PurchaseItemEditor> createState() => _PurchaseItemEditorState();
}

class _PurchaseItemEditorState extends State<_PurchaseItemEditor> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<ProductService>(
              initialValue: widget.draft.product,
              decoration: const InputDecoration(
                labelText: 'Product',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              items: widget.products
                  .map(
                    (product) => DropdownMenuItem<ProductService>(
                      value: product,
                      child: Text(product.name),
                    ),
                  )
                  .toList(),
              validator: (value) => value == null ? 'Select product' : null,
              onChanged: (value) {
                setState(() {
                  widget.draft.product = value;
                  if (value != null &&
                      widget.draft.unitCost.text.trim() == '0') {
                    widget.draft.unitCost.text = value.costPrice
                        .toStringAsFixed(2);
                  }
                });
              },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _DialogField(
              widget.draft.quantity,
              'Qty',
              numeric: true,
              required: true,
              width: double.infinity,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _DialogField(
              widget.draft.unitCost,
              'Unit Cost',
              numeric: true,
              required: true,
              width: double.infinity,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: IconButton(
              tooltip: 'Remove item',
              onPressed: widget.canRemove ? widget.onRemove : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseEntryDetailDialog extends StatelessWidget {
  const _PurchaseEntryDetailDialog({required this.entry});

  final PurchaseEntry entry;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(entry.entryNumber),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _PurchaseMetric(label: 'Supplier', value: entry.supplierName),
                  _PurchaseMetric(
                    label: 'Total',
                    value: _formatMoney(entry.totalAmount),
                  ),
                  _PurchaseMetric(
                    label: 'Paid',
                    value: _formatMoney(entry.amountPaid),
                  ),
                  _PurchaseMetric(
                    label: 'Balance',
                    value: _formatMoney(entry.balanceDue),
                    highlight: entry.balanceDue > 0,
                  ),
                  _PurchaseMetric(
                    label: 'Due Date',
                    value: _formatDateOnly(entry.effectiveDueDate),
                    highlight: entry.isOverdue(),
                  ),
                  _PurchaseMetric(
                    label: 'Status',
                    value: entry.isOverdue() ? 'Overdue' : entry.status.label,
                    highlight:
                        entry.status != PurchasePaymentStatus.paid ||
                        entry.isOverdue(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Items',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in entry.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName),
                  subtitle: Text(
                    '${_formatQuantity(item.quantity)} ${item.unit}  •  ${_formatMoney(item.unitCost)} each',
                  ),
                  trailing: Text(
                    _formatMoney(item.lineTotal),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Payment History',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (entry.paymentHistory.isEmpty)
                Text(
                  'No payments recorded yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                for (final indexedPayment
                    in entry.paymentHistory.indexed.toList().reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_formatMoney(indexedPayment.$2.amount)),
                    subtitle: Text(
                      [
                        _formatDateOnly(indexedPayment.$2.paidAt),
                        if (indexedPayment.$2.method.trim().isNotEmpty)
                          indexedPayment.$2.method.trim(),
                        if (indexedPayment.$2.reference.trim().isNotEmpty)
                          indexedPayment.$2.reference.trim(),
                      ].join('  |  '),
                    ),
                    trailing: Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        IconButton(
                          tooltip: 'Edit payment',
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showPurchasePaymentDialog(
                              context,
                              entry,
                              paymentIndex: indexedPayment.$1,
                              payment: indexedPayment.$2,
                            );
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Remove payment',
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await context
                                .read<ProductCubit>()
                                .deletePurchasePayment(
                                  entry,
                                  index: indexedPayment.$1,
                                );
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            _showEditPurchaseDialog(context, entry);
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Bill'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            await context.read<ProductCubit>().voidPurchaseEntry(entry);
          },
          icon: const Icon(Icons.block_outlined),
          label: const Text('Void Bill'),
        ),
        if (entry.balanceDue > 0)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _showPurchasePaymentDialog(context, entry);
            },
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Record Payment'),
          ),
      ],
    );
  }

  void _showPurchasePaymentDialog(
    BuildContext context,
    PurchaseEntry entry, {
    int? paymentIndex,
    PurchasePayment? payment,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ProductCubit>(),
        child: _PurchasePaymentDialog(
          entry: entry,
          paymentIndex: paymentIndex,
          payment: payment,
        ),
      ),
    );
  }

  void _showEditPurchaseDialog(BuildContext context, PurchaseEntry entry) {
    final cubit = context.read<ProductCubit>();
    final state = cubit.state;
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _PurchaseEntryDialog(
          suppliers: state.suppliers,
          products: state.products
              .where((product) => product.trackInventory)
              .toList(),
          existingCount: state.purchaseEntries.length,
          existingEntry: entry,
        ),
      ),
    );
  }
}

class _PurchasePaymentDialog extends StatefulWidget {
  const _PurchasePaymentDialog({
    required this.entry,
    this.paymentIndex,
    this.payment,
  });

  final PurchaseEntry entry;
  final int? paymentIndex;
  final PurchasePayment? payment;

  @override
  State<_PurchasePaymentDialog> createState() => _PurchasePaymentDialogState();
}

class _PurchasePaymentDialogState extends State<_PurchasePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _method = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _paidAt;

  @override
  void initState() {
    super.initState();
    final existingPayment = widget.payment;
    _paidAt = existingPayment?.paidAt ?? DateTime.now();
    _amount.text = (existingPayment?.amount ?? widget.entry.balanceDue)
        .toStringAsFixed(2);
    _method.text = existingPayment?.method ?? '';
    _reference.text = existingPayment?.reference ?? '';
    _notes.text = existingPayment?.notes ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _method.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.payment == null ? 'Record Payment' : 'Edit Payment'} - ${widget.entry.entryNumber}',
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PaymentDialogLine(
                label: 'Purchase Total',
                value: _formatMoney(widget.entry.totalAmount),
              ),
              _PaymentDialogLine(
                label: 'Already Paid',
                value: _formatMoney(widget.entry.amountPaid),
              ),
              _PaymentDialogLine(
                label: 'Balance Due',
                value: _formatMoney(widget.entry.balanceDue),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount *',
                  prefixIcon: Icon(Icons.currency_rupee_outlined),
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                readOnly: true,
                key: ValueKey(_paidAt.toIso8601String()),
                initialValue: _formatDateOnly(_paidAt),
                decoration: const InputDecoration(
                  labelText: 'Payment Date',
                  prefixIcon: Icon(Icons.event_outlined),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _paidAt,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _paidAt = picked);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _method,
                decoration: const InputDecoration(
                  labelText: 'Method',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Reference',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            if (widget.paymentIndex == null) {
              await context.read<ProductCubit>().recordPurchasePayment(
                widget.entry,
                amount: double.tryParse(_amount.text.trim()) ?? 0,
                paidAt: _paidAt,
                method: _method.text.trim(),
                reference: _reference.text.trim(),
                notes: _notes.text.trim(),
              );
            } else {
              await context.read<ProductCubit>().updatePurchasePayment(
                widget.entry,
                index: widget.paymentIndex!,
                amount: double.tryParse(_amount.text.trim()) ?? 0,
                paidAt: _paidAt,
                method: _method.text.trim(),
                reference: _reference.text.trim(),
                notes: _notes.text.trim(),
              );
            }
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.payments_outlined),
          label: Text(
            widget.payment == null ? 'Save Payment' : 'Update Payment',
          ),
        ),
      ],
    );
  }
}

class _SupplierLedgerDialog extends StatelessWidget {
  const _SupplierLedgerDialog({required this.ledger, this.payablesRow});

  final SupplierLedger ledger;
  final SupplierPayablesRow? payablesRow;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${ledger.supplier.name} Ledger'),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _PurchaseMetric(
                    label: 'Purchased',
                    value: _formatMoney(ledger.totalPurchased),
                  ),
                  _PurchaseMetric(
                    label: 'Paid',
                    value: _formatMoney(ledger.totalPaid),
                  ),
                  _PurchaseMetric(
                    label: 'Outstanding',
                    value: _formatMoney(ledger.outstandingBalance),
                    highlight: ledger.outstandingBalance > 0,
                  ),
                  _PurchaseMetric(
                    label: 'Bills',
                    value: ledger.purchaseEntries.length.toString(),
                  ),
                  if (payablesRow != null) ...[
                    _PurchaseMetric(
                      label: 'Overdue Bills',
                      value: payablesRow!.overdueBillCount.toString(),
                      highlight: payablesRow!.overdueBillCount > 0,
                    ),
                    _PurchaseMetric(
                      label: 'Overdue Amount',
                      value: _formatMoney(payablesRow!.overdueAmount),
                      highlight: payablesRow!.overdueAmount > 0,
                    ),
                    _PurchaseMetric(
                      label: '0-30 Days',
                      value: _formatMoney(payablesRow!.currentBucketAmount),
                    ),
                    _PurchaseMetric(
                      label: '31-60 Days',
                      value: _formatMoney(payablesRow!.days31To60BucketAmount),
                    ),
                    _PurchaseMetric(
                      label: '61-90 Days',
                      value: _formatMoney(payablesRow!.days61To90BucketAmount),
                    ),
                    _PurchaseMetric(
                      label: '90+ Days',
                      value: _formatMoney(payablesRow!.days90PlusBucketAmount),
                      highlight: payablesRow!.days90PlusBucketAmount > 0,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Bills',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (ledger.purchaseEntries.isEmpty)
                Text(
                  'No supplier bills yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                for (final entry in ledger.purchaseEntries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.entryNumber),
                    subtitle: Text(
                      [
                        _formatDateOnly(entry.purchaseDate),
                        'Due ${_formatDateOnly(entry.effectiveDueDate)}',
                        if (entry.billReference.trim().isNotEmpty)
                          'Bill ${entry.billReference.trim()}',
                        if (entry.isOverdue())
                          'Overdue by ${entry.daysOverdue()}d',
                        entry.status.label,
                      ].join('  |  '),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatMoney(entry.totalAmount),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Due ${_formatMoney(entry.balanceDue)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: entry.balanceDue > 0
                                    ? (entry.isOverdue()
                                          ? AppColors.error
                                          : AppColors.warning)
                                    : AppColors.success,
                              ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Ledger Timeline',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (ledger.entries.isEmpty)
                Text(
                  'No ledger entries yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                for (final entry in ledger.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.type.label),
                    subtitle: Text(
                      [
                        _formatDateOnly(entry.date),
                        entry.reference,
                        if (entry.description.trim().isNotEmpty)
                          entry.description.trim(),
                      ].join('  |  '),
                    ),
                    trailing: Text(
                      _formatMoney(entry.amount.abs()),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: entry.amount < 0
                            ? AppColors.success
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () => _exportStatement(context),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Export Statement'),
        ),
      ],
    );
  }

  Future<void> _exportStatement(BuildContext context) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save supplier statement PDF',
      fileName:
          '${ledger.supplier.name.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').toLowerCase()}-statement.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (path == null || !context.mounted) return;
    final bytes = await sl<SupplierStatementPdfService>().buildStatementPdf(
      supplier: ledger.supplier,
      ledger: ledger,
      payableRow: payablesRow,
      asOfDate: DateTime.now(),
    );
    await File(path).writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Supplier statement exported.'),
          backgroundColor: AppColors.success,
        ),
      );
  }
}

class _PurchaseMetric extends StatelessWidget {
  const _PurchaseMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryLight : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: highlight
                  ? AppColors.primaryPurple
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDialogLine extends StatelessWidget {
  const _PaymentDialogLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SupplierDialog extends StatefulWidget {
  const _SupplierDialog({this.supplier});

  final Supplier? supplier;

  @override
  State<_SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<_SupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    if (supplier == null) return;
    _name.text = supplier.name;
    _phone.text = supplier.phone;
    _email.text = supplier.email;
    _gstin.text = supplier.gstin;
    _address.text = supplier.address;
    _notes.text = supplier.notes;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _email,
      _gstin,
      _address,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.supplier == null ? 'New Supplier' : 'Edit Supplier'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _DialogField(_name, 'Supplier Name', required: true),
                _DialogField(_phone, 'Phone'),
                _DialogField(_email, 'Email'),
                _DialogField(_gstin, 'GSTIN'),
                _DialogField(_address, 'Address', maxLines: 3),
                _DialogField(_notes, 'Notes', maxLines: 3),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.supplier;
    final now = DateTime.now();
    context.read<ProductCubit>().saveSupplier(
      Supplier(
        id: existing?.id ?? '',
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        gstin: _gstin.text.trim(),
        address: _address.text.trim(),
        notes: _notes.text.trim(),
        isActive: existing?.isActive ?? true,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    Navigator.of(context).pop();
  }
}

class _StockAdjustmentDialog extends StatefulWidget {
  const _StockAdjustmentDialog({required this.product});

  final ProductService product;

  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reference = TextEditingController();
  final _secondaryReference = TextEditingController();
  final _supplierName = TextEditingController();
  final _unitCost = TextEditingController();
  final _note = TextEditingController();
  _StockAdjustmentMode _mode = _StockAdjustmentMode.add;
  String _reason = 'Purchase';
  String _selectedSupplierId = '';
  DateTime _effectiveAt = DateTime.now();
  bool _updateCostPriceFromUnitCost = true;

  bool get _showRestockDetails => _mode == _StockAdjustmentMode.add;

  @override
  void initState() {
    super.initState();
    _reference.text = _buildRestockReference(_effectiveAt);
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reference.dispose();
    _secondaryReference.dispose();
    _supplierName.dispose();
    _unitCost.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = [
      ...context.select((ProductCubit cubit) => cubit.state.suppliers),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return AlertDialog(
      title: Text('Adjust Stock: ${widget.product.name}'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current stock: ${_formatQuantity(widget.product.stockQuantity)} ${widget.product.unit}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<_StockAdjustmentMode>(
                  initialValue: _mode,
                  decoration: const InputDecoration(
                    labelText: 'Adjustment Mode',
                    prefixIcon: Icon(Icons.swap_horiz_outlined),
                  ),
                  items: _StockAdjustmentMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _mode = value;
                      if (value == _StockAdjustmentMode.add) {
                        if (_reference.text.trim().isEmpty) {
                          _reference.text = _buildRestockReference(
                            _effectiveAt,
                          );
                        }
                        if (_reason == 'Damage' ||
                            _reason == 'Correction' ||
                            _reason == 'Physical count') {
                          _reason = 'Purchase';
                        }
                      } else if (value == _StockAdjustmentMode.remove) {
                        if (_reason == 'Purchase' ||
                            _reason == 'Opening stock') {
                          _reason = 'Damage';
                        }
                      } else if (_reason == 'Purchase' ||
                          _reason == 'Damage' ||
                          _reason == 'Return') {
                        _reason = 'Physical count';
                      }
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _DialogField(
                  _quantity,
                  _mode.quantityLabel,
                  numeric: true,
                  required: true,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final reason in _stockAdjustmentReasons)
                      DropdownMenuItem(value: reason, child: Text(reason)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _reason = value);
                  },
                ),
                if (_showRestockDetails) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Restock Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DialogField(_reference, 'Restock Entry No.'),
                  const SizedBox(height: AppSpacing.md),
                  _DialogField(_secondaryReference, 'Bill / Invoice Ref.'),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSupplierId.isEmpty
                        ? null
                        : _selectedSupplierId,
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Manual supplier entry'),
                      ),
                      ...suppliers.map(
                        (supplier) => DropdownMenuItem<String>(
                          value: supplier.id,
                          child: Text(supplier.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      final supplierId = value ?? '';
                      Supplier? supplier;
                      for (final item in suppliers) {
                        if (item.id == supplierId) {
                          supplier = item;
                          break;
                        }
                      }
                      setState(() {
                        _selectedSupplierId = supplierId;
                        if (supplier != null) {
                          _supplierName.text = supplier.name;
                        } else if (supplierId.isEmpty) {
                          _supplierName.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DialogField(_supplierName, 'Supplier Name'),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    onTap: _pickEffectiveDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Inward Stock Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDateOnly(_effectiveAt),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          const Icon(Icons.edit_calendar_outlined),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DialogField(
                    _unitCost,
                    'Landed Cost / Unit Cost',
                    numeric: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    value: _updateCostPriceFromUnitCost,
                    onChanged: (value) {
                      setState(() => _updateCostPriceFromUnitCost = value);
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Update current cost price from this restock',
                    ),
                    subtitle: Text(
                      'Use the landed cost as the product cost for future stock valuation.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _DialogField(_note, 'Note', maxLines: 3),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Apply'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final enteredQuantity = double.tryParse(_quantity.text.trim()) ?? 0;
    final quantityDelta = switch (_mode) {
      _StockAdjustmentMode.add => enteredQuantity,
      _StockAdjustmentMode.remove => -enteredQuantity,
      _StockAdjustmentMode.setExact =>
        enteredQuantity - widget.product.stockQuantity,
    };
    final unitCost = double.tryParse(_unitCost.text.trim()) ?? 0;
    context.read<ProductCubit>().adjustStock(
      widget.product,
      quantityDelta: quantityDelta,
      reason: _reason,
      effectiveAt: _effectiveAt,
      reference: _showRestockDetails ? _reference.text.trim() : '',
      secondaryReference: _showRestockDetails
          ? _secondaryReference.text.trim()
          : '',
      supplierName: _showRestockDetails ? _supplierName.text.trim() : '',
      unitCost: _showRestockDetails ? unitCost : 0,
      updateCostPriceFromUnitCost:
          _showRestockDetails && _updateCostPriceFromUnitCost,
      note: _note.text.trim(),
    );
    Navigator.of(context).pop();
  }

  Future<void> _pickEffectiveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _effectiveAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _effectiveAt.hour,
        _effectiveAt.minute,
      );
      if (_reference.text.trim().isEmpty ||
          _reference.text.trim().startsWith('RST-')) {
        _reference.text = _buildRestockReference(_effectiveAt);
      }
    });
  }

  String _buildRestockReference(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return 'RST-$year$month$day';
  }
}

enum _StockAdjustmentMode {
  add('Add stock', 'Quantity to add'),
  remove('Remove stock', 'Quantity to remove'),
  setExact('Set exact stock', 'New stock balance');

  const _StockAdjustmentMode(this.label, this.quantityLabel);

  final String label;
  final String quantityLabel;
}

const List<String> _stockAdjustmentReasons = [
  'Opening stock',
  'Purchase',
  'Return',
  'Damage',
  'Correction',
  'Physical count',
];

class _InventoryHistoryDialog extends StatelessWidget {
  const _InventoryHistoryDialog({required this.product});

  final ProductService product;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${product.name} History'),
      content: SizedBox(
        width: 760,
        child: FutureBuilder<List<ProductInventoryEntry>>(
          future: context.read<ProductCubit>().loadInventoryEntries(product.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    'No stock activity yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 320,
              child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => Divider(color: AppColors.border),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final deltaColor = entry.isIncrease
                      ? AppColors.success
                      : AppColors.warning;
                  final deltaPrefix = entry.isIncrease ? '+' : '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.type.label),
                    subtitle: Text(
                      [
                        if (entry.reference.isNotEmpty) entry.reference,
                        if (entry.secondaryReference.isNotEmpty)
                          'Bill ${entry.secondaryReference}',
                        if (entry.supplierName.isNotEmpty)
                          'Supplier ${entry.supplierName}',
                        if (entry.reason.isNotEmpty) entry.reason,
                        if (entry.note.isNotEmpty) entry.note,
                        _formatDateTime(entry.createdAt),
                      ].join('  |  '),
                    ),
                    trailing: SizedBox(
                      width: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$deltaPrefix${_formatQuantity(entry.quantityDelta)}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: deltaColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Balance ${_formatQuantity(entry.balanceAfter)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          if (entry.unitCost > 0)
                            Text(
                              'Unit ${_formatMoney(entry.unitCost)}  •  Total ${_formatMoney(entry.totalCost)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

String _formatQuantity(double value) {
  return value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

String _formatDateTime(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _formatDateOnly(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _formatMoney(double value) {
  return value.toStringAsFixed(2);
}

Color _purchaseStatusColor(PurchasePaymentStatus status) {
  return switch (status) {
    PurchasePaymentStatus.unpaid => AppColors.warning,
    PurchasePaymentStatus.partial => AppColors.primaryPurple,
    PurchasePaymentStatus.paid => AppColors.success,
  };
}

double _roundCurrency(double value) {
  return double.parse(value.toStringAsFixed(2));
}
