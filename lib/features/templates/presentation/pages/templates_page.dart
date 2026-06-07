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
  final _invoiceTitle = TextEditingController();
  final _quotationTitle = TextEditingController();
  final _invoiceTerms = TextEditingController();
  final _quotationTerms = TextEditingController();
  final _lineItemUnit = TextEditingController();
  final _customerSignature = TextEditingController();
  final _authorizedSignature = TextEditingController();

  var _selectedTemplate = _TemplatePreset.classicTax.storageValue;
  var _previewType = _PreviewType.invoice;
  var _showHsn = true;
  var _showStateCode = true;
  var _showOriginalCopy = true;
  var _showAmountInWords = true;
  var _showBankDetails = true;
  var _showPaymentQr = true;
  var _showSignatureBlock = true;
  var _loaded = false;

  @override
  void dispose() {
    _invoiceTitle.dispose();
    _quotationTitle.dispose();
    _invoiceTerms.dispose();
    _quotationTerms.dispose();
    _lineItemUnit.dispose();
    _customerSignature.dispose();
    _authorizedSignature.dispose();
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
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 1180;
                            final editor = _TemplateEditor(
                              selectedTemplate: _selectedTemplate,
                              previewType: _previewType,
                              showHsn: _showHsn,
                              showStateCode: _showStateCode,
                              showOriginalCopy: _showOriginalCopy,
                              showAmountInWords: _showAmountInWords,
                              showBankDetails: _showBankDetails,
                              showPaymentQr: _showPaymentQr,
                              showSignatureBlock: _showSignatureBlock,
                              invoiceTitle: _invoiceTitle,
                              quotationTitle: _quotationTitle,
                              lineItemUnit: _lineItemUnit,
                              invoiceTerms: _invoiceTerms,
                              quotationTerms: _quotationTerms,
                              customerSignature: _customerSignature,
                              authorizedSignature: _authorizedSignature,
                              onTemplateChanged: (value) {
                                setState(() => _selectedTemplate = value);
                              },
                              onPreviewTypeChanged: (value) {
                                setState(() => _previewType = value);
                              },
                              onShowHsnChanged: (value) =>
                                  setState(() => _showHsn = value),
                              onShowStateCodeChanged: (value) =>
                                  setState(() => _showStateCode = value),
                              onShowOriginalCopyChanged: (value) =>
                                  setState(() => _showOriginalCopy = value),
                              onShowAmountInWordsChanged: (value) =>
                                  setState(() => _showAmountInWords = value),
                              onShowBankDetailsChanged: (value) =>
                                  setState(() => _showBankDetails = value),
                              onShowPaymentQrChanged: (value) =>
                                  setState(() => _showPaymentQr = value),
                              onShowSignatureBlockChanged: (value) =>
                                  setState(() => _showSignatureBlock = value),
                              onApplyPreset: _applyPreset,
                            );
                            final preview = _TemplatePreview(
                              profile: state.profile,
                              previewType: _previewType,
                              invoiceTitle: _cleanTitle(
                                _invoiceTitle.text,
                                'TAX INVOICE',
                              ),
                              quotationTitle: _cleanTitle(
                                _quotationTitle.text,
                                'QUOTATION',
                              ),
                              showHsn: _showHsn,
                              showStateCode: _showStateCode,
                              showOriginalCopy: _showOriginalCopy,
                              showAmountInWords: _showAmountInWords,
                              showBankDetails: _showBankDetails,
                              showPaymentQr: _showPaymentQr,
                              showSignatureBlock: _showSignatureBlock,
                              invoiceTerms: _invoiceTerms.text,
                              quotationTerms: _quotationTerms.text,
                              customerSignature: _cleanTitle(
                                _customerSignature.text,
                                "Customer's Seal & Signature",
                              ),
                              authorizedSignature: _cleanTitle(
                                _authorizedSignature.text,
                                'For Authorised Signatory',
                              ),
                            );

                            if (!wide) {
                              return SingleChildScrollView(
                                child: Column(
                                  children: [
                                    editor,
                                    const SizedBox(height: AppSpacing.lg),
                                    SizedBox(height: 760, child: preview),
                                  ],
                                ),
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 760, child: editor),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: SizedBox(
                                    height: constraints.maxHeight,
                                    child: preview,
                                  ),
                                ),
                              ],
                            );
                          },
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
    _invoiceTitle.text = settings.invoiceTitle;
    _quotationTitle.text = settings.quotationTitle;
    _invoiceTerms.text = profile.defaultInvoiceTerms;
    _quotationTerms.text = profile.defaultQuotationTerms;
    _lineItemUnit.text = settings.defaultLineItemUnit;
    _customerSignature.text = settings.customerSignatureLabel;
    _authorizedSignature.text = settings.authorizedSignatoryLabel;
    _selectedTemplate = settings.documentTemplate;
    _showHsn = settings.showLineItemHsn;
    _showStateCode = settings.showCustomerStateCode;
    _showOriginalCopy = settings.showOriginalCopyLabelOnPdf;
    _showAmountInWords = settings.showAmountInWordsOnPdf;
    _showBankDetails = settings.showBankDetailsOnPdf;
    _showPaymentQr = settings.showPaymentQrOnPdf;
    _showSignatureBlock = settings.showSignatureBlockOnPdf;
    _loaded = true;
  }

  void _applyPreset(_TemplatePreset preset) {
    setState(() {
      _selectedTemplate = preset.storageValue;
      _invoiceTitle.text = preset.invoiceTitle;
      _quotationTitle.text = preset.quotationTitle;
      _showHsn = preset.showHsn;
      _showStateCode = preset.showStateCode;
      _showOriginalCopy = preset.showOriginalCopy;
      _showAmountInWords = preset.showAmountInWords;
      _showBankDetails = preset.showBankDetails;
      _showPaymentQr = preset.showPaymentQr;
      _showSignatureBlock = preset.showSignatureBlock;
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
        documentTemplate: _selectedTemplate,
        invoiceTitle: _cleanTitle(_invoiceTitle.text, 'TAX INVOICE'),
        quotationTitle: _cleanTitle(_quotationTitle.text, 'QUOTATION'),
        showLineItemHsn: _showHsn,
        showCustomerStateCode: _showStateCode,
        showOriginalCopyLabelOnPdf: _showOriginalCopy,
        showAmountInWordsOnPdf: _showAmountInWords,
        showBankDetailsOnPdf: _showBankDetails,
        showPaymentQrOnPdf: _showPaymentQr,
        showSignatureBlockOnPdf: _showSignatureBlock,
        customerSignatureLabel: _cleanTitle(
          _customerSignature.text,
          "Customer's Seal & Signature",
        ),
        authorizedSignatoryLabel: _cleanTitle(
          _authorizedSignature.text,
          'For Authorised Signatory',
        ),
        defaultLineItemUnit: lineItemUnit,
      ),
    );
  }

  String _cleanTitle(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
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
                  'Advanced Templates',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Shape invoice and quotation PDFs, reusable terms, visible sections, and signature labels.',
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

class _TemplateEditor extends StatelessWidget {
  const _TemplateEditor({
    required this.selectedTemplate,
    required this.previewType,
    required this.showHsn,
    required this.showStateCode,
    required this.showOriginalCopy,
    required this.showAmountInWords,
    required this.showBankDetails,
    required this.showPaymentQr,
    required this.showSignatureBlock,
    required this.invoiceTitle,
    required this.quotationTitle,
    required this.lineItemUnit,
    required this.invoiceTerms,
    required this.quotationTerms,
    required this.customerSignature,
    required this.authorizedSignature,
    required this.onTemplateChanged,
    required this.onPreviewTypeChanged,
    required this.onShowHsnChanged,
    required this.onShowStateCodeChanged,
    required this.onShowOriginalCopyChanged,
    required this.onShowAmountInWordsChanged,
    required this.onShowBankDetailsChanged,
    required this.onShowPaymentQrChanged,
    required this.onShowSignatureBlockChanged,
    required this.onApplyPreset,
  });

  final String selectedTemplate;
  final _PreviewType previewType;
  final bool showHsn;
  final bool showStateCode;
  final bool showOriginalCopy;
  final bool showAmountInWords;
  final bool showBankDetails;
  final bool showPaymentQr;
  final bool showSignatureBlock;
  final TextEditingController invoiceTitle;
  final TextEditingController quotationTitle;
  final TextEditingController lineItemUnit;
  final TextEditingController invoiceTerms;
  final TextEditingController quotationTerms;
  final TextEditingController customerSignature;
  final TextEditingController authorizedSignature;
  final ValueChanged<String> onTemplateChanged;
  final ValueChanged<_PreviewType> onPreviewTypeChanged;
  final ValueChanged<bool> onShowHsnChanged;
  final ValueChanged<bool> onShowStateCodeChanged;
  final ValueChanged<bool> onShowOriginalCopyChanged;
  final ValueChanged<bool> onShowAmountInWordsChanged;
  final ValueChanged<bool> onShowBankDetailsChanged;
  final ValueChanged<bool> onShowPaymentQrChanged;
  final ValueChanged<bool> onShowSignatureBlockChanged;
  final ValueChanged<_TemplatePreset> onApplyPreset;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _EditorPanel(
            icon: Icons.dashboard_customize_outlined,
            title: 'Document Style',
            subtitle: 'Choose a starting layout and tune it for your business.',
            child: Column(
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final preset in _TemplatePreset.values)
                      _PresetButton(
                        preset: preset,
                        selected: selectedTemplate == preset.storageValue,
                        onPressed: () {
                          onTemplateChanged(preset.storageValue);
                          onApplyPreset(preset);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: invoiceTitle,
                        decoration: const InputDecoration(
                          labelText: 'Invoice PDF Title',
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: quotationTitle,
                        decoration: const InputDecoration(
                          labelText: 'Quotation PDF Title',
                          prefixIcon: Icon(Icons.request_quote_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _EditorPanel(
            icon: Icons.visibility_outlined,
            title: 'PDF Sections',
            subtitle: 'Hide unused sections so printed documents stay clean.',
            child: Column(
              children: [
                _ToggleGrid(
                  children: [
                    _TemplateSwitch(
                      icon: Icons.tag_outlined,
                      title: 'HSN/SAC Column',
                      subtitle: 'Show only when item codes matter.',
                      value: showHsn,
                      onChanged: onShowHsnChanged,
                    ),
                    _TemplateSwitch(
                      icon: Icons.map_outlined,
                      title: 'State Code',
                      subtitle: 'Billing and shipping state codes.',
                      value: showStateCode,
                      onChanged: onShowStateCodeChanged,
                    ),
                    _TemplateSwitch(
                      icon: Icons.copy_all_outlined,
                      title: 'Original Copy Label',
                      subtitle: 'Print original recipient label.',
                      value: showOriginalCopy,
                      onChanged: onShowOriginalCopyChanged,
                    ),
                    _TemplateSwitch(
                      icon: Icons.format_list_numbered_outlined,
                      title: 'Amount in Words',
                      subtitle: 'Print total value in words.',
                      value: showAmountInWords,
                      onChanged: onShowAmountInWordsChanged,
                    ),
                    _TemplateSwitch(
                      icon: Icons.account_balance_outlined,
                      title: 'Bank Details',
                      subtitle: 'Show account and IFSC block.',
                      value: showBankDetails,
                      onChanged: onShowBankDetailsChanged,
                    ),
                    _TemplateSwitch(
                      icon: Icons.qr_code_2_outlined,
                      title: 'Payment QR',
                      subtitle: 'Show UPI or uploaded payment QR.',
                      value: showPaymentQr,
                      onChanged: onShowPaymentQrChanged,
                    ),
                    _TemplateSwitch(
                      icon: Icons.draw_outlined,
                      title: 'Signature Footer',
                      subtitle: 'Customer and authorised signatory labels.',
                      value: showSignatureBlock,
                      onChanged: onShowSignatureBlockChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _EditorPanel(
            icon: Icons.edit_note_outlined,
            title: 'Reusable Text',
            subtitle: 'Defaults copied into new invoices and quotations.',
            child: Column(
              children: [
                TextField(
                  controller: lineItemUnit,
                  decoration: const InputDecoration(
                    labelText: 'Default Line Item Unit',
                    prefixIcon: Icon(Icons.straighten_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customerSignature,
                        decoration: const InputDecoration(
                          labelText: 'Customer Signature Label',
                          prefixIcon: Icon(Icons.person_pin_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: authorizedSignature,
                        decoration: const InputDecoration(
                          labelText: 'Authorised Signatory Label',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: invoiceTerms,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Terms',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: quotationTerms,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Quotation Terms',
                    prefixIcon: Icon(Icons.request_quote_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _EditorPanel(
            icon: Icons.preview_outlined,
            title: 'Preview Mode',
            subtitle: 'Switch the preview without leaving this page.',
            child: SegmentedButton<_PreviewType>(
              segments: const [
                ButtonSegment(
                  value: _PreviewType.invoice,
                  icon: Icon(Icons.receipt_long_outlined),
                  label: Text('Invoice'),
                ),
                ButtonSegment(
                  value: _PreviewType.quotation,
                  icon: Icon(Icons.request_quote_outlined),
                  label: Text('Quotation'),
                ),
              ],
              selected: {previewType},
              onSelectionChanged: (value) => onPreviewTypeChanged(value.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

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
          _SectionTitle(icon: icon, title: title, subtitle: subtitle),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.preset,
    required this.selected,
    required this.onPressed,
  });

  final _TemplatePreset preset;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 232,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(AppSpacing.md),
          backgroundColor: selected ? AppColors.primaryLight : null,
          side: BorderSide(
            color: selected ? AppColors.primaryPurple : AppColors.border,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            Icon(preset.icon, color: AppColors.primaryPurple),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preset.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleGrid extends StatelessWidget {
  const _ToggleGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        final width =
            (constraints.maxWidth - (columns - 1) * AppSpacing.md) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _TemplateSwitch extends StatelessWidget {
  const _TemplateSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? AppColors.primaryPurple : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? AppColors.primaryPurple : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({
    required this.profile,
    required this.previewType,
    required this.invoiceTitle,
    required this.quotationTitle,
    required this.showHsn,
    required this.showStateCode,
    required this.showOriginalCopy,
    required this.showAmountInWords,
    required this.showBankDetails,
    required this.showPaymentQr,
    required this.showSignatureBlock,
    required this.invoiceTerms,
    required this.quotationTerms,
    required this.customerSignature,
    required this.authorizedSignature,
  });

  final CompanyProfile profile;
  final _PreviewType previewType;
  final String invoiceTitle;
  final String quotationTitle;
  final bool showHsn;
  final bool showStateCode;
  final bool showOriginalCopy;
  final bool showAmountInWords;
  final bool showBankDetails;
  final bool showPaymentQr;
  final bool showSignatureBlock;
  final String invoiceTerms;
  final String quotationTerms;
  final String customerSignature;
  final String authorizedSignature;

  @override
  Widget build(BuildContext context) {
    final businessName = profile.businessName.trim().isEmpty
        ? 'Business Name'
        : profile.businessName.trim();
    final address = [
      profile.addressLine1,
      profile.addressLine2,
      profile.city,
      profile.state,
      profile.pincode,
    ].where((value) => value.trim().isNotEmpty).join(', ');
    final title = previewType == _PreviewType.invoice
        ? invoiceTitle
        : quotationTitle;
    final terms = previewType == _PreviewType.invoice
        ? invoiceTerms
        : quotationTerms;

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
            icon: Icons.plagiarism_outlined,
            title: 'Live Preview',
            subtitle: 'The PDF will hide sections when their data is empty.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD7DCE5)),
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      if (showOriginalCopy &&
                          previewType == _PreviewType.invoice) ...[
                        const SizedBox(height: 2),
                        const Text(
                          '(ORIGINAL FOR RECIPIENT)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 84,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD7DCE5),
                              ),
                            ),
                            child: const Icon(Icons.image_outlined, size: 30),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  businessName,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                if (address.isNotEmpty)
                                  Text(address, textAlign: TextAlign.right),
                                if (profile.gstin.trim().isNotEmpty)
                                  Text('GSTIN/UIN: ${profile.gstin.trim()}'),
                                if (profile.phone.trim().isNotEmpty)
                                  Text('Mobile: ${profile.phone.trim()}'),
                                if (profile.email.trim().isNotEmpty)
                                  Text('Email: ${profile.email.trim()}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28, color: Colors.black),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              previewType == _PreviewType.invoice
                                  ? 'Invoice No: INV-2026/05-001'
                                  : 'Quotation No: QUO-2026/05-001',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Text(
                            'Date: 02 May 2026',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
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
                          if (previewType == _PreviewType.invoice) ...[
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
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Grand Total: Rs 14750.00',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (showAmountInWords) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Total in Words: Fourteen thousand seven hundred fifty rupees only',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                      if (showBankDetails || showPaymentQr) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showBankDetails)
                              const Expanded(
                                child: _PreviewBlock(
                                  title: 'Company Bank Details',
                                  lines: [
                                    'Bank: Union Bank',
                                    'A/c No: 5019006884968',
                                    'IFSC: UBIN0935051',
                                  ],
                                ),
                              ),
                            if (showPaymentQr) ...[
                              const SizedBox(width: AppSpacing.md),
                              Container(
                                width: 72,
                                height: 72,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                ),
                                child: const Icon(Icons.qr_code_2_outlined),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (terms.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text('Terms: ${terms.trim()}'),
                      ],
                      if (showSignatureBlock) ...[
                        const SizedBox(height: 56),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              customerSignature,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              authorizedSignature,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
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

enum _PreviewType { invoice, quotation }

enum _TemplatePreset {
  classicTax(
    storageValue: 'classic_tax',
    title: 'Classic Tax',
    description: 'GST-ready invoice with full compliance blocks.',
    icon: Icons.receipt_long_outlined,
    invoiceTitle: 'TAX INVOICE',
    quotationTitle: 'QUOTATION',
    showHsn: true,
    showStateCode: true,
    showOriginalCopy: true,
    showAmountInWords: true,
    showBankDetails: true,
    showPaymentQr: true,
    showSignatureBlock: true,
    invoiceTerms: 'Thank you for your business.',
    quotationTerms: 'Quotation validity: 15 days.',
  ),
  compactBill(
    storageValue: 'compact_bill',
    title: 'Compact Bill',
    description: 'Short printout for quick non-GST billing.',
    icon: Icons.article_outlined,
    invoiceTitle: 'INVOICE',
    quotationTitle: 'ESTIMATE',
    showHsn: false,
    showStateCode: false,
    showOriginalCopy: false,
    showAmountInWords: false,
    showBankDetails: false,
    showPaymentQr: true,
    showSignatureBlock: true,
    invoiceTerms: 'Payment due on receipt.',
    quotationTerms: 'Prices are subject to confirmation.',
  ),
  serviceQuote(
    storageValue: 'service_quote',
    title: 'Service Quote',
    description: 'Cleaner proposal-style quotation defaults.',
    icon: Icons.handyman_outlined,
    invoiceTitle: 'SERVICE INVOICE',
    quotationTitle: 'SERVICE QUOTATION',
    showHsn: false,
    showStateCode: true,
    showOriginalCopy: true,
    showAmountInWords: true,
    showBankDetails: true,
    showPaymentQr: false,
    showSignatureBlock: true,
    invoiceTerms: null,
    quotationTerms:
        'Quotation validity: 15 days.\nScope changes may revise the final amount.',
  ),
  letterhead(
    storageValue: 'letterhead',
    title: 'Letterhead',
    description: 'Brand-heavy header with complete footer controls.',
    icon: Icons.business_center_outlined,
    invoiceTitle: 'TAX INVOICE',
    quotationTitle: 'QUOTATION',
    showHsn: true,
    showStateCode: true,
    showOriginalCopy: true,
    showAmountInWords: true,
    showBankDetails: true,
    showPaymentQr: true,
    showSignatureBlock: true,
    invoiceTerms: 'Goods once sold will not be taken back.',
    quotationTerms: 'This quotation is subject to stock and price changes.',
  );

  const _TemplatePreset({
    required this.storageValue,
    required this.title,
    required this.description,
    required this.icon,
    required this.invoiceTitle,
    required this.quotationTitle,
    required this.showHsn,
    required this.showStateCode,
    required this.showOriginalCopy,
    required this.showAmountInWords,
    required this.showBankDetails,
    required this.showPaymentQr,
    required this.showSignatureBlock,
    required this.invoiceTerms,
    required this.quotationTerms,
  });

  final String storageValue;
  final String title;
  final String description;
  final IconData icon;
  final String invoiceTitle;
  final String quotationTitle;
  final bool showHsn;
  final bool showStateCode;
  final bool showOriginalCopy;
  final bool showAmountInWords;
  final bool showBankDetails;
  final bool showPaymentQr;
  final bool showSignatureBlock;
  final String? invoiceTerms;
  final String? quotationTerms;
}
