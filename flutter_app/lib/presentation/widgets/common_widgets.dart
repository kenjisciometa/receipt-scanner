import 'package:flutter/material.dart';

/// Statistics card widget for displaying metric values
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card wrapper for data sections
class DataCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double elevation;

  const DataCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.elevation = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation,
      child: Padding(
        padding: padding!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// Section title widget
class SectionTitle extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const SectionTitle({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.only(top: 16, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

/// Simple label-value row widget
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final EdgeInsetsGeometry padding;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.isBold = false,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }
}

/// Label-value row with flexible layout for longer values
class LabelValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;
  final int labelFlex;
  final int valueFlex;
  final EdgeInsetsGeometry padding;

  const LabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.isHighlighted = false,
    this.labelFlex = 2,
    this.valueFlex = 3,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: valueFlex,
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted ? Colors.black : Colors.black87,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlighted ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Editable field widget with tap to edit
class EditableField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool isBold;

  const EditableField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, size: 20, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }
}

/// Loading indicator with optional message
class LoadingIndicator extends StatelessWidget {
  final String? message;

  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!),
          ],
        ],
      ),
    );
  }
}

/// Error display widget with optional retry button
class ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorDisplay({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Debug/info section with icon, title, and content
class DebugSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final String? subtitle;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color titleColor;
  final Color contentColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;

  const DebugSection({
    super.key,
    required this.icon,
    required this.title,
    required this.content,
    this.subtitle,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.titleColor,
    required this.contentColor,
    this.borderWidth = 1,
    this.padding = const EdgeInsets.all(16),
  });

  /// Grey themed section (for LLM reasoning)
  factory DebugSection.grey({
    Key? key,
    required IconData icon,
    required String title,
    required String content,
    String? subtitle,
  }) {
    return DebugSection(
      key: key,
      icon: icon,
      title: title,
      content: content,
      subtitle: subtitle,
      backgroundColor: Colors.grey.shade100,
      borderColor: Colors.grey.shade300,
      iconColor: Colors.grey.shade600,
      titleColor: Colors.grey.shade700,
      contentColor: Colors.grey.shade800,
    );
  }

  /// Blue themed section (for extraction steps)
  factory DebugSection.blue({
    Key? key,
    required IconData icon,
    required String title,
    required String content,
    String? subtitle,
  }) {
    return DebugSection(
      key: key,
      icon: icon,
      title: title,
      content: content,
      subtitle: subtitle,
      backgroundColor: Colors.blue.shade50,
      borderColor: Colors.blue.shade200,
      iconColor: Colors.blue.shade600,
      titleColor: Colors.blue.shade700,
      contentColor: Colors.blue.shade900,
    );
  }

  /// Green themed section (for test results)
  factory DebugSection.green({
    Key? key,
    required IconData icon,
    required String title,
    required String content,
    String? subtitle,
  }) {
    return DebugSection(
      key: key,
      icon: icon,
      title: title,
      content: content,
      subtitle: subtitle,
      backgroundColor: Colors.green.shade50,
      borderColor: Colors.green.shade400,
      iconColor: Colors.green.shade700,
      titleColor: Colors.green.shade700,
      contentColor: Colors.green.shade900,
      borderWidth: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: titleColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const Divider(),
          Text(
            content,
            style: TextStyle(
              fontSize: 11,
              color: contentColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Confidence indicator widget showing extraction confidence level
class ConfidenceIndicator extends StatelessWidget {
  final double confidence;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const ConfidenceIndicator({
    super.key,
    required this.confidence,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.8
        ? Colors.green
        : confidence >= 0.6
            ? Colors.orange
            : Colors.red;

    final icon = confidence >= 0.8
        ? Icons.check_circle
        : confidence >= 0.6
            ? Icons.warning
            : Icons.error;

    final message = confidence >= 0.8
        ? 'High confidence - data looks accurate'
        : confidence >= 0.6
            ? 'Medium confidence - please verify'
            : 'Low confidence - manual review recommended';

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detection Confidence: ${(confidence * 100).toInt()}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
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

/// Editable data row with label and text field
class EditableDataRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool isAmount;
  final bool isHighlighted;
  final int labelFlex;
  final int valueFlex;
  final EdgeInsetsGeometry padding;

  const EditableDataRow({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.isAmount = false,
    this.isHighlighted = false,
    this.labelFlex = 2,
    this.valueFlex = 3,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: valueFlex,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              style: TextStyle(
                color: isHighlighted ? Colors.black : Colors.black87,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlighted ? 16 : 14,
              ),
              keyboardType: isAmount
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Document type display row with icon
class DocumentTypeRow extends StatelessWidget {
  final String documentType;
  final EdgeInsetsGeometry padding;
  final int labelFlex;
  final int valueFlex;

  const DocumentTypeRow({
    super.key,
    required this.documentType,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.labelFlex = 2,
    this.valueFlex = 3,
  });

  @override
  Widget build(BuildContext context) {
    // Determine icon and color based on document type
    final IconData icon;
    final Color color;
    final String displayText;

    switch (documentType.toLowerCase()) {
      case 'receipt':
        icon = Icons.receipt;
        color = Colors.green;
        displayText = 'Receipt';
        break;
      case 'invoice':
        icon = Icons.description;
        color = Colors.blue;
        displayText = 'Invoice';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        displayText = 'Unknown';
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              'Type',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: valueFlex,
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  displayText,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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

/// Tax breakdown display card (read-only)
class TaxBreakdownCard extends StatelessWidget {
  final double rate;
  final double taxAmount;
  final double? taxableAmount;
  final double? grossAmount;
  final String Function(double) formatAmount;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const TaxBreakdownCard({
    super.key,
    required this.rate,
    required this.taxAmount,
    this.taxableAmount,
    this.grossAmount,
    required this.formatAmount,
    this.margin = const EdgeInsets.symmetric(vertical: 4),
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tax rate header
          Row(
            children: [
              Icon(Icons.percent, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text(
                'VAT $rate%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              if (grossAmount != null)
                Text(
                  formatAmount(grossAmount!),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Details row
          Row(
            children: [
              if (taxableAmount != null) ...[
                Expanded(
                  child: Text(
                    'Net: ${formatAmount(taxableAmount!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  'Tax: ${formatAmount(taxAmount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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

/// Validation warning widget for displaying errors/warnings
class ValidationWarning extends StatelessWidget {
  final String message;
  final String title;
  final String? hint;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const ValidationWarning({
    super.key,
    required this.message,
    this.title = 'Calculation Error',
    this.hint,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    hint!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
