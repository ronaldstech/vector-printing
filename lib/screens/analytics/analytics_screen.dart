import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
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
            ? DateFormat('d MMM yyyy').format(_customSelectedDate!)
            : 'Select Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: colorScheme.outlineVariant, height: 1),
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
                Iconsax.chart_21,
                color: Color(0xFF0284C7),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Sales Metrics, Trends & Forecasts',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
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
            color: const Color(0xFF0284C7),
            onRefresh: () => provider.fetchRecords(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 96.0),
              children: [
                // 1. Period Selector Capsules
                _buildPeriodFilterBar(context),
                const SizedBox(height: 16),

                // 2. Chart Section with Interactive Toggle
                _buildChartSection(context, periodRecords),
                const SizedBox(height: 20),

                // 3. Collection & Health Efficiency
                _buildSectionHeader(context, 'Cash Flow Efficiency', Iconsax.activity),
                const SizedBox(height: 10),
                _buildCollectionRateCard(context, collectionRate, totalPaid, totalSales),
                const SizedBox(height: 20),

                // 4. Key Metrics Grid
                _buildSectionHeader(context, 'Performance Highlights', Iconsax.flash_1),
                const SizedBox(height: 10),
                _buildKeyMetricsGrid(context, totalOrders, avgOrderValue, fullyPaidCount, pendingCount),
                const SizedBox(height: 20),

                // 5. Financial Breakdown
                _buildSectionHeader(context, 'Financial Overview', Iconsax.moneys),
                const SizedBox(height: 10),
                _buildFinancialBreakdownCard(context, totalSales, totalPaid, totalBalance),
                const SizedBox(height: 20),

                // 6. Expected User Profit Projections
                _buildSectionHeader(context, 'Expected Profit Projections', Iconsax.status_up),
                const SizedBox(height: 4),
                Text(
                  'Based on ${NumberFormatter.format(provider.activeDayCount)} active day${provider.activeDayCount == 1 ? '' : 's'} · avg ${NumberFormatter.formatCurrency(provider.avgDailyNetProfit)} net profit/day',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                _buildExpectedProfitSection(context, provider),
                const SizedBox(height: 20),

                // 7. Outstanding Balances / Debtors
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader(context, 'Outstanding Debtors (${NumberFormatter.format(debtors.length)})', Iconsax.profile_delete),
                    if (debtors.isNotEmpty)
                      Text(
                        'Total: ${NumberFormatter.formatCurrency(totalBalance)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626), fontSize: 13),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
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

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF0284C7)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // --- Period Selector Bar ---
  Widget _buildPeriodFilterBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AnalyticsPeriod.values.map((period) {
          final isSelected = _selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () {
                if (period == AnalyticsPeriod.custom) {
                  _pickCustomDate();
                } else {
                  setState(() {
                    _selectedPeriod = period;
                    _customSelectedDate = null;
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
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
                    if (period == AnalyticsPeriod.custom) ...[
                      Icon(
                        Iconsax.calendar_1,
                        size: 14,
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      _getPeriodLabel(period),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
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

  // --- Interactive Chart Section ---
  Widget _buildChartSection(BuildContext context, List<PrintingRecord> records) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18.0),
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
                  Text(
                    'Revenue Trajectory',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: colorScheme.onSurface),
                  ),
                  Text(
                    _getPeriodLabel(_selectedPeriod),
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              // Chart Type Toggle Pills
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildChartToggleItem(context, ChartType.bar, Iconsax.chart_2, 'Bar'),
                    _buildChartToggleItem(context, ChartType.line, Iconsax.graph, 'Line'),
                    _buildChartToggleItem(context, ChartType.pie, Iconsax.chart_21, 'Pie'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (records.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.chart_fail, size: 40, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text(
                    'No data available for this period',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            _renderSelectedChart(context, records),
        ],
      ),
    );
  }

  Widget _buildChartToggleItem(BuildContext context, ChartType type, IconData icon, String label) {
    final isSelected = _selectedChart == type;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _selectedChart = type),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderSelectedChart(BuildContext context, List<PrintingRecord> records) {
    switch (_selectedChart) {
      case ChartType.bar:
        return _buildBarChart(context, records);
      case ChartType.line:
        return _buildLineChart(context, records);
      case ChartType.pie:
        return _buildPieChart(context, records);
    }
  }

  // --- 1. Custom Bar Chart ---
  Widget _buildBarChart(BuildContext context, List<PrintingRecord> records) {
    final colorScheme = Theme.of(context).colorScheme;
    final Map<String, double> salesByGroup = _groupSalesData(records);
    final maxVal = salesByGroup.values.isEmpty ? 1.0 : salesByGroup.values.reduce(math.max);

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
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 130 * heightFactor,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.key,
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.record, size: 10, color: Color(0xFF0284C7)),
            SizedBox(width: 5),
            Text('Turnover (MWK)', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  // --- 2. Custom Line Chart ---
  Widget _buildLineChart(BuildContext context, List<PrintingRecord> records) {
    final colorScheme = Theme.of(context).colorScheme;
    final Map<String, double> salesByGroup = _groupSalesData(records);
    final values = salesByGroup.values.toList();
    final labels = salesByGroup.keys.toList();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: CustomPaint(
            size: const Size(double.infinity, 180),
            painter: _LineChartPainter(
              values: values,
              labels: labels,
              lineColor: const Color(0xFF0284C7),
              fillColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.activity, size: 13, color: Color(0xFF0284C7)),
            SizedBox(width: 5),
            Text('Trend Curve Across Timeline', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  // --- 3. Custom Pie Chart ---
  Widget _buildPieChart(BuildContext context, List<PrintingRecord> records) {
    final colorScheme = Theme.of(context).colorScheme;
    final cashSales = records.where((r) => r.paymentMode == 'Cash').fold(0.0, (s, r) => s + r.totalAmount);
    final airtelSales = records.where((r) => r.paymentMode == 'Airtel Money').fold(0.0, (s, r) => s + r.totalAmount);
    final tnmSales = records.where((r) => r.paymentMode == 'TNM Mpamba').fold(0.0, (s, r) => s + r.totalAmount);
    final bankSales = records.where((r) => r.paymentMode == 'Bank').fold(0.0, (s, r) => s + r.totalAmount);

    final total = cashSales + airtelSales + tnmSales + bankSales;
    final List<Map<String, dynamic>> slices = [
      {'label': 'Cash', 'value': cashSales, 'color': const Color(0xFF059669)},
      {'label': 'Airtel Money', 'value': airtelSales, 'color': const Color(0xFFDC2626)},
      {'label': 'TNM Mpamba', 'value': tnmSales, 'color': const Color(0xFF0284C7)},
      {'label': 'Bank', 'value': bankSales, 'color': const Color(0xFF8B5CF6)},
    ].where((item) => (item['value'] as double) > 0).toList();

    if (slices.isEmpty) {
      slices.add({'label': 'Sales', 'value': total > 0 ? total : 1.0, 'color': const Color(0xFF0284C7)});
    }

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _PieChartPainter(
                slices: slices,
                holeColor: colorScheme.surface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
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
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: s['color'] as Color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s['label']}: ${pct.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
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

  Widget _buildCollectionRateCard(BuildContext context, double rate, double paid, double sales) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = rate >= 80 ? const Color(0xFF059669) : (rate >= 50 ? const Color(0xFFD97706) : const Color(0xFFDC2626));
    final bgColor = rate >= 80 ? const Color(0xFFECFDF5) : (rate >= 50 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collection Rate Efficiency',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: colorScheme.onSurface),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: sales > 0 ? (paid / sales).clamp(0.0, 1.0) : 0.0,
              minHeight: 10,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${NumberFormatter.formatCurrency(paid)} collected out of ${NumberFormatter.formatCurrency(sales)} billed',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
        ],
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
      childAspectRatio: 1.55,
      children: [
        _buildMetricTile(
          context: context,
          icon: Iconsax.receipt_2_1,
          color: const Color(0xFF0284C7),
          bgColor: const Color(0xFFE0F2FE),
          label: 'Total Orders',
          value: NumberFormatter.format(totalOrders),
        ),
        _buildMetricTile(
          context: context,
          icon: Iconsax.ticket_star,
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFEDE9FE),
          label: 'Avg Order Value',
          value: NumberFormatter.formatCurrency(avgOrderValue),
        ),
        _buildMetricTile(
          context: context,
          icon: Iconsax.verify,
          color: const Color(0xFF059669),
          bgColor: const Color(0xFFECFDF5),
          label: 'Fully Paid Orders',
          value: NumberFormatter.format(fullyPaidCount),
        ),
        _buildMetricTile(
          context: context,
          icon: Iconsax.clock,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
          label: 'Pending Debt Orders',
          value: NumberFormatter.format(pendingCount),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
        mainAxisAlignment: MainAxisAlignment.center,
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
                  label,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialBreakdownCard(
    BuildContext context,
    double totalSales,
    double totalPaid,
    double totalBalance,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFinanceRow(context, 'Total Invoiced', NumberFormatter.formatCurrency(totalSales), colorScheme.onSurface),
          Divider(height: 16, color: colorScheme.outlineVariant),
          _buildFinanceRow(context, 'Cash Received', NumberFormatter.formatCurrency(totalPaid), const Color(0xFF059669)),
          Divider(height: 16, color: colorScheme.outlineVariant),
          _buildFinanceRow(context, 'Uncollected Debt', NumberFormatter.formatCurrency(totalBalance), const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildDebtorItem(BuildContext context, dynamic record) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecordDetailsScreen(record: record),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Iconsax.user_minus, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.customerName,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${record.jobDescription} • Total: ${NumberFormatter.formatCurrency(record.totalAmount)}',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Owes ${NumberFormatter.formatCurrency(record.balance)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626), fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    const Text('Tap to view', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoDebtCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Iconsax.tick_circle, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Debts Settled!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: colorScheme.onSurface)),
                SizedBox(height: 2),
                Text('There are no outstanding balances for this period.', style: TextStyle(fontSize: 11.5, color: Color(0xFF059669))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectedProfitSection(BuildContext context, RecordProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasData = provider.records.isNotEmpty;
    final dailyUser = provider.expectedDailyUserProfit;
    final weeklyUser = provider.expectedWeeklyUserProfit;
    final monthlyUser = provider.expectedMonthlyUserProfit;
    final dailyNet = provider.expectedDailyNetProfit;
    final weeklyNet = provider.expectedWeeklyNetProfit;
    final monthlyNet = provider.expectedMonthlyNetProfit;

    if (!hasData) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Iconsax.status_up, color: Color(0xFF94A3B8), size: 26),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'No records yet — projections will appear once the first print job is added.',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Main gradient projection card
        Container(
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
                      'Your Projected Profit Share (50%)',
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
                      'Forecast',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Projections responsive layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 340;
                  if (isSmall) {
                    return Column(
                      children: [
                        _buildProjectionTile(
                          period: 'Daily',
                          userAmount: dailyUser,
                          totalAmount: dailyNet,
                          icon: Iconsax.sun_1,
                          accent: const Color(0xFF60A5FA),
                          isRow: true,
                        ),
                        const SizedBox(height: 8),
                        _buildProjectionTile(
                          period: 'Weekly',
                          userAmount: weeklyUser,
                          totalAmount: weeklyNet,
                          icon: Iconsax.calendar_tick,
                          accent: const Color(0xFF34D399),
                          isRow: true,
                        ),
                        const SizedBox(height: 8),
                        _buildProjectionTile(
                          period: 'Monthly',
                          userAmount: monthlyUser,
                          totalAmount: monthlyNet,
                          icon: Iconsax.calendar_2,
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
                          period: 'Daily',
                          userAmount: dailyUser,
                          totalAmount: dailyNet,
                          icon: Iconsax.sun_1,
                          accent: const Color(0xFF60A5FA),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildProjectionTile(
                          period: 'Weekly',
                          userAmount: weeklyUser,
                          totalAmount: weeklyNet,
                          icon: Iconsax.calendar_tick,
                          accent: const Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildProjectionTile(
                          period: 'Monthly',
                          userAmount: monthlyUser,
                          totalAmount: monthlyNet,
                          icon: Iconsax.calendar_2,
                          accent: const Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Secondary row: business net profit reference
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Iconsax.shop, size: 15, color: colorScheme.onSurfaceVariant),
                  SizedBox(width: 6),
                  Text(
                    'Total Shop Net Profit Projections',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildSimpleStat(context, 'Daily', dailyNet, const Color(0xFF0284C7))),
                  Expanded(child: _buildSimpleStat(context, 'Weekly', weeklyNet, const Color(0xFF059669))),
                  Expanded(child: _buildSimpleStat(context, 'Monthly', monthlyNet, const Color(0xFFD97706))),
                ],
              ),
            ],
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
                  NumberFormatter.formatCurrency(userAmount),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
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
              NumberFormatter.formatCurrency(userAmount),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'your share',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(BuildContext context, String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            NumberFormatter.formatCurrency(value),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
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
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w600),
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
  final Color holeColor;

  _PieChartPainter({required this.slices, required this.holeColor});

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
    final holePaint = Paint()..color = holeColor;
    canvas.drawCircle(center, radius * 0.55, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => true;
}
