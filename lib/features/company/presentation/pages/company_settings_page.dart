import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_cubit.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/company_profile.dart';
import '../cubit/company_settings_cubit.dart';

class CompanySettingsPage extends StatelessWidget {
  const CompanySettingsPage({super.key});

  static const routePath = '/company-settings';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CompanySettingsCubit>()..load(),
      child: const _CompanySettingsView(),
    );
  }
}

class _CompanySettingsView extends StatefulWidget {
  const _CompanySettingsView();

  @override
  State<_CompanySettingsView> createState() => _CompanySettingsViewState();
}

class _CompanySettingsViewState extends State<_CompanySettingsView> {
  final _formKey = GlobalKey<FormState>();

  final _businessName = TextEditingController();
  final _legalName = TextEditingController();
  final _gstin = TextEditingController();
  final _pan = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _country = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccountName = TextEditingController();
  final _bankAccountNumber = TextEditingController();
  final _ifscCode = TextEditingController();
  final _upiId = TextEditingController();
  final _invoiceTerms = TextEditingController();
  final _quotationTerms = TextEditingController();
  final _logoBase64 = TextEditingController();
  final _paymentQrBase64 = TextEditingController();

  final _gstRate = TextEditingController();
  final _invoicePrefix = TextEditingController();
  final _invoiceSeparator = TextEditingController();
  final _invoiceDateFormat = TextEditingController();
  final _invoiceNextNumber = TextEditingController();
  final _invoicePadding = TextEditingController();
  final _quotationPrefix = TextEditingController();
  final _quotationSeparator = TextEditingController();
  final _quotationDateFormat = TextEditingController();
  final _quotationNextNumber = TextEditingController();
  final _quotationPadding = TextEditingController();
  final _pointsPerRupee = TextEditingController();
  final _pointsRedemptionValue = TextEditingController();
  final _currencyCode = TextEditingController();
  final _currencySymbol = TextEditingController();
  final _primaryColorHex = TextEditingController();

  bool _gstEnabled = true;
  bool _loyaltyEnabled = true;
  String _themeMode = 'dark';
  bool _filledFromState = false;

  @override
  void dispose() {
    for (final controller in [
      _businessName,
      _legalName,
      _gstin,
      _pan,
      _email,
      _phone,
      _website,
      _addressLine1,
      _addressLine2,
      _city,
      _state,
      _pincode,
      _country,
      _bankName,
      _bankAccountName,
      _bankAccountNumber,
      _ifscCode,
      _upiId,
      _invoiceTerms,
      _quotationTerms,
      _logoBase64,
      _paymentQrBase64,
      _gstRate,
      _invoicePrefix,
      _invoiceSeparator,
      _invoiceDateFormat,
      _invoiceNextNumber,
      _invoicePadding,
      _quotationPrefix,
      _quotationSeparator,
      _quotationDateFormat,
      _quotationNextNumber,
      _quotationPadding,
      _pointsPerRupee,
      _pointsRedemptionValue,
      _currencyCode,
      _currencySymbol,
      _primaryColorHex,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CompanySettingsCubit, CompanySettingsState>(
      listener: (context, state) {
        if ((state.status == CompanySettingsStatus.loaded ||
                state.status == CompanySettingsStatus.saved) &&
            !_filledFromState) {
          _fillControllers(state.profile, state.settings);
          context.read<ThemeCubit>().apply(
            themeMode: state.settings.themeMode,
            primaryColorHex: state.settings.primaryColorHex,
          );
          _filledFromState = true;
        }

        if (state.status == CompanySettingsStatus.failure ||
            state.status == CompanySettingsStatus.saved) {
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
          child: state.status == CompanySettingsStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SettingsHero(
                              isBusy: state.isBusy,
                              isSaving:
                                  state.status == CompanySettingsStatus.saving,
                              onSave: () => _save(context),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'These details will feed invoices, quotations, GST fields, payment blocks, and PDF headers.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _Section(
                              title: 'Business',
                              children: [
                                _Field(
                                  _businessName,
                                  'Business Name',
                                  required: true,
                                ),
                                _Field(_legalName, 'Legal Name'),
                                _Field(_gstin, 'GSTIN'),
                                _Field(_pan, 'PAN'),
                                _Field(_email, 'Email'),
                                _Field(_phone, 'Phone'),
                                _Field(_website, 'Website'),
                              ],
                            ),
                            _Section(
                              title: 'Address',
                              children: [
                                _Field(_addressLine1, 'Address Line 1'),
                                _Field(_addressLine2, 'Address Line 2'),
                                _Field(_city, 'City'),
                                _Field(_state, 'State'),
                                _Field(_pincode, 'Pincode'),
                                _Field(_country, 'Country'),
                              ],
                            ),
                            _Section(
                              title: 'Bank & Payment',
                              children: [
                                _Field(_bankName, 'Bank Name'),
                                _Field(_bankAccountName, 'Account Name'),
                                _Field(_bankAccountNumber, 'Account Number'),
                                _Field(_ifscCode, 'IFSC Code'),
                                _Field(_upiId, 'UPI ID'),
                              ],
                            ),
                            _Section(
                              title: 'Defaults',
                              children: [
                                _Field(
                                  _invoiceTerms,
                                  'Invoice Terms',
                                  maxLines: 3,
                                ),
                                _Field(
                                  _quotationTerms,
                                  'Quotation Terms',
                                  maxLines: 3,
                                ),
                                _Field(_logoBase64, 'Logo Base64'),
                                _Field(_paymentQrBase64, 'Payment QR Base64'),
                              ],
                            ),
                            _Section(
                              title: 'Invoice Settings',
                              children: [
                                _ToggleField(
                                  title: 'GST Enabled',
                                  value: _gstEnabled,
                                  onChanged: (value) =>
                                      setState(() => _gstEnabled = value),
                                ),
                                _Field(
                                  _gstRate,
                                  'Default GST %',
                                  numeric: true,
                                ),
                                _Field(_invoicePrefix, 'Invoice Prefix'),
                                _Field(
                                  _invoiceSeparator,
                                  'Invoice Separator',
                                  helperText: 'Examples: -, /, //',
                                ),
                                _Field(
                                  _invoiceDateFormat,
                                  'Invoice Date Format',
                                  helperText:
                                      'Blank, yyyy, yyyy/MM, yyyy/MM/dd',
                                ),
                                _Field(
                                  _invoiceNextNumber,
                                  'Next Invoice Number',
                                  numeric: true,
                                ),
                                _Field(
                                  _invoicePadding,
                                  'Invoice Padding',
                                  numeric: true,
                                ),
                                _Field(_currencyCode, 'Currency Code'),
                                _Field(_currencySymbol, 'Currency Symbol'),
                                _NumberPreview(
                                  label: 'Invoice Preview',
                                  prefixController: _invoicePrefix,
                                  separatorController: _invoiceSeparator,
                                  dateFormatController: _invoiceDateFormat,
                                  numberController: _invoiceNextNumber,
                                  paddingController: _invoicePadding,
                                ),
                              ],
                            ),
                            _Section(
                              title: 'Quotation Settings',
                              children: [
                                _Field(_quotationPrefix, 'Quotation Prefix'),
                                _Field(
                                  _quotationSeparator,
                                  'Quotation Separator',
                                  helperText: 'Examples: -, /, //',
                                ),
                                _Field(
                                  _quotationDateFormat,
                                  'Quotation Date Format',
                                  helperText:
                                      'Blank, yyyy, yyyy/MM, yyyy/MM/dd',
                                ),
                                _Field(
                                  _quotationNextNumber,
                                  'Next Quotation Number',
                                  numeric: true,
                                ),
                                _Field(
                                  _quotationPadding,
                                  'Quotation Padding',
                                  numeric: true,
                                ),
                                _NumberPreview(
                                  label: 'Quotation Preview',
                                  prefixController: _quotationPrefix,
                                  separatorController: _quotationSeparator,
                                  dateFormatController: _quotationDateFormat,
                                  numberController: _quotationNextNumber,
                                  paddingController: _quotationPadding,
                                ),
                              ],
                            ),
                            _Section(
                              title: 'Appearance',
                              children: [
                                _ThemeModeSelector(
                                  value: _themeMode,
                                  onChanged: (value) {
                                    setState(() => _themeMode = value);
                                    context.read<ThemeCubit>().apply(
                                      themeMode: value,
                                      primaryColorHex: _primaryColorHex.text,
                                    );
                                  },
                                ),
                                _Field(
                                  _primaryColorHex,
                                  'Primary Color',
                                  helperText: 'Example: #7C4DFF',
                                  onChanged: (_) {
                                    context.read<ThemeCubit>().apply(
                                      themeMode: _themeMode,
                                      primaryColorHex: _primaryColorHex.text,
                                    );
                                  },
                                ),
                                _PrimaryColorSwatches(
                                  selectedHex: _primaryColorHex.text,
                                  onSelected: (hex) {
                                    setState(() => _primaryColorHex.text = hex);
                                    context.read<ThemeCubit>().apply(
                                      themeMode: _themeMode,
                                      primaryColorHex: hex,
                                    );
                                  },
                                ),
                              ],
                            ),
                            _Section(
                              title: 'Loyalty Settings',
                              children: [
                                _ToggleField(
                                  title: 'Loyalty Points Enabled',
                                  value: _loyaltyEnabled,
                                  onChanged: (value) =>
                                      setState(() => _loyaltyEnabled = value),
                                ),
                                _Field(
                                  _pointsPerRupee,
                                  'Points Per Rupee',
                                  numeric: true,
                                ),
                                _Field(
                                  _pointsRedemptionValue,
                                  'Point Value',
                                  numeric: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  void _fillControllers(CompanyProfile profile, AppSettings settings) {
    _businessName.text = profile.businessName;
    _legalName.text = profile.legalName;
    _gstin.text = profile.gstin;
    _pan.text = profile.pan;
    _email.text = profile.email;
    _phone.text = profile.phone;
    _website.text = profile.website;
    _addressLine1.text = profile.addressLine1;
    _addressLine2.text = profile.addressLine2;
    _city.text = profile.city;
    _state.text = profile.state;
    _pincode.text = profile.pincode;
    _country.text = profile.country;
    _bankName.text = profile.bankName;
    _bankAccountName.text = profile.bankAccountName;
    _bankAccountNumber.text = profile.bankAccountNumber;
    _ifscCode.text = profile.ifscCode;
    _upiId.text = profile.upiId;
    _invoiceTerms.text = profile.defaultInvoiceTerms;
    _quotationTerms.text = profile.defaultQuotationTerms;
    _logoBase64.text = profile.logoBase64;
    _paymentQrBase64.text = profile.paymentQrBase64;
    _gstEnabled = settings.gstEnabled;
    _loyaltyEnabled = settings.loyaltyEnabled;
    _gstRate.text = settings.defaultGstRate.toString();
    _invoicePrefix.text = settings.invoicePrefix;
    _invoiceSeparator.text = settings.invoiceSeparator;
    _invoiceDateFormat.text = settings.invoiceDateFormat;
    _invoiceNextNumber.text = settings.invoiceNextNumber.toString();
    _invoicePadding.text = settings.invoiceNumberPadding.toString();
    _quotationPrefix.text = settings.quotationPrefix;
    _quotationSeparator.text = settings.quotationSeparator;
    _quotationDateFormat.text = settings.quotationDateFormat;
    _quotationNextNumber.text = settings.quotationNextNumber.toString();
    _quotationPadding.text = settings.quotationNumberPadding.toString();
    _pointsPerRupee.text = settings.pointsPerRupee.toString();
    _pointsRedemptionValue.text = settings.pointsRedemptionValue.toString();
    _currencyCode.text = settings.currencyCode;
    _currencySymbol.text = settings.currencySymbol;
    _themeMode = settings.themeMode;
    _primaryColorHex.text = settings.primaryColorHex;
  }

  void _save(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<CompanySettingsCubit>().save(
      profile: CompanyProfile(
        businessName: _businessName.text.trim(),
        legalName: _legalName.text.trim(),
        gstin: _gstin.text.trim(),
        pan: _pan.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        website: _website.text.trim(),
        addressLine1: _addressLine1.text.trim(),
        addressLine2: _addressLine2.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        pincode: _pincode.text.trim(),
        country: _country.text.trim(),
        bankName: _bankName.text.trim(),
        bankAccountName: _bankAccountName.text.trim(),
        bankAccountNumber: _bankAccountNumber.text.trim(),
        ifscCode: _ifscCode.text.trim(),
        upiId: _upiId.text.trim(),
        defaultInvoiceTerms: _invoiceTerms.text.trim(),
        defaultQuotationTerms: _quotationTerms.text.trim(),
        logoBase64: _logoBase64.text.trim(),
        paymentQrBase64: _paymentQrBase64.text.trim(),
        updatedAt: DateTime.now(),
      ),
      settings: AppSettings(
        gstEnabled: _gstEnabled,
        defaultGstRate: _doubleValue(_gstRate, 18),
        invoicePrefix: _invoicePrefix.text.trim(),
        invoiceSeparator: _invoiceSeparator.text,
        invoiceDateFormat: _invoiceDateFormat.text.trim(),
        invoiceNextNumber: _intValue(_invoiceNextNumber, 1),
        invoiceNumberPadding: _intValue(_invoicePadding, 4),
        quotationPrefix: _quotationPrefix.text.trim(),
        quotationSeparator: _quotationSeparator.text,
        quotationDateFormat: _quotationDateFormat.text.trim(),
        quotationNextNumber: _intValue(_quotationNextNumber, 1),
        quotationNumberPadding: _intValue(_quotationPadding, 4),
        loyaltyEnabled: _loyaltyEnabled,
        pointsPerRupee: _doubleValue(_pointsPerRupee, 0.01),
        pointsRedemptionValue: _doubleValue(_pointsRedemptionValue, 1),
        currencyCode: _currencyCode.text.trim(),
        currencySymbol: _currencySymbol.text.trim(),
        themeMode: _themeMode,
        primaryColorHex: _primaryColorHex.text.trim(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  int _intValue(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  double _doubleValue(TextEditingController controller, double fallback) {
    return double.tryParse(controller.text.trim()) ?? fallback;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final icon = switch (title) {
      'Business' => Icons.storefront_outlined,
      'Address' => Icons.location_on_outlined,
      'Bank & Payment' => Icons.account_balance_outlined,
      'Defaults' => Icons.tune_outlined,
      'Invoice Settings' => Icons.receipt_long_outlined,
      'Quotation Settings' => Icons.request_quote_outlined,
      'Appearance' => Icons.palette_outlined,
      'Loyalty Settings' => Icons.stars_outlined,
      _ => Icons.widgets_outlined,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primaryPurple),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1080
                    ? 3
                    : width >= 720
                    ? 2
                    : 1;
                final itemWidth =
                    (width - (columns - 1) * AppSpacing.lg) / columns;

                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: [
                    for (final child in children)
                      SizedBox(width: itemWidth, child: child),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({
    required this.isBusy,
    required this.isSaving,
    required this.onSave,
  });

  final bool isBusy;
  final bool isSaving;
  final VoidCallback onSave;

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
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryPurple, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.settings, color: AppColors.onAccent),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company Profile & Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Configure business identity, billing defaults, numbering, and loyalty rules.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: isBusy ? null : onSave,
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ToggleField extends StatelessWidget {
  const _ToggleField({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(
    this.controller,
    this.label, {
    this.required = false,
    this.numeric = false,
    this.maxLines = 1,
    this.helperText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool numeric;
  final int maxLines;
  final String? helperText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, helperText: helperText),
      onChanged: onChanged,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return '$label is required';
        if (numeric && text.isNotEmpty && double.tryParse(text) == null) {
          return 'Enter a valid number';
        }
        return null;
      },
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'dark',
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Dark'),
        ),
        ButtonSegment(
          value: 'light',
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Light'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _PrimaryColorSwatches extends StatelessWidget {
  const _PrimaryColorSwatches({
    required this.selectedHex,
    required this.onSelected,
  });

  final String selectedHex;
  final ValueChanged<String> onSelected;

  static const _colors = [
    '#7C4DFF',
    '#5B5EF7',
    '#0EA5E9',
    '#14B8A6',
    '#F97316',
    '#E11D48',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final hex in _colors)
          Tooltip(
            message: hex,
            child: InkWell(
              onTap: () => onSelected(hex),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ThemeCubit.parseColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedHex.toUpperCase() == hex
                        ? AppColors.textPrimary
                        : AppColors.border,
                    width: selectedHex.toUpperCase() == hex ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NumberPreview extends StatelessWidget {
  const _NumberPreview({
    required this.label,
    required this.prefixController,
    required this.separatorController,
    required this.dateFormatController,
    required this.numberController,
    required this.paddingController,
  });

  final String label;
  final TextEditingController prefixController;
  final TextEditingController separatorController;
  final TextEditingController dateFormatController;
  final TextEditingController numberController;
  final TextEditingController paddingController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        prefixController,
        separatorController,
        dateFormatController,
        numberController,
        paddingController,
      ]),
      builder: (context, _) {
        final number = int.tryParse(numberController.text.trim()) ?? 1;
        final padding = int.tryParse(paddingController.text.trim()) ?? 4;
        final formattedNumber = number.toString().padLeft(padding, '0');
        final separator = separatorController.text;
        final formattedDate = _formatDate(dateFormatController.text.trim());
        final previewParts = [
          prefixController.text,
          if (formattedDate.isNotEmpty) formattedDate,
          formattedNumber,
        ].where((part) => part.isNotEmpty).toList();
        final preview = previewParts.join(separator);

        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.tag, size: 20),
          ),
          child: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }

  String _formatDate(String pattern) {
    if (pattern.isEmpty) return '';
    final now = DateTime.now();
    final year = now.year.toString();
    final shortYear = year.substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');

    return pattern
        .replaceAll('yyyy', year)
        .replaceAll('yy', shortYear)
        .replaceAll('MM', month)
        .replaceAll('dd', day);
  }
}
