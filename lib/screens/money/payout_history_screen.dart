import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/payout_record_model.dart';
import '../../providers/record_provider.dart';
import '../../utils/number_formatter.dart';

class PayoutHistoryScreen extends StatelessWidget {
  const PayoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text(
          'Payout History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Consumer<RecordProvider>(
              builder: (context, provider, _) => Center(
                child: Text(
                  '${NumberFormatter.format(provider.payoutRecords.length)} payouts',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<RecordProvider>(
        builder: (context, provider, _) {
          final payouts = provider.payoutRecords; // sorted DESC by timestamp

          if (payouts.isEmpty) {
            return _buildEmptyState();
          }

          final totalPaidOut = provider.totalPaidOutToUser;
          final totalUserShare = provider.totalUserProfitShare;
          final currentBalance = provider.userPayoutBalance;

          return RefreshIndicator(
            onRefresh: () => provider.fetchRecords(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payouts.length + 1, // +1 for summary card
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildSummaryCard(
                    currentBalance: currentBalance,
                    totalPaidOut: totalPaidOut,
                    totalUserShare: totalUserShare,
                    count: payouts.length,
                  );
                }
                final record = payouts[index - 1];
                return _buildPayoutCard(record);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required double currentBalance,
    required double totalPaidOut,
    required double totalUserShare,
    required int count,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E), // Deep Teal
            Color(0xFF0D9488), // Medium Teal
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.payments_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'User Profit Payout Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${NumberFormatter.format(count)} Recorded',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Current balance large
          Text(
            'Balance Due',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormatter.formatCurrency(currentBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Divider
          Divider(color: Colors.white.withValues(alpha: 0.25), height: 1),
          const SizedBox(height: 14),

          // Row stats
          Row(
            children: [
              Expanded(
                child: _buildStatCol(
                  label: 'Total Earned (50%)',
                  value: NumberFormatter.formatCurrency(totalUserShare),
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: _buildStatCol(
                  label: 'Total Paid Out',
                  value: NumberFormatter.formatCurrency(totalPaidOut),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(PayoutRecord record) {
    final hasNote = record.note != null && record.note!.isNotEmpty;
    final hasRecordedBy = record.recordedBy != null && record.recordedBy!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon + Date + Amount Badge
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  radius: 20,
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.teal.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy').format(record.timestamp),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormat('hh:mm a').format(record.timestamp),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            record.isSynced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                            size: 12,
                            color: record.isSynced ? Colors.teal : Colors.orange.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            record.isSynced ? 'Synced' : 'Pending',
                            style: TextStyle(
                              fontSize: 10,
                              color: record.isSynced ? Colors.teal : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    NumberFormatter.formatCurrency(record.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            if (hasNote) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notes, size: 14, color: Colors.amber.shade800),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.note!,
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Profit balance context
            Row(
              children: [
                Expanded(
                  child: _buildContextStat(
                    label: 'Total Profit at Time',
                    value: NumberFormatter.formatCurrency(record.totalProfitAtTime),
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildContextStat(
                    label: 'Cumulative Paid',
                    value: NumberFormatter.formatCurrency(record.cumulativePaidAtTime),
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildContextStat(
                    label: 'Balance After',
                    value: NumberFormatter.formatCurrency(record.balanceAfterPayout),
                    color: record.balanceAfterPayout > 0 ? Colors.teal.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),

            if (hasRecordedBy) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Recorded by ${record.recordedBy}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Sync indicator
                  Icon(
                    record.isSynced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    size: 14,
                    color: record.isSynced ? Colors.teal : Colors.grey,
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  record.isSynced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  size: 14,
                  color: record.isSynced ? Colors.teal : Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContextStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payments_outlined, size: 44, color: Colors.teal.shade300),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Payouts Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'When admin records a profit payout to the user,\nit will appear here with full details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
