import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
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
            ? DateFormat('d MMM yyyy').format(_customSelectedDate!)
            : 'Select Date';
    }
  }

  void _showRecordPaymentDialog(BuildContext context, RecordProvider provider, String? adminEmail) {
    final controller = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Iconsax.wallet_add_1, color: Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Record Payout',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Unpaid Balance:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    Text(
                      NumberFormatter.formatCurrency(provider.userPayoutBalance),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0284C7), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Amount Paid (MWK)',
                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Iconsax.empty_wallet, size: 20, color: Color(0xFF0284C7)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  hintText: 'e.g. Weekly profit distribution',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.note_text, size: 20, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
                      backgroundColor: const Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm Payout', style: TextStyle(fontWeight: FontWeight.w700)),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Iconsax.wallet_3,
                color: Color(0xFF0284C7),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Money Records',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Revenue, Expenses & Profit Sharing',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Payout History',
            icon: const Icon(Iconsax.receipt_item, size: 20, color: Color(0xFF475569)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()),
            ),
          ),
        ],
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
            color: const Color(0xFF0284C7),
            onRefresh: () => provider.fetchRecords(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 96.0),
              children: [
                // 1. Balance to be Paid Hero Card
                _buildPayoutBalanceCard(context, provider, isAdmin, adminEmail),
                const SizedBox(height: 16),

                // 2. Filter Bar
                _buildFilterBar(),
                const SizedBox(height: 18),

                // 3. Period Financial Summary Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.chart_2, size: 17, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Text(
                          '${_getPeriodLabel(_selectedPeriod)} Financials',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${NumberFormatter.format(totalPages)} pages printed',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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

                // 5. Expected Profit Projections
                _buildExpectedProfitCard(provider),
                const SizedBox(height: 20),

                // 6. Individual Order Financial Breakdown List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.receipt_search, size: 16, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        Text(
                          'Order Breakdown (${NumberFormatter.format(filteredRecords.length)})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Rate: ${NumberFormatter.formatCurrency(config.pricePerPaper)}/pg',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Dark slate
            Color(0xFF065F46), // Deep emerald
            Color(0xFF059669), // Vivid mint/green
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Iconsax.empty_wallet_tick,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Profit Share Balance',
                          style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '50% Split',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              NumberFormatter.formatCurrency(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Earned: ${NumberFormatter.formatCurrency(totalUserShare)}',
                    style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Paid: ${NumberFormatter.formatCurrency(paidOut)}',
                    style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF065F46),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showRecordPaymentDialog(context, provider, adminEmail),
                      icon: const Icon(Iconsax.card_send, size: 18),
                      label: const Text(
                        'Record Payout',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()),
                    ),
                    icon: const Icon(Iconsax.clock, size: 16),
                    label: const Text(
                      'History',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
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
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()),
                  ),
                  icon: const Icon(Iconsax.clock, size: 18),
                  label: const Text(
                    'View Payout History',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
            child: InkWell(
              onTap: () {
                if (filter == MoneyPeriodFilter.custom) {
                  _pickCustomDate();
                } else {
                  setState(() {
                    _selectedPeriod = filter;
                    _customSelectedDate = null;
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (filter == MoneyPeriodFilter.custom) ...[
                      Icon(
                        Iconsax.calendar_1,
                        size: 14,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      _getPeriodLabel(filter),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
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
        // Revenue & Net Profit Cards Row
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Revenue',
                value: NumberFormatter.formatCurrency(totalAmountMade),
                subtitle: 'Gross sales billed',
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                icon: Iconsax.wallet_money,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Total Net Profit',
                value: NumberFormatter.formatCurrency(totalProfit),
                subtitle: 'Gross minus expenses',
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                icon: Iconsax.trend_up,
                isHighlight: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // My Profit (50% Share) Banner Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.percentage_circle, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Your Profit Share (50%)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF065F46),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Direct 50% split of shop profit',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                NumberFormatter.formatCurrency(myProfit),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF065F46),
                  letterSpacing: -0.3,
                ),
              ),
            ],
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
                icon: Iconsax.document_text,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallExpenseCard(
                title: 'Toner Ink',
                value: NumberFormatter.formatCurrency(totalTonerPrice),
                icon: Iconsax.colorfilter,
                color: const Color(0xFF4F46E5),
                bgColor: const Color(0xFFEEF2FF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallExpenseCard(
                title: 'Service Fee',
                value: NumberFormatter.formatCurrency(totalServiceFee),
                icon: Iconsax.setting_4,
                color: const Color(0xFF9333EA),
                bgColor: const Color(0xFFFAF5FF),
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
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.status_up, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Expected Profit Projections',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '50% Share',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasData
                ? 'Based on ${NumberFormatter.format(activeDays)} active day${activeDays == 1 ? '' : 's'} · avg ${NumberFormatter.formatCurrency(avgDaily)} net/day'
                : 'Add records to see profit projections',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 340;
              if (isSmall) {
                return Column(
                  children: [
                    _buildProjTile('Daily', daily, Iconsax.sun_1, const Color(0xFF60A5FA), isRow: true),
                    const SizedBox(height: 8),
                    _buildProjTile('Weekly', weekly, Iconsax.calendar_tick, const Color(0xFF34D399), isRow: true),
                    const SizedBox(height: 8),
                    _buildProjTile('Monthly', monthly, Iconsax.calendar_2, const Color(0xFFFBBF24), isRow: true),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildProjTile('Daily', daily, Iconsax.sun_1, const Color(0xFF60A5FA))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProjTile('Weekly', weekly, Iconsax.calendar_tick, const Color(0xFF34D399))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProjTile('Monthly', monthly, Iconsax.calendar_2, const Color(0xFFFBBF24))),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 8),
            Text(
              period,
              style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormatter.formatCurrency(amount),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800),
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
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            'your share',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9.5),
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
    required Color bgColor,
    required IconData icon,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isHighlight ? const Color(0xFF059669) : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallExpenseCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    record.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  NumberFormatter.formatCurrency(revenue),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${record.jobDescription} • ${NumberFormatter.format(pages)} pages • ${DateFormat('dd MMM, hh:mm a').format(record.timestamp)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
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
    Color valColor = const Color(0xFF334155);
    if (isProfit) valColor = const Color(0xFF0284C7);
    if (isShare) valColor = const Color(0xFF059669);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: (isProfit || isShare) ? FontWeight.w800 : FontWeight.w600,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.wallet_check,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No financial records for this period',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select another period filter or record a sale in POS.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
