import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../providers/record_provider.dart';
import 'record_details_screen.dart';
import '../../utils/number_formatter.dart';
import '../../services/sync_service.dart';

enum RecordPeriodFilter { all, today, week, month, custom }

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String _searchQuery = '';
  RecordPeriodFilter _selectedPeriod = RecordPeriodFilter.all;
  DateTime? _customSelectedDate;

  bool _matchesPeriod(DateTime timestamp) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case RecordPeriodFilter.today:
        return timestamp.year == now.year &&
            timestamp.month == now.month &&
            timestamp.day == now.day;
      case RecordPeriodFilter.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return timestamp.isAfter(start.subtract(const Duration(seconds: 1)));
      case RecordPeriodFilter.month:
        return timestamp.year == now.year && timestamp.month == now.month;
      case RecordPeriodFilter.custom:
        if (_customSelectedDate == null) return true;
        return timestamp.year == _customSelectedDate!.year &&
            timestamp.month == _customSelectedDate!.month &&
            timestamp.day == _customSelectedDate!.day;
      case RecordPeriodFilter.all:
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
        _selectedPeriod = RecordPeriodFilter.custom;
      });
    }
  }

  String _getPeriodChipLabel(RecordPeriodFilter filter) {
    switch (filter) {
      case RecordPeriodFilter.all:
        return 'All Time';
      case RecordPeriodFilter.today:
        return 'Today';
      case RecordPeriodFilter.week:
        return 'This Week';
      case RecordPeriodFilter.month:
        return 'This Month';
      case RecordPeriodFilter.custom:
        return _customSelectedDate != null
            ? DateFormat('d MMM yyyy').format(_customSelectedDate!)
            : 'Select Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: colors.outlineVariant, height: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Iconsax.receipt_2_1,
                color: colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orders & Records',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Sales History & Invoicing',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Consumer<RecordProvider>(
            builder: (context, provider, _) {
              final pendingCount = provider.pendingSyncRecordsCount;
              final hasPending = pendingCount > 0;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: hasPending ? Colors.red.withValues(alpha: 0.12) : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasPending ? Colors.red.withValues(alpha: 0.3) : colors.outlineVariant,
                          width: hasPending ? 1.2 : 1.0,
                        ),
                      ),
                      child: IconButton(
                        tooltip: hasPending
                            ? '$pendingCount unsynced records - Tap to sync online'
                            : 'Sync Cloud Records',
                        icon: Icon(
                          hasPending ? Iconsax.cloud_cross : Iconsax.refresh,
                          size: 18,
                          color: hasPending ? const Color(0xFFDC2626) : colors.onSurfaceVariant,
                        ),
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Syncing records to Cloud Firestore...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          final count = await SyncService().syncLocalRecordsToCloud();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  count > 0
                                      ? 'Synced $count records to Firestore!'
                                      : 'All records are already synced.',
                                ),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    if (hasPending)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                            child: Text(
                              pendingCount > 99 ? '99+' : '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<RecordProvider>(
        builder: (context, recordProvider, child) {
          final allRecords = recordProvider.records;
          final pendingCount = recordProvider.pendingSyncRecordsCount;

          // Filter by period and search text
          final filtered = allRecords.where((record) {
            final matchesSearch = _searchQuery.isEmpty ||
                record.customerName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                record.jobDescription
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
            final matchesTime = _matchesPeriod(record.timestamp);
            return matchesSearch && matchesTime;
          }).toList();

          // Calculate period-specific totals
          final filteredTotal = filtered.fold<double>(
            0.0,
            (sum, item) => sum + item.totalAmount,
          );
          final filteredSheets = filtered.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );

          return Column(
            children: [
              // Unsynced Alert Banner
              if (pendingCount > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    border: Border(
                      bottom: BorderSide(color: Colors.red.withValues(alpha: 0.25), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Iconsax.cloud_cross,
                          color: Color(0xFFE11D48),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 12, color: colors.onSurface),
                            children: [
                              TextSpan(
                                text: 'You have $pendingCount ${pendingCount == 1 ? 'record' : 'records'} ',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const TextSpan(
                                text: 'not yet synced to online database.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Syncing records to Cloud Firestore...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          final count = await SyncService().syncLocalRecordsToCloud();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  count > 0
                                      ? 'Synced $count records to Firestore!'
                                      : 'All records are already synced.',
                                ),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Iconsax.refresh, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Sync Now',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Search & Filter Header Container
              Container(
                color: colors.surface,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  children: [
                    // Modern Search Field
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search customer name or job description...',
                        hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                        prefixIcon: Icon(Iconsax.search_normal, size: 18, color: colors.onSurfaceVariant),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Iconsax.close_circle, size: 18, color: colors.onSurfaceVariant),
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Period Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: RecordPeriodFilter.values.map((filter) {
                          final isSelected = _selectedPeriod == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () {
                                if (filter == RecordPeriodFilter.custom) {
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? colors.primary : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? colors.primary : colors.outlineVariant,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colors.primary.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (filter == RecordPeriodFilter.custom) ...[
                                      Icon(
                                        Iconsax.calendar_1,
                                        size: 14,
                                        color: isSelected ? Colors.white : colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(
                                      _getPeriodChipLabel(filter),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? Colors.white : colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Stats Strip for Current Filtered Results
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(color: colors.outlineVariant, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${NumberFormatter.format(filtered.length)} orders',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          ' (${NumberFormatter.format(filteredSheets)} sheets)',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Gross: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          NumberFormatter.formatCurrency(filteredTotal),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: colors.primary,
                          ),
                        ),
                        if (_selectedPeriod != RecordPeriodFilter.all || _searchQuery.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPeriod = RecordPeriodFilter.all;
                                _customSelectedDate = null;
                                _searchQuery = '';
                              });
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Records List View
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Iconsax.document_filter,
                                  size: 40,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No orders matching "$_searchQuery"'
                                    : 'No orders recorded for this period',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try changing your period filter or clearing search keywords.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemBuilder: (context, index) {
                          final record = filtered[index];
                          final hasBalance = record.balance > 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.outlineVariant),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RecordDetailsScreen(record: record),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Status Avatar Icon
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: hasBalance
                                              ? Colors.amber.withValues(alpha: 0.15)
                                              : Colors.green.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          hasBalance ? Iconsax.clock : Iconsax.verify,
                                          color: hasBalance
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFF059669),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Customer and Job Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              record.customerName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                                color: colors.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${record.jobDescription} • ${NumberFormatter.format(record.quantity)} sheet(s)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onSurfaceVariant,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Iconsax.calendar_1,
                                                      size: 13,
                                                      color: colors.onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      DateFormat('dd MMM, hh:mm a').format(record.timestamp),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: colors.onSurfaceVariant,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (record.createdBy != null && record.createdBy!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: colors.surfaceContainerHighest,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      record.createdBy!,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: colors.onSurfaceVariant,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Financial Breakdown & Sync Badge
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            NumberFormatter.formatCurrency(record.totalAmount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color: colors.onSurface,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: hasBalance
                                                  ? Colors.red.withValues(alpha: 0.12)
                                                  : Colors.green.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              hasBalance
                                                  ? 'Due: ${NumberFormatter.formatCurrency(record.balance)}'
                                                  : '${record.paymentMode} • Paid',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: hasBalance
                                                    ? const Color(0xFFDC2626)
                                                    : const Color(0xFF059669),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                record.isSynced ? Iconsax.cloud_add : Iconsax.cloud_cross,
                                                size: 13,
                                                color: record.isSynced
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFFD97706),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                record.isSynced ? 'Synced' : 'Queued',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: record.isSynced
                                                      ? const Color(0xFF059669)
                                                      : const Color(0xFFD97706),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
