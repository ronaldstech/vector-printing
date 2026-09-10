import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/record_model.dart';
import '../../providers/record_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/number_formatter.dart';

class POSScreen extends StatefulWidget {
  final VoidCallback onOrderCompleted;

  const POSScreen({super.key, required this.onOrderCompleted});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _copiesController = TextEditingController(text: '1');
  final _pagesController = TextEditingController(text: '1');

  // Payment mode options
  final List<String> _paymentModes = ['Cash', 'Airtel Money', 'TNM Mpamba'];
  String _selectedPaymentMode = 'Cash';

  double _pricePerPaper = 150.0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _copiesController.addListener(_calculateTotal);
    _pagesController.addListener(_calculateTotal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final config = Provider.of<RecordProvider>(context).config;
    _pricePerPaper = config.pricePerPaper;
    _calculateTotal();
  }

  void _calculateTotal() {
    final copies = int.tryParse(_copiesController.text.trim()) ?? 0;
    final pages = int.tryParse(_pagesController.text.trim()) ?? 0;
    setState(() {
      _totalAmount = (copies * pages * _pricePerPaper).toDouble();
    });
  }

  void _clearForm() {
    _customerNameController.clear();
    _copiesController.text = '1';
    _pagesController.text = '1';
    setState(() {
      _selectedPaymentMode = 'Cash';
      _calculateTotal();
    });
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final customerName = _customerNameController.text.trim();
    final copies = int.parse(_copiesController.text.trim());
    final pages = int.parse(_pagesController.text.trim());
    final totalQuantity = copies * pages;

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    final createdByEmail = user?.email;

    final newRecord = PrintingRecord(
      customerName: customerName,
      jobDescription: 'Printing ($copies copies, $pages pages)',
      quantity: totalQuantity,
      copies: copies,
      pages: pages,
      pricePerUnit: _pricePerPaper,
      totalAmount: _totalAmount,
      paidAmount: _totalAmount,
      balance: 0.0,
      paymentMode: _selectedPaymentMode,
      timestamp: DateTime.now(),
      createdBy: createdByEmail,
      isSynced: false,
    );

    final provider = Provider.of<RecordProvider>(context, listen: false);
    await provider.addRecord(newRecord);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sale saved! ${NumberFormatter.formatCurrency(_totalAmount)} via $_selectedPaymentMode',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _clearForm();
    widget.onOrderCompleted();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _copiesController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Terminal', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Reset Form',
            icon: const Icon(Icons.refresh),
            onPressed: _clearForm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Name (Optional)
              TextFormField(
                controller: _customerNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Customer Name (Optional)',
                  hintText: 'e.g. Walk-in Customer / John Banda',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),

              // Number of Copies & Number of Pages Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _copiesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Number of Copies',
                        prefixIcon: const Icon(Icons.copy_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      onChanged: (_) => _calculateTotal(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Required';
                        final n = int.tryParse(value);
                        if (n == null || n <= 0) return 'Must be >= 1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _pagesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Number of Pages',
                        prefixIcon: const Icon(Icons.auto_stories_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      onChanged: (_) => _calculateTotal(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Required';
                        final n = int.tryParse(value);
                        if (n == null || n <= 0) return 'Must be >= 1';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Price Per Page (Configured / Read-only)
              Consumer<RecordProvider>(
                builder: (context, provider, _) {
                  final configuredPrice = provider.config.pricePerPaper;
                  return TextFormField(
                    key: ValueKey('price_$configuredPrice'),
                    initialValue: NumberFormatter.formatCurrency(configuredPrice),
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Price Per Page (Configured)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      helperText: 'Configured by Admin across all devices',
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Mode of Payment Select / Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedPaymentMode,
                decoration: InputDecoration(
                  labelText: 'Mode of Payment',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                items: _paymentModes.map((mode) {
                  IconData iconData;
                  if (mode == 'Airtel Money') {
                    iconData = Icons.phone_android;
                  } else if (mode == 'TNM Mpamba') {
                    iconData = Icons.sim_card_outlined;
                  } else {
                    iconData = Icons.money;
                  }
                  return DropdownMenuItem<String>(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(iconData, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(mode, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPaymentMode = val);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Total Calculation Summary Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Formula:',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        Text(
                          '${_copiesController.text.isEmpty ? '0' : _copiesController.text} copies × ${_pagesController.text.isEmpty ? '0' : _pagesController.text} pages × ${NumberFormatter.formatCurrency(_pricePerPaper)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          NumberFormatter.formatCurrency(_totalAmount),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submitOrder,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'Save Sale to Database',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
