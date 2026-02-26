import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'history_screen.dart';
import 'invoice_history_screen.dart';

/// Combined history screen with tabs for Receipts and Invoices
class CombinedHistoryScreen extends ConsumerStatefulWidget {
  /// Optional invoice ID to highlight (auto-switches to Invoices tab)
  final String? highlightInvoiceId;

  const CombinedHistoryScreen({
    super.key,
    this.highlightInvoiceId,
  });

  @override
  ConsumerState<CombinedHistoryScreen> createState() => _CombinedHistoryScreenState();
}

class _CombinedHistoryScreenState extends ConsumerState<CombinedHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Start on Invoices tab (index 1) if highlighting an invoice
    final initialIndex = widget.highlightInvoiceId != null ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.receipt_long),
              text: 'Receipts',
            ),
            Tab(
              icon: Icon(Icons.description),
              text: 'Invoices',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _ReceiptsTab(),
          _InvoicesTab(highlightInvoiceId: widget.highlightInvoiceId),
        ],
      ),
    );
  }
}

/// Receipts tab content (extracted from HistoryScreen)
class _ReceiptsTab extends ConsumerStatefulWidget {
  const _ReceiptsTab();

  @override
  ConsumerState<_ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends ConsumerState<_ReceiptsTab> {
  String _selectedFilter = 'All';
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(receiptsProvider);
      ref.invalidate(statisticsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(receiptsProvider);
    final statsAsync = ref.watch(statisticsProvider);

    return RefreshIndicator(
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
            const SizedBox(height: 8),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...['All', 'Today', 'Yesterday', 'Last 7 days', 'This month'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = filter;
                            _customDateRange = null;
                          });
                        },
                      ),
                    );
                  }),
                  // Custom date range chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_customDateRange != null
                          ? '${_customDateRange!.start.day}.${_customDateRange!.start.month} - ${_customDateRange!.end.day}.${_customDateRange!.end.month}'
                          : 'Custom'),
                      selected: _selectedFilter == 'Custom',
                      onSelected: (selected) async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: _customDateRange,
                        );
                        if (range != null) {
                          setState(() {
                            _selectedFilter = 'Custom';
                            _customDateRange = range;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
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
                final filtered = _filterByDate(receipts, _selectedFilter);
                if (filtered.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('No receipts added $_selectedFilter'.toLowerCase()),
                      ),
                    ),
                  );
                }
                return Column(
                  children: filtered.map((receipt) => ReceiptCard(receipt: receipt)).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading receipts: $e'),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterByDate(List<Map<String, dynamic>> items, String filter) {
    if (filter == 'All') return items;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7Days = today.subtract(const Duration(days: 7));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    return items.where((item) {
      final createdAt = item['created_at'] != null
          ? DateTime.tryParse(item['created_at'])
          : null;
      if (createdAt == null) return false;
      final addedDay = DateTime(createdAt.year, createdAt.month, createdAt.day);

      switch (filter) {
        case 'Today':
          return addedDay == today;
        case 'Yesterday':
          return addedDay == yesterday;
        case 'Last 7 days':
          return addedDay.isAfter(last7Days) || addedDay == last7Days;
        case 'This month':
          return addedDay.isAfter(thisMonthStart) || addedDay == thisMonthStart;
        case 'Custom':
          if (_customDateRange == null) return true;
          final rangeStart = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          final rangeEnd = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day);
          return (addedDay.isAfter(rangeStart) || addedDay == rangeStart) &&
                 (addedDay.isBefore(rangeEnd) || addedDay == rangeEnd);
        default:
          return true;
      }
    }).toList();
  }
}

/// Invoices tab content (extracted from InvoiceHistoryScreen)
class _InvoicesTab extends ConsumerStatefulWidget {
  /// Optional invoice ID to highlight and auto-expand
  final String? highlightInvoiceId;

  const _InvoicesTab({this.highlightInvoiceId});

  @override
  ConsumerState<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends ConsumerState<_InvoicesTab> {
  String _selectedFilter = 'All';
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(invoicesProvider);
      ref.invalidate(invoiceStatisticsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final statsAsync = ref.watch(invoiceStatisticsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(invoicesProvider);
        ref.invalidate(invoiceStatisticsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      title: 'Total',
                      value: '€${stats['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
                      icon: Icons.euro,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Tax',
                      value: '€${stats['total_tax']?.toStringAsFixed(2) ?? '0.00'}',
                      icon: Icons.receipt_long,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Invoices',
                      value: '${stats['invoice_count'] ?? 0}',
                      icon: Icons.description,
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),

            // Invoice history
            Text(
              'Invoice History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            // Date filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...['All', 'Today', 'Last 7 days', 'This month'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = filter;
                            _customDateRange = null;
                          });
                        },
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_customDateRange != null
                          ? '${_customDateRange!.start.day}.${_customDateRange!.start.month} - ${_customDateRange!.end.day}.${_customDateRange!.end.month}'
                          : 'Custom'),
                      selected: _selectedFilter == 'Custom',
                      onSelected: (selected) async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _customDateRange,
                        );
                        if (range != null) {
                          setState(() {
                            _selectedFilter = 'Custom';
                            _customDateRange = range;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            invoicesAsync.when(
              data: (invoices) {
                if (invoices.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No invoices yet. Scan your first invoice!'),
                      ),
                    ),
                  );
                }
                final filtered = _filterByDate(invoices, _selectedFilter);

                if (filtered.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No invoices match the selected filters'),
                      ),
                    ),
                  );
                }
                return Column(
                  children: filtered.map((invoice) => InvoiceCard(
                    invoice: invoice,
                    initiallyExpanded: invoice['id'] == widget.highlightInvoiceId,
                    isHighlighted: invoice['id'] == widget.highlightInvoiceId,
                  )).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading invoices: $e'),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterByDate(List<Map<String, dynamic>> items, String filter) {
    if (filter == 'All') return items;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last7Days = today.subtract(const Duration(days: 7));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    return items.where((item) {
      final createdAt = item['created_at'] != null
          ? DateTime.tryParse(item['created_at'])
          : null;
      if (createdAt == null) return false;
      final addedDay = DateTime(createdAt.year, createdAt.month, createdAt.day);

      switch (filter) {
        case 'Today':
          return addedDay == today;
        case 'Last 7 days':
          return addedDay.isAfter(last7Days) || addedDay == last7Days;
        case 'This month':
          return addedDay.isAfter(thisMonthStart) || addedDay == thisMonthStart;
        case 'Custom':
          if (_customDateRange == null) return true;
          final rangeStart = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          final rangeEnd = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day);
          return (addedDay.isAfter(rangeStart) || addedDay == rangeStart) &&
                 (addedDay.isBefore(rangeEnd) || addedDay == rangeEnd);
        default:
          return true;
      }
    }).toList();
  }
}

/// Simple stat card widget
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
            Icon(icon, size: 24, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
