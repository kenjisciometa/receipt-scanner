import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/receipt_repository.dart';
import '../../services/auth_service.dart';

final receiptRepositoryProvider = Provider((ref) => ReceiptRepository());

final receiptsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(receiptRepositoryProvider);
  return repository.getReceipts();
});

final statisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(receiptRepositoryProvider);
  return repository.getStatistics();
});

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final receiptsAsync = ref.watch(receiptsProvider);
    final statsAsync = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(receiptsProvider);
          ref.invalidate(statisticsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info card
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                    ),
                  ),
                  title: Text(user?.email ?? 'Unknown'),
                  subtitle: const Text('Logged in'),
                ),
              ),
              const SizedBox(height: 24),

              // Statistics
              Text(
                'Statistics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              statsAsync.when(
                data: (stats) => Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Spent',
                        value: '€${stats['total_spent']?.toStringAsFixed(2) ?? '0.00'}',
                        icon: Icons.shopping_cart,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Tax',
                        value: '€${stats['total_tax']?.toStringAsFixed(2) ?? '0.00'}',
                        icon: Icons.receipt_long,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Receipts',
                        value: '${stats['receipt_count'] ?? 0}',
                        icon: Icons.format_list_numbered,
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // Receipt history
              Text(
                'Receipt History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              receiptsAsync.when(
                data: (receipts) {
                  if (receipts.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('No receipts yet. Scan your first receipt!'),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: receipts.length,
                    itemBuilder: (context, index) {
                      final receipt = receipts[index];
                      return _ReceiptCard(receipt: receipt);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading receipts: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
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

class _ReceiptCard extends ConsumerWidget {
  final Map<String, dynamic> receipt;

  const _ReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantName = receipt['merchant_name'] ?? 'Unknown';
    final total = receipt['total_amount'] as num?;
    final subtotal = receipt['subtotal_amount'] as num?;
    final tax = receipt['tax_amount'] as num?;
    final currency = receipt['currency'] ?? 'EUR';
    final taxBreakdown = receipt['tax_breakdown'] as List<dynamic>?;
    final purchaseDate = receipt['purchase_date'] != null
        ? DateTime.tryParse(receipt['purchase_date'])
        : null;
    final createdAt = receipt['created_at'] != null
        ? DateTime.parse(receipt['created_at'])
        : null;

    String currencySymbol = currency == 'EUR' ? '€' : currency;

    String formatDate(DateTime? date) {
      if (date == null) return 'Unknown date';
      return '${date.day}.${date.month}.${date.year}';
    }

    String formatTime(DateTime? date) {
      if (date == null) return '';
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const CircleAvatar(
          child: Icon(Icons.receipt),
        ),
        title: Text(merchantName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDate(purchaseDate ?? createdAt)),
            if (createdAt != null)
              Text(
                'Added: ${formatDate(createdAt)} ${formatTime(createdAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
        trailing: Text(
          '$currencySymbol${total?.toStringAsFixed(2) ?? '0.00'}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtotal != null)
                  _DetailRow(label: 'Subtotal', value: '$currencySymbol${subtotal.toStringAsFixed(2)}'),
                _DetailRow(label: 'Tax', value: '$currencySymbol${tax?.toStringAsFixed(2) ?? '0.00'}'),
                _DetailRow(
                  label: 'Total',
                  value: '$currencySymbol${total?.toStringAsFixed(2) ?? '0.00'}',
                  isBold: true,
                ),

                // Tax breakdown
                if (taxBreakdown != null && taxBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const Text('Tax Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...taxBreakdown.map((tax) {
                    final rate = tax['rate'];
                    final taxAmount = (tax['tax_amount'] as num?)?.toDouble();
                    final grossAmount = (tax['gross_amount'] as num?)?.toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$rate%', style: const TextStyle(fontSize: 13)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (grossAmount != null)
                                Text('Gross: $currencySymbol${grossAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                              Text(
                                'Tax: $currencySymbol${taxAmount?.toStringAsFixed(2) ?? '0.00'}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Delete button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context, ref),
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt?'),
        content: const Text('Are you sure you want to delete this receipt? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = ref.read(receiptRepositoryProvider);
        await repository.deleteReceipt(receipt['id']);
        ref.invalidate(receiptsProvider);
        ref.invalidate(statisticsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt deleted'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: isBold
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
          ),
        ],
      ),
    );
  }
}
