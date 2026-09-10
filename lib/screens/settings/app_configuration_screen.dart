import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_config_model.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../providers/record_provider.dart';
import '../../utils/number_formatter.dart';

class AppConfigurationScreen extends StatefulWidget {
  const AppConfigurationScreen({super.key});

  @override
  State<AppConfigurationScreen> createState() => _AppConfigurationScreenState();
}

class _AppConfigurationScreenState extends State<AppConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;
  bool _isSavingConfig = false;

  late TextEditingController _papersStockController;
  late TextEditingController _pricePerPaperController;
  late TextEditingController _buyingPriceController;
  late TextEditingController _inkPriceController;
  late TextEditingController _serviceFeeController;

  @override
  void initState() {
    super.initState();
    final recordProvider = Provider.of<RecordProvider>(context, listen: false);
    final config = recordProvider.config;

    _papersStockController = TextEditingController(text: config.papersStock.toString());
    _pricePerPaperController = TextEditingController(text: config.pricePerPaper.toStringAsFixed(0));
    _buyingPriceController = TextEditingController(text: config.buyingPricePerPaper.toStringAsFixed(0));
    _inkPriceController = TextEditingController(text: config.inkPricePerPaper.toStringAsFixed(0));
    _serviceFeeController = TextEditingController(text: config.serviceFeePerPaper.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _papersStockController.dispose();
    _pricePerPaperController.dispose();
    _buyingPriceController.dispose();
    _inkPriceController.dispose();
    _serviceFeeController.dispose();
    super.dispose();
  }

  double get _currentPrice => double.tryParse(_pricePerPaperController.text) ?? 0.0;
  double get _currentBuyingPrice => double.tryParse(_buyingPriceController.text) ?? 0.0;
  double get _currentInkPrice => double.tryParse(_inkPriceController.text) ?? 0.0;
  double get _currentServiceFee => double.tryParse(_serviceFeeController.text) ?? 0.0;
  double get _totalExpensesPerPaper => _currentBuyingPrice + _currentInkPrice + _currentServiceFee;
  double get _netProfitPerPaper => _currentPrice - _totalExpensesPerPaper;

  Future<void> _saveConfigurations() async {
    if (!_formKey.currentState!.validate()) return;

    final recordProvider = Provider.of<RecordProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSavingConfig = true);
    try {
      final updatedConfig = AppConfig(
        papersStock: int.parse(_papersStockController.text.trim()),
        pricePerPaper: double.parse(_pricePerPaperController.text.trim()),
        buyingPricePerPaper: double.parse(_buyingPriceController.text.trim()),
        inkPricePerPaper: double.parse(_inkPriceController.text.trim()),
        serviceFeePerPaper: double.parse(_serviceFeeController.text.trim()),
        updatedAt: DateTime.now(),
      );

      await recordProvider.updateConfig(updatedConfig);

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Configurations saved & synchronized across all devices!'),
              ),
            ],
          ),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save configurations: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final recordProvider = Provider.of<RecordProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App Configuration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Admin Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.email ?? 'Admin',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade900,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Administrator Access',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Pricing, Costs & Stock Configuration
            const Row(
              children: [
                Icon(Icons.tune, size: 20, color: Colors.blue),
                SizedBox(width: 6),
                Text(
                  'Pricing, Cost & Profit Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Changes made here are saved to SQLite and automatically synced to all devices.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 1.5,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Papers stock
                    TextFormField(
                      controller: _papersStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Current Total Papers Stock',
                        hintText: 'e.g. 500 sheets (1 ream)',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                        suffixText: 'sheets',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Stock is required';
                        if (int.tryParse(val.trim()) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Selling price per paper
                    TextFormField(
                      controller: _pricePerPaperController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Printing Price per Paper',
                        hintText: 'e.g. 150',
                        prefixIcon: Icon(Icons.payments_outlined),
                        prefixText: 'MWK ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Price is required';
                        if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Buying price per paper
                    TextFormField(
                      controller: _buyingPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Buying Price per Paper (Cost)',
                        hintText: 'e.g. 35',
                        prefixIcon: Icon(Icons.shopping_cart_outlined),
                        prefixText: 'MWK ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Buying price is required';
                        if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ink price per paper
                    TextFormField(
                      controller: _inkPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ink Price per Paper (Expense)',
                        hintText: 'e.g. 25',
                        prefixIcon: Icon(Icons.color_lens_outlined),
                        prefixText: 'MWK ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Ink price is required';
                        if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Service fee per paper
                    TextFormField(
                      controller: _serviceFeeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Service Fee per Paper (Overhead/Wear)',
                        hintText: 'e.g. 10',
                        prefixIcon: Icon(Icons.build_circle_outlined),
                        prefixText: 'MWK ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Service fee is required';
                        if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Live Net Profit Calculation Preview Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _netProfitPerPaper >= 0
                            ? Colors.teal.withValues(alpha: 0.08)
                            : Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _netProfitPerPaper >= 0 ? Colors.teal.shade300 : Colors.red.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Expenses / Paper:', style: TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                NumberFormatter.formatCurrency(_totalExpensesPerPaper),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(Paper: ${NumberFormatter.formatCurrency(_currentBuyingPrice)} + Ink: ${NumberFormatter.formatCurrency(_currentInkPrice)} + Service: ${NumberFormatter.formatCurrency(_currentServiceFee)})',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Net Profit per Paper:',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                NumberFormatter.formatCurrency(_netProfitPerPaper),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _netProfitPerPaper >= 0 ? Colors.teal.shade800 : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isSavingConfig ? null : _saveConfigurations,
                        icon: _isSavingConfig
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          _isSavingConfig ? 'Saving & Syncing...' : 'Save & Sync Configurations',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Cloud & Sync Management
            const Text(
              'Cloud & Synchronization',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_sync, color: Colors.teal),
                    title: const Text('Pull Records from Cloud'),
                    subtitle: const Text('Fetch latest records synced by other devices'),
                    trailing: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isProcessing
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _isProcessing = true);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Pulling cloud records...')),
                            );
                            try {
                              final count = await SyncService().syncFromCloud();
                              if (!mounted) return;
                              await recordProvider.fetchRecords();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Successfully pulled $count new records from Firestore!'),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            } finally {
                              if (mounted) setState(() => _isProcessing = false);
                            }
                          },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_upload, color: Colors.blue),
                    title: const Text('Push Unsynced Records'),
                    subtitle: Text('${recordProvider.pendingSyncRecordsCount} pending local record(s)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Syncing local records to cloud...')),
                      );
                      final count = await SyncService().syncLocalRecordsToCloud();
                      if (!mounted) return;
                      await recordProvider.fetchRecords();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Successfully synced $count records!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Database & Storage Info
            const Text(
              'System & Storage',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.storage_outlined, color: Colors.indigo),
                    title: const Text('Local SQLite Records'),
                    subtitle: Text('${recordProvider.records.length} records saved on this device'),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.verified_user_outlined, color: Colors.green),
                    title: Text('Database Version'),
                    subtitle: Text('SQLite v5 (with sync & config schema)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
