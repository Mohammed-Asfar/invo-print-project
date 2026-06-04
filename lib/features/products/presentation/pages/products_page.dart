import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/product_inventory_entry.dart';
import '../../domain/entities/product_service.dart';
import '../../domain/services/inventory_activity_report.dart';
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
                    length: 2,
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
                DataColumn(label: Text('Reason')),
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
                              : row.entry.reference,
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
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool numeric;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxLines > 1 ? 680 : 330,
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

class _StockAdjustmentDialog extends StatefulWidget {
  const _StockAdjustmentDialog({required this.product});

  final ProductService product;

  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  _StockAdjustmentMode _mode = _StockAdjustmentMode.add;
  String _reason = _stockAdjustmentReasons.first;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust Stock: ${widget.product.name}'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
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
                  setState(() => _mode = value);
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
              const SizedBox(height: AppSpacing.md),
              _DialogField(_note, 'Note', maxLines: 3),
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
    context.read<ProductCubit>().adjustStock(
      widget.product,
      quantityDelta: quantityDelta,
      reason: _reason,
      note: _note.text.trim(),
    );
    Navigator.of(context).pop();
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
