import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../company/domain/entities/app_settings.dart';
import '../../../company/domain/entities/company_profile.dart';
import '../../../company/presentation/cubit/company_settings_cubit.dart';

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({super.key});

  static const routePath = '/templates';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CompanySettingsCubit>()..load(),
      child: const _TemplatesView(),
    );
  }
}

class _TemplatesView extends StatefulWidget {
  const _TemplatesView();

  @override
  State<_TemplatesView> createState() => _TemplatesViewState();
}

class _TemplatesViewState extends State<_TemplatesView> {
  final _invoiceTerms = TextEditingController();
  final _quotationTerms = TextEditingController();
  final _lineItemUnit = TextEditingController();
  var _showHsn = true;
  var _showStateCode = true;
  var _loaded = false;

  @override
  void dispose() {
    _invoiceTerms.dispose();
    _quotationTerms.dispose();
    _lineItemUnit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CompanySettingsCubit, CompanySettingsState>(
      listener: (context, state) {
        if (state.status == CompanySettingsStatus.loaded && !_loaded) {
          _readState(state.profile, state.settings);
        }
        if (state.status == CompanySettingsStatus.saved ||
            state.status == CompanySettingsStatus.failure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message ?? 'Done'),
                backgroundColor: state.status == CompanySettingsStatus.failure
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
                _TemplatesHeader(
                  isBusy: state.isBusy,
                  onRefresh: () {
                    _loaded = false;
                    context.read<CompanySettingsCubit>().load();
                  },
                  onSave: state.isBusy
                      ? null
                      : () => _save(context, state.profile, state.settings),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child:
                      state.status == CompanySettingsStatus.loading && !_loaded
                      ? const Center(child: CircularProgressIndicator())
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 340,
                              child: _PresetRail(onApply: _applyPreset),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _TemplateSettingsPanel(
                                      showHsn: _showHsn,
                                      showStateCode: _showStateCode,
                                      lineItemUnit: _lineItemUnit,
                                      invoiceTerms: _invoiceTerms,
                                      quotationTerms: _quotationTerms,
                                      onShowHsnChanged: (value) =>
                                          setState(() => _showHsn = value),
                                      onShowStateCodeChanged: (value) =>
                                          setState(
                                            () => _showStateCode = value,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    _TemplatePreview(
                                      profile: state.profile,
                                      showHsn: _showHsn,
                                      showStateCode: _showStateCode,
                                      invoiceTerms: _invoiceTerms.text,
                                      quotationTerms: _quotationTerms.text,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _readState(CompanyProfile profile, AppSettings settings) {
    _invoiceTerms.text = profile.defaultInvoiceTerms;
    _quotationTerms.text = profile.defaultQuotationTerms;
    _lineItemUnit.text = settings.defaultLineItemUnit;
    _showHsn = settings.showLineItemHsn;
    _showStateCode = settings.showCustomerStateCode;
    _loaded = true;
  }

  void _applyPreset(_TemplatePreset preset) {
    setState(() {
      _showHsn = preset.showHsn;
      _showStateCode = preset.showStateCode;
      if (preset.invoiceTerms != null) {
        _invoiceTerms.text = preset.invoiceTerms!;
      }
      if (preset.quotationTerms != null) {
        _quotationTerms.text = preset.quotationTerms!;
      }
    });
  }

  Future<void> _save(
    BuildContext context,
    CompanyProfile profile,
    AppSettings settings,
  ) {
    final lineItemUnit = _lineItemUnit.text.trim().isEmpty
        ? 'service'
        : _lineItemUnit.text.trim();
    return context.read<CompanySettingsCubit>().save(
      profile: profile.copyWith(
        defaultInvoiceTerms: _invoiceTerms.text.trim(),
        defaultQuotationTerms: _quotationTerms.text.trim(),
      ),
      settings: settings.copyWith(
        showLineItemHsn: _showHsn,
        showCustomerStateCode: _showStateCode,
        defaultLineItemUnit: lineItemUnit,
      ),
    );
  }
}

class _TemplatesHeader extends StatelessWidget {
  const _TemplatesHeader({
    required this.isBusy,
    required this.onRefresh,
    required this.onSave,
  });

  final bool isBusy;
  final VoidCallback onRefresh;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
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
              Icons.description_outlined,
              color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Templates',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Control invoice and quotation print defaults, field visibility, and reusable terms.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onRefresh,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Templates'),
          ),
        ],
      ),
    );
  }
}

class _PresetRail extends StatelessWidget {
  const _PresetRail({required this.onApply});

  final ValueChanged<_TemplatePreset> onApply;

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
          Text(
            'Presets',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final preset in _TemplatePreset.values) ...[
            _PresetTile(preset: preset, onApply: () => onApply(preset)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.onApply});

  final _TemplatePreset preset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onApply,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(preset.icon, color: AppColors.primaryPurple),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      preset.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateSettingsPanel extends StatelessWidget {
  const _TemplateSettingsPanel({
    required this.showHsn,
    required this.showStateCode,
    required this.lineItemUnit,
    required this.invoiceTerms,
    required this.quotationTerms,
    required this.onShowHsnChanged,
    required this.onShowStateCodeChanged,
  });

  final bool showHsn;
  final bool showStateCode;
  final TextEditingController lineItemUnit;
  final TextEditingController invoiceTerms;
  final TextEditingController quotationTerms;
  final ValueChanged<bool> onShowHsnChanged;
  final ValueChanged<bool> onShowStateCodeChanged;

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
          _SectionTitle(
            icon: Icons.tune_outlined,
            title: 'Print Defaults',
            subtitle:
                'These values are used by invoices, quotations, and PDFs.',
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: showHsn,
            onChanged: onShowHsnChanged,
            title: const Text('Show HSN/SAC column'),
            subtitle: const Text('Hide it when item HSN is not needed.'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: showStateCode,
            onChanged: onShowStateCodeChanged,
            title: const Text('Show customer state code'),
            subtitle: const Text(
              'Print state code in billing and shipping blocks.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: lineItemUnit,
            decoration: const InputDecoration(
              labelText: 'Default Line Item Unit',
              prefixIcon: Icon(Icons.straighten_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: invoiceTerms,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Invoice Terms',
              prefixIcon: Icon(Icons.receipt_long_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: quotationTerms,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Quotation Terms',
              prefixIcon: Icon(Icons.request_quote_outlined),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({
    required this.profile,
    required this.showHsn,
    required this.showStateCode,
    required this.invoiceTerms,
    required this.quotationTerms,
  });

  final CompanyProfile profile;
  final bool showHsn;
  final bool showStateCode;
  final String invoiceTerms;
  final String quotationTerms;

  @override
  Widget build(BuildContext context) {
    final businessName = profile.businessName.trim().isEmpty
        ? 'Business Name'
        : profile.businessName.trim();
    final address = [
      profile.addressLine1,
      profile.city,
      profile.state,
      profile.pincode,
    ].where((value) => value.trim().isNotEmpty).join(', ');

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
          _SectionTitle(
            icon: Icons.preview_outlined,
            title: 'Document Preview',
            subtitle: 'A compact view of the sections controlled here.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD7DCE5)),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'TAX INVOICE',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD7DCE5)),
                        ),
                        child: const Icon(Icons.image_outlined),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            businessName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          if (address.isNotEmpty) Text(address),
                          if (profile.gstin.trim().isNotEmpty)
                            Text('GSTIN/UIN: ${profile.gstin.trim()}'),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 28, color: Colors.black),
                  Row(
                    children: const [
                      Expanded(child: Text('Invoice No: INV-2026/05-001')),
                      Text('Date: 02 May 2026'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PreviewBlock(
                          title: 'Billed To',
                          lines: [
                            'Name: TBS Enterprises',
                            'Mobile: 9655246269',
                            'State: Tamil Nadu',
                            if (showStateCode) 'State Code: 33',
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: _PreviewBlock(
                          title: 'Shipped To',
                          lines: [
                            'Name: Site Office',
                            'Mobile: 9840012345',
                            'State: Tamil Nadu',
                            if (showStateCode) 'State Code: 33',
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Table(
                    border: TableBorder.all(color: Colors.black),
                    children: [
                      TableRow(
                        children: [
                          const _PreviewCell('Description', strong: true),
                          if (showHsn)
                            const _PreviewCell('HSN/SAC', strong: true),
                          const _PreviewCell('Qty', strong: true),
                          const _PreviewCell('Rate', strong: true),
                          const _PreviewCell('Amount', strong: true),
                        ],
                      ),
                      TableRow(
                        children: [
                          const _PreviewCell('Thermal Invoice Printer'),
                          if (showHsn) const _PreviewCell('8443'),
                          const _PreviewCell('1'),
                          const _PreviewCell('12500.00'),
                          const _PreviewCell('12500.00'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (invoiceTerms.trim().isNotEmpty)
                    Text('Invoice Terms: ${invoiceTerms.trim()}'),
                  if (quotationTerms.trim().isNotEmpty)
                    Text('Quotation Terms: ${quotationTerms.trim()}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        for (final line in lines) Text(line),
      ],
    );
  }
}

class _PreviewCell extends StatelessWidget {
  const _PreviewCell(this.value, {this.strong = false});

  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        value,
        style: TextStyle(
          fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryPurple),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _TemplatePreset {
  taxInvoice(
    title: 'Tax Invoice',
    description: 'GST-ready layout with HSN and state code.',
    icon: Icons.receipt_long_outlined,
    showHsn: true,
    showStateCode: true,
    invoiceTerms: 'Thank you for your business.',
    quotationTerms: 'Quotation validity: 15 days.',
  ),
  simpleBilling(
    title: 'Simple Billing',
    description: 'Cleaner printout for non-GST or small bills.',
    icon: Icons.article_outlined,
    showHsn: false,
    showStateCode: false,
    invoiceTerms: 'Payment due on receipt.',
    quotationTerms: 'Prices are subject to confirmation.',
  ),
  serviceQuote(
    title: 'Service Quote',
    description: 'Useful defaults for estimates and service work.',
    icon: Icons.handyman_outlined,
    showHsn: false,
    showStateCode: true,
    invoiceTerms: null,
    quotationTerms:
        'Quotation validity: 15 days.\nScope changes may revise the final amount.',
  );

  const _TemplatePreset({
    required this.title,
    required this.description,
    required this.icon,
    required this.showHsn,
    required this.showStateCode,
    required this.invoiceTerms,
    required this.quotationTerms,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool showHsn;
  final bool showStateCode;
  final String? invoiceTerms;
  final String? quotationTerms;
}
