import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/record_model.dart';
import '../providers/record_provider.dart';
import '../utils/number_formatter.dart';

class RecordDetailsScreen extends StatelessWidget {
  final PrintingRecord record;

  const RecordDetailsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Customer', record.customerName),
                _buildDetailRow('Job', record.jobDescription),
                _buildDetailRow('Date', DateFormat('dd MMM yyyy, HH:mm').format(record.timestamp)),
                const Divider(),
                _buildDetailRow('Quantity', NumberFormatter.format(record.quantity)),
                _buildDetailRow('Price per unit', NumberFormatter.formatCurrency(record.pricePerUnit)),
                const Divider(),
                _buildDetailRow('Total Amount', NumberFormatter.formatCurrency(record.totalAmount), isBold: true),
                _buildDetailRow('Amount Paid', NumberFormatter.formatCurrency(record.paidAmount), color: Colors.green),
                _buildDetailRow(
                  'Balance',
                  NumberFormatter.formatCurrency(record.balance),
                  color: record.balance > 0 ? Colors.red : Colors.green,
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(
            builder: (context) => Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('Are you sure you want to remove this record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<RecordProvider>(context, listen: false).deleteRecord(record.id!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
