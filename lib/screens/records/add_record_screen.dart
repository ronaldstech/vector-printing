import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/record_model.dart';
import '../../providers/record_provider.dart';
import '../../utils/number_formatter.dart';

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _jobDescriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _pricePerUnitController = TextEditingController();
  final _paidAmountController = TextEditingController();

  double _totalAmount = 0;
  double _balance = 0;

  void _calculateTotals() {
    setState(() {
      int quantity = int.tryParse(_quantityController.text) ?? 0;
      double price = double.tryParse(_pricePerUnitController.text) ?? 0;
      double paid = double.tryParse(_paidAmountController.text) ?? 0;

      _totalAmount = quantity * price;
      _balance = _totalAmount - paid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Printing Record')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _customerNameController,
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jobDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Job Description (e.g., A4 B&W)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateTotals(),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pricePerUnitController,
                      decoration: InputDecoration(
                        labelText: 'Price Per Unit (Ksh)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _calculateTotals(),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidAmountController,
                decoration: InputDecoration(
                  labelText: 'Amount Paid (Ksh)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _calculateTotals(),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount:'),
                        Text(NumberFormatter.formatCurrency(_totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Balance:'),
                        Text(
                          NumberFormatter.formatCurrency(_balance),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _balance > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _saveRecord,
                  child: const Text('Save Record', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveRecord() {
    if (_formKey.currentState!.validate()) {
      final record = PrintingRecord(
        customerName: _customerNameController.text.trim(),
        jobDescription: _jobDescriptionController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        pricePerUnit: double.parse(_pricePerUnitController.text.trim()),
        totalAmount: _totalAmount,
        paidAmount: double.tryParse(_paidAmountController.text.trim()) ?? 0.0,
        balance: _balance,
        timestamp: DateTime.now(),
      );

      Provider.of<RecordProvider>(context, listen: false).addRecord(record);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _jobDescriptionController.dispose();
    _quantityController.dispose();
    _pricePerUnitController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }
}
