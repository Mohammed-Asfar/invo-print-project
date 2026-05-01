import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/product_service.dart';
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

class _ProductsView extends StatelessWidget {
  const _ProductsView();

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
                TextField(
                  onChanged: context.read<ProductCubit>().search,
                  decoration: const InputDecoration(
                    labelText: 'Search products and services',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: state.status == ProductStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : _ProductGrid(products: state.filteredProducts),
                ),
              ],
            ),
          ),
        );
      },
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
              _Metric(label: 'GST', value: '${product.gstRate}%'),
              const SizedBox(width: AppSpacing.lg),
              _Metric(label: 'Unit', value: product.unit),
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
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

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
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
  final _unit = TextEditingController();
  final _rate = TextEditingController();
  final _hsnSac = TextEditingController();
  final _gstRate = TextEditingController();
  ProductServiceType _type = ProductServiceType.service;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product == null) {
      _unit.text = 'service';
      _rate.text = '0';
      _gstRate.text = '0';
      return;
    }
    _name.text = product.name;
    _description.text = product.description;
    _type = product.type;
    _unit.text = product.unit;
    _rate.text = product.defaultRate.toString();
    _hsnSac.text = product.hsnSac;
    _gstRate.text = product.gstRate.toString();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _unit,
      _rate,
      _hsnSac,
      _gstRate,
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
                _DialogField(_unit, 'Unit', required: true),
                _DialogField(_rate, 'Default Rate', numeric: true),
                _DialogField(_gstRate, 'GST Rate %', numeric: true),
                _DialogField(_hsnSac, 'HSN/SAC'),
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
        unit: _unit.text.trim(),
        defaultRate: _doubleValue(_rate),
        hsnSac: _hsnSac.text.trim(),
        gstRate: _doubleValue(_gstRate),
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
