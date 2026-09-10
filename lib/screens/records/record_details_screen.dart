import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/record_model.dart';
import '../../providers/record_provider.dart';
import '../../utils/number_formatter.dart';

class RecordDetailsScreen extends StatelessWidget {
  final PrintingRecord record;

  const RecordDetailsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final bool hasBalance = record.balance > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Record',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            record.customerName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                         Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: record.isSynced
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.orange.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                record.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                                size: 14,
                                color: record.isSynced ? Colors.green.shade700 : Colors.orange.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                record.isSynced ? 'Synced' : 'Not Synced',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: record.isSynced ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEE, dd MMM yyyy • hh:mm a').format(record.timestamp),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const Divider(height: 28),
                    _buildDetailRow('Job Description', record.jobDescription),
                    if (record.createdBy != null && record.createdBy!.isNotEmpty)
                      _buildDetailRow('Recorded By', record.createdBy!),
                    _buildDetailRow('Copies', NumberFormatter.format(record.copies)),
                    _buildDetailRow('Pages per copy', NumberFormatter.format(record.pages)),
                    _buildDetailRow('Total Pages Printed', NumberFormatter.format(record.quantity)),
                    _buildDetailRow('Price per page', NumberFormatter.formatCurrency(record.pricePerUnit)),
                    _buildDetailRow('Payment Mode', record.paymentMode),
                    const Divider(height: 28),
                    _buildDetailRow(
                      'Total Amount',
                      NumberFormatter.formatCurrency(record.totalAmount),
                      isBold: true,
                      fontSize: 18,
                    ),
                    _buildDetailRow(
                      'Amount Paid',
                      NumberFormatter.formatCurrency(record.paidAmount),
                      color: Colors.green.shade700,
                      isBold: true,
                    ),
                    _buildDetailRow(
                      'Balance Remaining',
                      NumberFormatter.formatCurrency(record.balance),
                      color: hasBalance ? Colors.red : Colors.green.shade700,
                      isBold: true,
                      fontSize: 17,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
    double fontSize = 15,
  }) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
            Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: Text('Are you sure you want to delete the record for "${record.customerName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Provider.of<RecordProvider>(context, listen: false).deleteRecord(record.id!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
