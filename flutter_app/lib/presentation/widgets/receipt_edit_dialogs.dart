import 'package:flutter/material.dart';

/// Shared receipt editing dialogs
class ReceiptEditDialogs {
  /// Show dialog to edit a text value (e.g., merchant name)
  static Future<String?> editText({
    required BuildContext context,
    required String title,
    required String label,
    required String currentValue,
  }) async {
    String textValue = currentValue;

    return showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            initialValue: textValue,
            autofocus: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => textValue = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(textValue),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog to edit a numeric amount (e.g., total, subtotal)
  static Future<double?> editAmount({
    required BuildContext context,
    required String title,
    required String label,
    double? currentValue,
    String currencySymbol = '€',
    bool isPercent = false,
  }) async {
    String textValue = currentValue?.toString() ?? '';

    return showDialog<double?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            initialValue: textValue,
            autofocus: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              prefixText: isPercent ? null : '$currencySymbol ',
              suffixText: isPercent ? '%' : null,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => textValue = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(double.tryParse(textValue));
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog to edit date and time
  static Future<Map<String, String>?> editDateTime({
    required BuildContext context,
    String? currentDate,
    String? currentTime,
  }) async {
    String dateValue = currentDate ?? '';
    String timeValue = currentTime ?? '';

    return showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Date & Time'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: dateValue,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Date (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                    hintText: '2025-01-15',
                  ),
                  onChanged: (value) => dateValue = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: timeValue,
                  decoration: const InputDecoration(
                    labelText: 'Time (HH:MM)',
                    border: OutlineInputBorder(),
                    hintText: '14:30',
                  ),
                  onChanged: (value) => timeValue = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop({
                'date': dateValue,
                'time': timeValue,
              }),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog to select payment method
  static Future<String?> editPaymentMethod({
    required BuildContext context,
    String? currentValue,
    List<String> commonMethods = const ['Card', 'Cash', 'Debit', 'Credit', 'Mobile'],
  }) async {
    String textValue = currentValue ?? '';

    return showDialog<String?>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Payment Method'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: textValue,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => textValue = value,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: commonMethods.map((method) => ActionChip(
                    label: Text(method),
                    onPressed: () => Navigator.of(dialogContext).pop(method),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(textValue),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog to edit tax breakdown
  static Future<List<Map<String, dynamic>>?> editTaxBreakdown({
    required BuildContext context,
    required List<dynamic> currentBreakdown,
    String currencySymbol = '€',
  }) async {
    final List<Map<String, dynamic>> editableBreakdown =
        currentBreakdown.map((e) => Map<String, dynamic>.from(e)).toList();

    return showDialog<List<Map<String, dynamic>>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Tax Breakdown'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: editableBreakdown.length,
                  itemBuilder: (context, index) {
                    final item = editableBreakdown[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['rate']?.toString() ?? '',
                                    decoration: const InputDecoration(
                                      labelText: 'Rate %',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => item['rate'] = double.tryParse(v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['tax_amount']?.toString() ?? '',
                                    decoration: InputDecoration(
                                      labelText: 'Tax $currencySymbol',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) => item['tax_amount'] = double.tryParse(v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: item['gross_amount']?.toString() ?? '',
                              decoration: InputDecoration(
                                labelText: 'Gross $currencySymbol',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => item['gross_amount'] = double.tryParse(v),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(editableBreakdown),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show confirmation dialog
  static Future<bool> confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: confirmColor != null ? TextStyle(color: confirmColor) : null,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
