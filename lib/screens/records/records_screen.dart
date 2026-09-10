import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/record_provider.dart';
import 'record_details_screen.dart';
import '../../utils/number_formatter.dart';

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
        return 'All';
      case RecordPeriodFilter.today:
        return 'Today';
      case RecordPeriodFilter.week:
        return 'This Week';
      case RecordPeriodFilter.month:
        return 'This Month';
      case RecordPeriodFilter.custom:
        return _customSelectedDate != null
            ? DateFormat('dd MMM yyyy').format(_customSelectedDate!)
            : 'Custom Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Records History', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Consumer<RecordProvider>(
        builder: (context, provider, child) {
          final filtered = provider.records.where((record) {
            final matchesQuery = record.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                record.jobDescription.toLowerCase().contains(_searchQuery.toLowerCase());
            if (!matchesQuery) return false;
            return _matchesPeriod(record.timestamp);
          }).toList();

          return Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search customer or job...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Period Filter Chips (All, Today, Week, Month, Custom Date)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    ...RecordPeriodFilter.values.map((filter) {
                      final isSelected = _selectedPeriod == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          avatar: filter == RecordPeriodFilter.custom
                              ? Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          label: Text(_getPeriodChipLabel(filter)),
                          selected: isSelected,
                          onSelected: (_) {
                            if (filter == RecordPeriodFilter.custom) {
                              _pickCustomDate();
                            } else {
                              setState(() => _selectedPeriod = filter);
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const Divider(height: 16),

              // Filter Count Summary Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${filtered.length} of ${provider.records.length} records',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    if (_selectedPeriod != RecordPeriodFilter.all || _searchQuery.isNotEmpty)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 20),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedPeriod = RecordPeriodFilter.all;
                            _customSelectedDate = null;
                            _searchQuery = '';
                          });
                        },
                        child: const Text('Reset filters', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Records List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No records matching "$_searchQuery"'
                                  : 'No records found for this period',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemBuilder: (context, index) {
                          final record = filtered[index];
                          final hasBalance = record.balance > 0;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            elevation: 0.8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: hasBalance
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.15),
                                child: Icon(
                                  hasBalance ? Icons.pending_actions : Icons.check_circle_outline,
                                  color: hasBalance ? Colors.orange.shade800 : Colors.green.shade800,
                                ),
                              ),
                              title: Text(
                                record.customerName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${record.jobDescription} • Qty: ${NumberFormatter.format(record.quantity)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(record.timestamp),
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                      if (record.createdBy != null && record.createdBy!.isNotEmpty) ...[
                                        Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                        Icon(Icons.person_outline, size: 12, color: Colors.blue.shade700),
                                        const SizedBox(width: 2),
                                        Flexible(
                                          child: Text(
                                            record.createdBy!,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    NumberFormatter.formatCurrency(record.totalAmount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasBalance ? 'Due: ${NumberFormatter.formatCurrency(record.balance)}' : '${record.paymentMode} • Paid',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: hasBalance ? Colors.red : Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        record.isSynced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                                        size: 13,
                                        color: record.isSynced ? Colors.teal : Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        record.isSynced ? 'Synced' : 'Not synced',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: record.isSynced ? Colors.teal : Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
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
