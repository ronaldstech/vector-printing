import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/record_model.dart';
import '../../models/app_config_model.dart';
import '../../providers/record_provider.dart';
import '../../services/auth_service.dart';
import 'payout_history_screen.dart';
import '../../utils/number_formatter.dart';

enum MoneyPeriodFilter { today, week, month, all, custom }

class MoneyRecordsScreen extends StatefulWidget {
  const MoneyRecordsScreen({super.key});

  @override
  State<MoneyRecordsScreen> createState() => _MoneyRecordsScreenState();
}

class _MoneyRecordsScreenState extends State<MoneyRecordsScreen> {
  MoneyPeriodFilter _selectedPeriod = MoneyPeriodFilter.today;
  DateTime? _customSelectedDate;

  bool _matchesPeriod(DateTime timestamp) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case MoneyPeriodFilter.today:
        return timestamp.year == now.year &&
            timestamp.month == now.month &&
            timestamp.day == now.day;
      case MoneyPeriodFilter.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return timestamp.isAfter(start.subtract(const Duration(seconds: 1)));
      case MoneyPeriodFilter.month:
        return timestamp.year == now.year && timestamp.month == now.month;
      case MoneyPeriodFilter.custom:
        if (_customSelectedDate == null) return true;
        return timestamp.year == _customSelectedDate!.year &&
            timestamp.month == _customSelectedDate!.month &&
            timestamp.day == _customSelectedDate!.day;
      case MoneyPeriodFilter.all:
        return true;
    }
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _customSelectedDate = picked;
        _selectedPeriod = MoneyPeriodFilter.custom;
      });
    }
  }

  String _getPeriodLabel(MoneyPeriodFilter filter) {
    switch (filter) {
      case MoneyPeriodFilter.today:
        return 'Today';
      case MoneyPeriodFilter.week:
        return 'This Week';
      case MoneyPeriodFilter.month:
        return 'This Month';
      case MoneyPeriodFilter.all:
        return 'All Time';
      case MoneyPeriodFilter.custom:
        return _customSelectedDate != null
            ? DateFormat('dd MMM yyyy').format(_customSelectedDate!)
            : 'Custom Date';
    }
  }

  void _showRecordPaymentDialog(BuildContext context, RecordProvider provider, String? adminEmail) {
    final controller = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payments, color: Colors.teal),
            SizedBox(width: 8),
            Text('Record Payment to User', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current user balance to be paid: ${NumberFormatter.formatCurrency(provider.userPayoutBalance)}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the amount of profit share handed over to the user. This will be subtracted from the remaining balance.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Amount Paid to User',
                  prefixText: 'MWK ',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter an amount';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Enter a positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Weekly profit payment',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final amount = double.parse(controller.text.trim());
                final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
                Navigator.pop(ctx);
                await provider.recordPayoutToUser(
                  amount,
                  note: note,
                  recordedBy: adminEmail,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Recorded ${NumberFormatter.formatCurrency(amount)} paid to user!'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              }
            },
            child: const Text('Record Payout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final isAdmin = auth.isAdmin;
    final adminEmail = auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Records', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<RecordProvider>(
        builder: (context, provider, child) {
          final config = provider.config;
          final filteredRecords = provider.records.where((r) => _matchesPeriod(r.timestamp)).toList();

          // Calculate period metrics
          final int totalPages = filteredRecords.fold(0, (sum, r) => sum + r.quantity);
          final double totalAmountMade = filteredRecords.fold(0.0, (sum, r) => sum + r.totalAmount);
          final double totalTonerPrice = totalPages * config.inkPricePerPaper;
          final double totalPaperPrice = totalPages * config.buyingPricePerPaper;
          final double totalServiceFee = totalPages * config.serviceFeePerPaper;
          final double totalExpenses = totalTonerPrice + totalPaperPrice + totalServiceFee;
          final double totalProfit = totalAmountMade - totalExpenses;
          final double myProfit = totalProfit * 0.50;

          return RefreshIndicator(
            onRefresh: () => provider.fetchRecords(),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 1. Balance to be Paid Card (Prominently featured at the top)
                _buildPayoutBalanceCard(context, provider, isAdmin, adminEmail),
                const SizedBox(height: 16),

                // 2. Filter Bar (Today, Week, Month, All, Custom)
                _buildFilterBar(),
                const SizedBox(height: 16),

                // 3. Period Financial Summary Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_getPeriodLabel(_selectedPeriod)} Financials',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$totalPages pages printed',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4. Financial Metric Cards Grid
                _buildFinancialGrid(
                  totalAmountMade: totalAmountMade,
                  totalTonerPrice: totalTonerPrice,
                  totalPaperPrice: totalPaperPrice,
                  totalServiceFee: totalServiceFee,
                  totalProfit: totalProfit,
                  myProfit: myProfit,
                ),
                const SizedBox(height: 16),

                // 5. Expected Profit Projections (all users)
                _buildExpectedProfitCard(provider),
                const SizedBox(height: 20),

                // 5. Individual Order Financial Breakdown List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Breakdown (${NumberFormatter.format(filteredRecords.length)})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Price: ${NumberFormatter.formatCurrency(config.pricePerPaper)}/pg',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (filteredRecords.isEmpty)
                  _buildEmptyState()
                else
                  ...filteredRecords.map((record) => _buildOrderMoneyCard(record, config)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPayoutBalanceCard(BuildContext context, RecordProvider provider, bool isAdmin, String? adminEmail) {
    final balance = provider.userPayoutBalance;
    final totalUserShare = provider.totalUserProfitShare;
    final paidOut = provider.totalPaidOutToUser;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F766E), // Deep Teal
              const Color(0xFF14B8A6), // Bright Teal
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'User Profit Balance to be Paid',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '50% Share',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              NumberFormatter.formatCurrency(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Earned: ${NumberFormatter.formatCurrency(totalUserShare)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  'Already Paid: ${NumberFormatter.formatCurrency(paidOut)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showRecordPaymentDialog(context, provider, adminEmail),
                      icon: const Icon(Icons.handshake_outlined, size: 18),
                      label: const Text(
                        'Record Payout',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()),
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('History'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()),
                  ),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text(
                    'View Payout History',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MoneyPeriodFilter.values.map((filter) {
          final isSelected = _selectedPeriod == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              avatar: filter == MoneyPeriodFilter.custom
                  ? Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                    )
                  : null,
              label: Text(_getPeriodLabel(filter)),
              selected: isSelected,
              onSelected: (_) {
                if (filter == MoneyPeriodFilter.custom) {
                  _pickCustomDate();
                } else {
                  setState(() => _selectedPeriod = filter);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFinancialGrid({
    required double totalAmountMade,
    required double totalTonerPrice,
    required double totalPaperPrice,
    required double totalServiceFee,
    required double totalProfit,
    required double myProfit,
  }) {
    return Column(
      children: [
        // Revenue & Net Profit Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Amount Made',
                value: NumberFormatter.formatCurrency(totalAmountMade),
                subtitle: 'Gross Customer Revenue',
                color: Colors.blue.shade700,
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Total Profit',
                value: NumberFormatter.formatCurrency(totalProfit),
                subtitle: 'Gross - All Expenses',
                color: Colors.teal.shade800,
                icon: Icons.trending_up,
                isHighlight: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // My Profit (50% Share) Card
        Card(
          elevation: 1.5,
          color: const Color(0xFFF0FDF4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.green.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  radius: 18,
                  child: const Icon(Icons.pie_chart_outline, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Profit (50%)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '50% of Total Profit',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  NumberFormatter.formatCurrency(myProfit),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 3 Expense Cards: Paper, Toner, Service Fee
        Row(
          children: [
            Expanded(
              child: _buildSmallExpenseCard(
                title: 'Paper Cost',
                value: NumberFormatter.formatCurrency(totalPaperPrice),
                icon: Icons.description_outlined,
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallExpenseCard(
                title: 'Toner Price',
                value: NumberFormatter.formatCurrency(totalTonerPrice),
                icon: Icons.format_color_fill,
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallExpenseCard(
                title: 'Service Fee',
                value: NumberFormatter.formatCurrency(totalServiceFee),
                icon: Icons.build_circle_outlined,
                color: Colors.purple.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpectedProfitCard(RecordProvider provider) {
    final hasData = provider.records.isNotEmpty;
    final daily = provider.expectedDailyUserProfit;
    final weekly = provider.expectedWeeklyUserProfit;
    final monthly = provider.expectedMonthlyUserProfit;
    final avgDaily = provider.avgDailyNetProfit;
    final activeDays = provider.activeDayCount;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Colors.white70, size: 17),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Expected Profit (Your 50% Share)',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Forecast',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasData
                ? 'Based on ${NumberFormatter.format(activeDays)} active day${activeDays == 1 ? '' : 's'} — avg ${NumberFormatter.formatCurrency(avgDaily)} net/day'
                : 'Add records to see profit projections',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 340;
              if (isSmall) {
                return Column(
                  children: [
                    _buildProjTile('Per Day', daily, Icons.wb_sunny_outlined, const Color(0xFF60A5FA), isRow: true),
                    const SizedBox(height: 8),
                    _buildProjTile('Per Week', weekly, Icons.date_range_outlined, const Color(0xFF34D399), isRow: true),
                    const SizedBox(height: 8),
                    _buildProjTile('Per Month', monthly, Icons.calendar_month_outlined, const Color(0xFFFBBF24), isRow: true),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildProjTile('Per Day', daily, Icons.wb_sunny_outlined, const Color(0xFF60A5FA))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProjTile('Per Week', weekly, Icons.date_range_outlined, const Color(0xFF34D399))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProjTile('Per Month', monthly, Icons.calendar_month_outlined, const Color(0xFFFBBF24))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProjTile(String period, double amount, IconData icon, Color accent, {bool isRow = false}) {
    if (isRow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 8),
            Text(
              period,
              style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormatter.formatCurrency(amount),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'your share',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              NumberFormatter.formatCurrency(amount),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            'your share',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    bool isHighlight = false,
  }) {
    return Card(
      elevation: isHighlight ? 2 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallExpenseCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderMoneyCard(PrintingRecord record, AppConfig config) {
    final int pages = record.quantity;
    final double revenue = record.totalAmount;
    final double tonerCost = (pages * config.inkPricePerPaper).toDouble();
    final double paperCost = (pages * config.buyingPricePerPaper).toDouble();
    final double serviceCost = (pages * config.serviceFeePerPaper).toDouble();
    final double totalCost = tonerCost + paperCost + serviceCost;
    final double orderProfit = revenue - totalCost;
    final double userShare = orderProfit * 0.50;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    record.customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  NumberFormatter.formatCurrency(revenue),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${record.jobDescription} • ${NumberFormatter.format(pages)} pages • ${DateFormat('dd MMM, hh:mm a').format(record.timestamp)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const Divider(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildOrderMiniStat('Paper', NumberFormatter.formatCurrency(paperCost)),
                  const SizedBox(width: 14),
                  _buildOrderMiniStat('Toner', NumberFormatter.formatCurrency(tonerCost)),
                  const SizedBox(width: 14),
                  _buildOrderMiniStat('Service', NumberFormatter.formatCurrency(serviceCost)),
                  const SizedBox(width: 14),
                  _buildOrderMiniStat('Net Profit', NumberFormatter.formatCurrency(orderProfit), isProfit: true),
                  const SizedBox(width: 14),
                  _buildOrderMiniStat('50% Share', NumberFormatter.formatCurrency(userShare), isShare: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderMiniStat(String label, String value, {bool isProfit = false, bool isShare = false}) {
    Color valColor = Colors.black87;
    if (isProfit) valColor = Colors.teal.shade800;
    if (isShare) valColor = Colors.green.shade800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: (isProfit || isShare) ? FontWeight.bold : FontWeight.w500,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Icon(Icons.monetization_on_outlined, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            const Text('No records for this period', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Select another period filter or record a sale in POS.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
