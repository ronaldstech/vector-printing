import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
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
        SnackBar(
          content: Row(
            children: const [
              Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Configurations saved & synchronized across all devices!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save configurations: $e'),
          backgroundColor: Colors.red.shade700,
        ),
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
                Iconsax.setting_2,
                color: colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Configuration',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Pricing, Paper Stock & Cloud Settings',
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
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 96.0),
          children: [
            // Admin Status Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Iconsax.security_user,
                      color: colors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.email ?? 'Admin',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Administrator Privileges',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pricing, Costs & Stock Configuration Section
            _buildSectionHeader(context, 'Pricing, Cost & Profit Settings', Iconsax.coin_1),
            const SizedBox(height: 4),
            Text(
              'Changes saved here apply globally across all synchronized staff devices.',
              style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Papers stock
                  _buildConfigInputField(
                    context: context,
                    controller: _papersStockController,
                    label: 'Current Total Paper Stock',
                    hint: 'e.g. 500 sheets',
                    icon: Iconsax.document_copy,
                    suffixText: 'sheets',
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Stock is required';
                      if (int.tryParse(val.trim()) == null) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Selling price per paper
                  _buildConfigInputField(
                    context: context,
                    controller: _pricePerPaperController,
                    label: 'Printing Price per Paper',
                    hint: 'e.g. 150',
                    icon: Iconsax.tag,
                    prefixText: 'MWK ',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Price is required';
                      if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Buying price per paper
                  _buildConfigInputField(
                    context: context,
                    controller: _buyingPriceController,
                    label: 'Buying Price per Paper (Cost)',
                    hint: 'e.g. 35',
                    icon: Iconsax.shopping_cart,
                    prefixText: 'MWK ',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Buying price is required';
                      if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Ink price per paper
                  _buildConfigInputField(
                    context: context,
                    controller: _inkPriceController,
                    label: 'Ink / Toner Price per Paper',
                    hint: 'e.g. 25',
                    icon: Iconsax.colorfilter,
                    prefixText: 'MWK ',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Ink price is required';
                      if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Service fee per paper
                  _buildConfigInputField(
                    context: context,
                    controller: _serviceFeeController,
                    label: 'Service Fee per Paper (Overhead/Wear)',
                    hint: 'e.g. 10',
                    icon: Iconsax.setting_4,
                    prefixText: 'MWK ',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Service fee is required';
                      if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Live Net Profit Preview Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _netProfitPerPaper >= 0
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _netProfitPerPaper >= 0
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Expenses per Sheet:',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colors.onSurface),
                            ),
                            Text(
                              NumberFormatter.formatCurrency(_totalExpensesPerPaper),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD97706), fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Paper: ${NumberFormatter.formatCurrency(_currentBuyingPrice)}  •  Ink: ${NumberFormatter.formatCurrency(_currentInkPrice)}  •  Service: ${NumberFormatter.formatCurrency(_currentServiceFee)}',
                                style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 16, color: colors.outlineVariant),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Net Profit per Paper:',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.onSurface),
                            ),
                            Text(
                              NumberFormatter.formatCurrency(_netProfitPerPaper),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _netProfitPerPaper >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Configurations Button
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSavingConfig ? null : _saveConfigurations,
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSavingConfig) ...[
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Saving & Syncing...',
                                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14),
                              ),
                            ] else ...[
                              const Icon(Iconsax.cloud_add, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                'Save & Sync Configurations',
                                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Cloud & Synchronization Tools
            _buildSectionHeader(context, 'Cloud & Synchronization', Iconsax.cloud_connection),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.cloud_change, color: Color(0xFF059669), size: 20),
                    ),
                    title: Text('Pull Records from Cloud', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.onSurface)),
                    subtitle: Text('Fetch latest sales & payouts from other devices', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                    trailing: _isProcessing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Iconsax.arrow_right_3, size: 16, color: colors.onSurfaceVariant),
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
                                  backgroundColor: const Color(0xFF059669),
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
                  Divider(height: 1, indent: 56, color: colors.outlineVariant),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Iconsax.cloud_add, color: colors.primary, size: 20),
                    ),
                    title: Text('Push Unsynced Records', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.onSurface)),
                    subtitle: Text('${recordProvider.pendingSyncRecordsCount} pending local record(s) waiting', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                    trailing: Icon(Iconsax.arrow_right_3, size: 16, color: colors.onSurfaceVariant),
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
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // System & Database Info
            _buildSectionHeader(context, 'System & Storage Engine', Iconsax.cpu),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Iconsax.folder_2, color: colors.onSurfaceVariant, size: 20),
                    ),
                    title: Text('Local SQLite Store', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.onSurface)),
                    subtitle: Text('${NumberFormatter.format(recordProvider.records.length)} print sales saved on device', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                  ),
                  Divider(height: 1, indent: 56, color: colors.outlineVariant),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.shield_tick, color: Color(0xFF059669), size: 20),
                    ),
                    title: Text('Offline Database Version', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.onSurface)),
                    subtitle: Text('SQLite v5 (with real-time cloud bidirectional schema)', style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 17, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigInputField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: colors.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: colors.onSurfaceVariant.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, size: 20, color: colors.onSurfaceVariant),
        prefixText: prefixText,
        prefixStyle: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
        suffixText: suffixText,
        suffixStyle: TextStyle(fontSize: 12, color: colors.onSurfaceVariant, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      validator: validator,
    );
  }
}
