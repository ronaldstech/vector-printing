import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/record_model.dart';
import '../../providers/record_provider.dart';
import '../records/record_details_screen.dart';
import '../../utils/number_formatter.dart';

enum ChartType { bar, line, pie }
enum AnalyticsPeriod { today, week, month, custom }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  ChartType _selectedChart = ChartType.bar;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.week;
  DateTime? _customSelectedDate;

  bool _matchesPeriod(DateTime timestamp) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case AnalyticsPeriod.today:
        return timestamp.year == now.year &&
            timestamp.month == now.month &&
            timestamp.day == now.day;
      case AnalyticsPeriod.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return timestamp.isAfter(start.subtract(const Duration(seconds: 1)));
      case AnalyticsPeriod.month:
        return timestamp.year == now.year && timestamp.month == now.month;
      case AnalyticsPeriod.custom:
        if (_customSelectedDate == null) return true;
        return timestamp.year == _customSelectedDate!.year &&
            timestamp.month == _customSelectedDate!.month &&
            timestamp.day == _customSelectedDate!.day;
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
        _selectedPeriod = AnalyticsPeriod.custom;
      });
    }
  }

  String _getPeriodLabel(AnalyticsPeriod p) {
    switch (p) {
      case AnalyticsPeriod.today:
        return 'Today';
      case AnalyticsPeriod.week:
        return 'This Week';
      case AnalyticsPeriod.month:
        return 'This Month';
      case AnalyticsPeriod.custom:
        return _customSelectedDate != null
            ? DateFormat('dd MMM yyyy').format(_customSelectedDate!)
            : 'Custom Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<RecordProvider>(
        builder: (context, provider, child) {
          // Filter records by active period
          final periodRecords = provider.records.where((r) => _matchesPeriod(r.timestamp)).toList();

          final totalSales = periodRecords.fold(0.0, (sum, r) => sum + r.totalAmount);
          final totalPaid = periodRecords.fold(0.0, (sum, r) => sum + r.paidAmount);
          final totalBalance = periodRecords.fold(0.0, (sum, r) => sum + r.balance);

          final totalOrders = periodRecords.length;
          final fullyPaidCount = periodRecords.where((r) => r.balance <= 0).length;
          final pendingCount = periodRecords.where((r) => r.balance > 0).length;

          final double collectionRate = totalSales > 0 ? (totalPaid / totalSales) * 100 : 0.0;
          final double avgOrderValue = totalOrders > 0 ? totalSales / totalOrders : 0.0;

          final debtors = periodRecords.where((r) => r.balance > 0).toList();

          return RefreshIndicator(
            onRefresh: () => provider.fetchRecords(),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 1. Period Selector Chips
                _buildPeriodFilterBar(),
                const SizedBox(height: 16),

                // 2. Chart Type Toggle & Visual Chart Card
                _buildChartSection(periodRecords),
                const SizedBox(height: 24),

                // 3. Collection & Health
                _buildSectionTitle(context, 'Collection & Efficiency'),
                const SizedBox(height: 12),
                _buildCollectionRateCard(context, collectionRate, totalPaid, totalSales),
                const SizedBox(height: 16),

                // 4. Key Metrics Grid
                _buildKeyMetricsGrid(context, totalOrders, avgOrderValue, fullyPaidCount, pendingCount),
                const SizedBox(height: 24),

                // 5. Financial Breakdown
                _buildSectionTitle(context, 'Period Financial Breakdown'),
                const SizedBox(height: 12),
                _buildFinancialBreakdownCard(context, totalSales, totalPaid, totalBalance),
                const SizedBox(height: 24),

                // 6. Expected User Profit Projections
                _buildSectionTitle(context, 'Expected User Profit Projections'),
                const SizedBox(height: 4),
                Text(
                  'Based on ${NumberFormatter.format(provider.activeDayCount)} active day${provider.activeDayCount == 1 ? '' : 's'} of data — avg ${NumberFormatter.formatCurrency(provider.avgDailyNetProfit)} net profit/day',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                _buildExpectedProfitSection(context, provider),
                const SizedBox(height: 24),

                // 6. Outstanding Balances / Debtors
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle(context, 'Period Outstanding Balances (${NumberFormatter.format(debtors.length)})'),
                    if (debtors.isNotEmpty)
                      Text(
                        'Total: ${NumberFormatter.formatCurrency(totalBalance)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (debtors.isEmpty)
                  _buildNoDebtCard(context)
                else
                  ...debtors.map((record) => _buildDebtorItem(context, record)),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Period Selector Bar ---
  Widget _buildPeriodFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AnalyticsPeriod.values.map((period) {
          final isSelected = _selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              avatar: period == AnalyticsPeriod.custom
                  ? Icon(
                      Icons.calendar_month,
                      size: 14,
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                    )
                  : null,
              label: Text(_getPeriodLabel(period)),
              selected: isSelected,
              onSelected: (_) {
                if (period == AnalyticsPeriod.custom) {
                  _pickCustomDate();
                } else {
                  setState(() => _selectedPeriod = period);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Interactive Chart Section (Bar, Line, Pie) ---
  Widget _buildChartSection(List<PrintingRecord> records) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sales Visualization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      _getPeriodLabel(_selectedPeriod),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                // Chart Type Toggle (Bar, Line, Pie)
                SegmentedButton<ChartType>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(value: ChartType.bar, icon: Icon(Icons.bar_chart, size: 18), label: Text('Bar', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: ChartType.line, icon: Icon(Icons.show_chart, size: 18), label: Text('Line', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: ChartType.pie, icon: Icon(Icons.pie_chart, size: 18), label: Text('Pie', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_selectedChart},
                  onSelectionChanged: (newSelection) {
                    setState(() => _selectedChart = newSelection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (records.isEmpty)
              Container(
                height: 180,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insert_chart_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('No data available for this period', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              )
            else
              _renderSelectedChart(records),
          ],
        ),
      ),
    );
  }

  Widget _renderSelectedChart(List<PrintingRecord> records) {
    switch (_selectedChart) {
      case ChartType.bar:
        return _buildBarChart(records);
      case ChartType.line:
        return _buildLineChart(records);
      case ChartType.pie:
        return _buildPieChart(records);
    }
  }

  // --- 1. Custom Bar Chart ---
  Widget _buildBarChart(List<PrintingRecord> records) {
    final Map<String, double> salesByGroup = _groupSalesData(records);
    final maxVal = salesByGroup.values.isEmpty ? 1.0 : salesByGroup.values.reduce(math.max);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: salesByGroup.entries.map((entry) {
              final heightFactor = maxVal > 0 ? (entry.value / maxVal).clamp(0.05, 1.0) : 0.05;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        entry.value >= 1000 ? '${(entry.value / 1000).toStringAsFixed(1)}k' : '${entry.value.toInt()}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 130 * heightFactor,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, primaryColor.withValues(alpha: 0.6)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.key,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.square, size: 10, color: Colors.blue),
            SizedBox(width: 4),
            Text('Sales Turnover (MWK)', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  // --- 2. Custom Line Chart ---
  Widget _buildLineChart(List<PrintingRecord> records) {
    final Map<String, double> salesByGroup = _groupSalesData(records);
    final values = salesByGroup.values.toList();
    final labels = salesByGroup.keys.toList();
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _LineChartPainter(
              values: values,
              labels: labels,
              lineColor: primaryColor,
              fillColor: primaryColor.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 14, color: Colors.blue),
            SizedBox(width: 4),
            Text('Revenue Trend Over Period', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  // --- 3. Custom Pie Chart ---
  Widget _buildPieChart(List<PrintingRecord> records) {
    // Breakdown by payment mode or payment status
    final cashSales = records.where((r) => r.paymentMode == 'Cash').fold(0.0, (s, r) => s + r.totalAmount);
    final airtelSales = records.where((r) => r.paymentMode == 'Airtel Money').fold(0.0, (s, r) => s + r.totalAmount);
    final tnmSales = records.where((r) => r.paymentMode == 'TNM Mpamba').fold(0.0, (s, r) => s + r.totalAmount);

    final total = cashSales + airtelSales + tnmSales;
    final List<Map<String, dynamic>> slices = [
      {'label': 'Cash', 'value': cashSales, 'color': Colors.green},
      {'label': 'Airtel Money', 'value': airtelSales, 'color': Colors.red},
      {'label': 'TNM Mpamba', 'value': tnmSales, 'color': Colors.blue},
    ].where((item) => (item['value'] as double) > 0).toList();

    if (slices.isEmpty) {
      slices.add({'label': 'Sales', 'value': total > 0 ? total : 1.0, 'color': Colors.blue});
    }

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _PieChartPainter(slices: slices),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: slices.map((s) {
              final double pct = total > 0 ? ((s['value'] as double) / total) * 100 : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: s['color'] as Color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${s['label']}: ${pct.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- Helper to Group Data by Days / Time Buckets ---
  Map<String, double> _groupSalesData(List<PrintingRecord> records) {
    final Map<String, double> result = {};

    if (_selectedPeriod == AnalyticsPeriod.today) {
      // Group by hours
      for (var h = 8; h <= 18; h += 2) {
        result['${h}h'] = 0.0;
      }
      for (var r in records) {
        final hour = r.timestamp.hour;
        final key = '${(hour ~/ 2) * 2}h';
        result[key] = (result[key] ?? 0.0) + r.totalAmount;
      }
    } else if (_selectedPeriod == AnalyticsPeriod.week) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (var d in days) {
        result[d] = 0.0;
      }
      for (var r in records) {
        final dayIndex = r.timestamp.weekday - 1;
        if (dayIndex >= 0 && dayIndex < 7) {
          final dayName = days[dayIndex];
          result[dayName] = (result[dayName] ?? 0.0) + r.totalAmount;
        }
      }
    } else {
      // Group by weeks or 5-day intervals
      for (var r in records) {
        final dateKey = DateFormat('dd MMM').format(r.timestamp);
        result[dateKey] = (result[dateKey] ?? 0.0) + r.totalAmount;
      }
      if (result.isEmpty) {
        result['No sales'] = 0.0;
      }
    }

    return result;
  }

  // --- Existing Metric & Breakdown Widgets ---
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildCollectionRateCard(BuildContext context, double rate, double paid, double sales) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cash Collection Efficiency', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: rate >= 80 ? Colors.green : (rate >= 50 ? Colors.orange : Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: sales > 0 ? (paid / sales).clamp(0.0, 1.0) : 0.0,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  rate >= 80 ? Colors.green : (rate >= 50 ? Colors.orange : Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${NumberFormatter.formatCurrency(paid)} collected out of ${NumberFormatter.formatCurrency(sales)} billed',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsGrid(
    BuildContext context,
    int totalOrders,
    double avgOrderValue,
    int fullyPaidCount,
    int pendingCount,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _buildMetricTile(
          context,
          icon: Icons.receipt_long,
          color: Colors.blue,
          label: 'Total Orders',
          value: NumberFormatter.format(totalOrders),
        ),
        _buildMetricTile(
          context,
          icon: Icons.trending_up,
          color: Colors.purple,
          label: 'Avg Order Value',
          value: NumberFormatter.formatCurrency(avgOrderValue),
        ),
        _buildMetricTile(
          context,
          icon: Icons.check_circle_outline,
          color: Colors.green,
          label: 'Fully Paid Orders',
          value: NumberFormatter.format(fullyPaidCount),
        ),
        _buildMetricTile(
          context,
          icon: Icons.pending_actions,
          color: Colors.orange,
          label: 'Pending Debt Orders',
          value: NumberFormatter.format(pendingCount),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialBreakdownCard(
    BuildContext context,
    double totalSales,
    double totalPaid,
    double totalBalance,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFinanceRow('Total Invoiced', NumberFormatter.formatCurrency(totalSales), Colors.black87),
            const Divider(),
            _buildFinanceRow('Cash Received', NumberFormatter.formatCurrency(totalPaid), Colors.green.shade700),
            const Divider(),
            _buildFinanceRow('Uncollected Debt', NumberFormatter.formatCurrency(totalBalance), Colors.red.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDebtorItem(BuildContext context, dynamic record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade100),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade50,
          child: Icon(Icons.person, color: Colors.red.shade700),
        ),
        title: Text(record.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${record.jobDescription} • Total: ${NumberFormatter.formatCurrency(record.totalAmount)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Owes ${NumberFormatter.formatCurrency(record.balance)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14),
            ),
            const Text('Tap to inspect', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordDetailsScreen(record: record),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoDebtCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 36),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Debts Settled!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('There are no outstanding balances for this period.', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildExpectedProfitSection(BuildContext context, RecordProvider provider) {
    final hasData = provider.records.isNotEmpty;
    final dailyUser = provider.expectedDailyUserProfit;
    final weeklyUser = provider.expectedWeeklyUserProfit;
    final monthlyUser = provider.expectedMonthlyUserProfit;
    final dailyNet = provider.expectedDailyNetProfit;
    final weeklyNet = provider.expectedWeeklyNetProfit;
    final monthlyNet = provider.expectedMonthlyNetProfit;

    if (!hasData) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.auto_graph, color: Colors.grey.shade400, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'No records yet — projections will appear once the first print job is added.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Main gradient projection card
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.30),
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
                  const Icon(Icons.auto_graph, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your Projected Profit Share (50%)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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
              const SizedBox(height: 16),

              // Projections (responsive: column on small screens, row on wider screens)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 340;
                  if (isSmall) {
                    return Column(
                      children: [
                        _buildProjectionTile(
                          period: 'Per Day',
                          userAmount: dailyUser,
                          totalAmount: dailyNet,
                          icon: Icons.wb_sunny_outlined,
                          accent: const Color(0xFF60A5FA),
                          isRow: true,
                        ),
                        const SizedBox(height: 8),
                        _buildProjectionTile(
                          period: 'Per Week',
                          userAmount: weeklyUser,
                          totalAmount: weeklyNet,
                          icon: Icons.date_range_outlined,
                          accent: const Color(0xFF34D399),
                          isRow: true,
                        ),
                        const SizedBox(height: 8),
                        _buildProjectionTile(
                          period: 'Per Month',
                          userAmount: monthlyUser,
                          totalAmount: monthlyNet,
                          icon: Icons.calendar_month_outlined,
                          accent: const Color(0xFFFBBF24),
                          isRow: true,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: _buildProjectionTile(
                          period: 'Per Day',
                          userAmount: dailyUser,
                          totalAmount: dailyNet,
                          icon: Icons.wb_sunny_outlined,
                          accent: const Color(0xFF60A5FA),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildProjectionTile(
                          period: 'Per Week',
                          userAmount: weeklyUser,
                          totalAmount: weeklyNet,
                          icon: Icons.date_range_outlined,
                          accent: const Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildProjectionTile(
                          period: 'Per Month',
                          userAmount: monthlyUser,
                          totalAmount: monthlyNet,
                          icon: Icons.calendar_month_outlined,
                          accent: const Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Disclaimer
              Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Projections are based on your historical average profit per active business day.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Secondary row: business net profit reference
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.store_outlined, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Total Business Net Profit Projections',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildSimpleStat('Daily', dailyNet, Colors.blue.shade700)),
                    Expanded(child: _buildSimpleStat('Weekly', weeklyNet, Colors.green.shade700)),
                    Expanded(child: _buildSimpleStat('Monthly', monthlyNet, Colors.orange.shade700)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectionTile({
    required String period,
    required double userAmount,
    required double totalAmount,
    required IconData icon,
    required Color accent,
    bool isRow = false,
  }) {
    if (isRow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormatter.formatCurrency(userAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'your share (total: ${NumberFormatter.formatCurrency(totalAmount)})',
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              NumberFormatter.formatCurrency(userAmount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'your share',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            NumberFormatter.formatCurrency(value),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

}
// ==========================================
// Custom Painters for Line & Pie Charts
// ==========================================

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color fillColor;

  _LineChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double maxVal = values.reduce(math.max);
    final double safeMax = maxVal == 0 ? 1.0 : maxVal;
    final double stepX = values.length > 1 ? size.width / (values.length - 1) : size.width;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    List<Offset> points = [];

    for (int i = 0; i < values.length; i++) {
      final x = values.length > 1 ? i * stepX : size.width / 2;
      final y = size.height - (values[i] / safeMax * (size.height - 40)) - 25;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height - 20);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    if (points.isNotEmpty) {
      fillPath.lineTo(points.last.dx, size.height - 20);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    // Draw dots and bottom labels
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4.5, dotPaint);

      if (i < labels.length) {
        textPainter.text = TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.black54, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(points[i].dx - (textPainter.width / 2), size.height - 15),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

class _PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> slices;

  _PieChartPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = slices.fold(0.0, (s, item) => s + (item['value'] as double));
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.2;

    double startAngle = -math.pi / 2;

    for (var slice in slices) {
      final sweepAngle = ((slice['value'] as double) / total) * 2 * math.pi;
      final paint = Paint()
        ..color = slice['color'] as Color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Inner hole for a donut style
    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => true;
}
