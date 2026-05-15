part of 'create_invoice_page.dart';

enum _SelectedCustomerConflictAction { keepSelected, usePhoneOwner, cancel }

enum _CustomerDialogExit { createNew, cancel }

class _CustomerResolve {
  const _CustomerResolve(this.customer);

  static const cancelled = _CustomerResolve._cancelled();

  const _CustomerResolve._cancelled() : customer = null;

  final Customer? customer;

  bool get isCancelled => identical(this, cancelled);
}

class _GstinValidationState {
  const _GstinValidationState({required this.gstin, required this.isValid});

  final String gstin;
  final bool isValid;
}

class _GstinAutofillSnapshot {
  const _GstinAutofillSnapshot({
    required this.gstin,
    required this.customerName,
    required this.stateName,
    required this.stateCode,
    required this.billingAddress,
    required this.customerCustomFields,
  });

  final String gstin;
  final String customerName;
  final String stateName;
  final String stateCode;
  final String billingAddress;
  final Map<String, String> customerCustomFields;
}

class _CustomerConflictTile extends StatelessWidget {
  const _CustomerConflictTile({
    required this.label,
    required this.customer,
    this.onTap,
  });

  final String label;
  final Customer customer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.person_outline, color: AppColors.primaryPurple),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.name.isEmpty ? 'Unnamed customer' : customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    customer.phone.isEmpty ? 'No phone' : customer.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _InvoiceTotals {
  const _InvoiceTotals({
    required this.subtotal,
    required this.discountTotal,
    required this.extraChargeTotal,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.roundOff,
    required this.grandTotal,
  });

  final double subtotal;
  final double discountTotal;
  final double extraChargeTotal;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double roundOff;
  final double grandTotal;
}

class _NumberToWords {
  static const List<String> _ones = [
    'Zero',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];

  static const List<String> _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  static String convert(double amount) {
    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();
    final rupeeWords = _convertNumber(rupees);
    if (paise == 0) return '$rupeeWords rupees';
    return '$rupeeWords rupees and ${_convertNumber(paise)} paise';
  }

  static String _convertNumber(int number) {
    if (number < 20) return _ones[number];
    if (number < 100) {
      final ten = _tens[number ~/ 10];
      final remainder = number % 10;
      return remainder == 0 ? ten : '$ten ${_ones[remainder]}';
    }
    if (number < 1000) {
      final hundred = '${_ones[number ~/ 100]} Hundred';
      final remainder = number % 100;
      return remainder == 0 ? hundred : '$hundred ${_convertNumber(remainder)}';
    }
    if (number < 100000) {
      final thousand = '${_convertNumber(number ~/ 1000)} Thousand';
      final remainder = number % 1000;
      return remainder == 0
          ? thousand
          : '$thousand ${_convertNumber(remainder)}';
    }
    if (number < 10000000) {
      final lakh = '${_convertNumber(number ~/ 100000)} Lakh';
      final remainder = number % 100000;
      return remainder == 0 ? lakh : '$lakh ${_convertNumber(remainder)}';
    }
    final crore = '${_convertNumber(number ~/ 10000000)} Crore';
    final remainder = number % 10000000;
    return remainder == 0 ? crore : '$crore ${_convertNumber(remainder)}';
  }
}
