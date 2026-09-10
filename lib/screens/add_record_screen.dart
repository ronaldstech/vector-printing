import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/record_model.dart';
import '../providers/record_provider.dart';

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _jobDescriptionController = TextEditingController();
  final _quantityController = TextEditingController();
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
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _jobDescriptionController,
                decoration: const InputDecoration(labelText: 'Job Description (e.g., A4 B&W)'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateTotals(),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pricePerUnitController,
                      decoration: const InputDecoration(labelText: 'Price Per Unit'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateTotals(),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _paidAmountController,
                decoration: const InputDecoration(labelText: 'Amount Paid'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateTotals(),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount:'),
                        Text('Ksh ${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Balance:'),
                        Text(
                          'Ksh ${_balance.toStringAsFixed(2)}',
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveRecord,
                  child: const Text('Save Record'),
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
        customerName: _customerNameController.text,
        jobDescription: _jobDescriptionController.text,
        quantity: int.parse(_quantityController.text),
        pricePerUnit: double.parse(_pricePerUnitController.text),
        totalAmount: _totalAmount,
        paidAmount: double.parse(_paidAmountController.text),
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
