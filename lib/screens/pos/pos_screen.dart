import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
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
  final List<String> _paymentModes = ['Cash', 'Airtel Money', 'TNM Mpamba', 'Bank'];
  String _selectedPaymentMode = 'Cash';

  double _pricePerPaper = 150.0;
  double _totalAmount = 0.0;
  bool _isSubmitting = false;

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

  void _quickSetCopies(int value) {
    _copiesController.text = value.toString();
    _calculateTotal();
  }

  void _quickSetPages(int value) {
    _pagesController.text = value.toString();
    _calculateTotal();
  }

  void _incrementCopies(int delta) {
    final cur = int.tryParse(_copiesController.text.trim()) ?? 1;
    final next = (cur + delta).clamp(1, 99999);
    _copiesController.text = next.toString();
    _calculateTotal();
  }

  void _incrementPages(int delta) {
    final cur = int.tryParse(_pagesController.text.trim()) ?? 1;
    final next = (cur + delta).clamp(1, 99999);
    _pagesController.text = next.toString();
    _calculateTotal();
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
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final customerName = _customerNameController.text.trim();
      final copies = int.parse(_copiesController.text.trim());
      final pages = int.parse(_pagesController.text.trim());
      final totalQuantity = copies * pages;

      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;
      final createdByEmail = user?.email;

      final newRecord = PrintingRecord(
        customerName: customerName.isEmpty ? 'Walk-in Customer' : customerName,
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
              const Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sale saved! ${NumberFormatter.formatCurrency(_totalAmount)} via $_selectedPaymentMode',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      _clearForm();
      widget.onOrderCompleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving sale: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
                Iconsax.shop,
                color: colors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POS Terminal',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Quick Print Sale & Checkout',
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: IconButton(
              tooltip: 'Reset Form',
              icon: Icon(Iconsax.refresh, size: 18, color: colors.onSurfaceVariant),
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              padding: EdgeInsets.zero,
              onPressed: _clearForm,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 18.0, 16.0, 96.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Customer Name Card
              _buildSectionCard(
                context: context,
                title: 'Customer Details',
                icon: Iconsax.user_edit,
                child: TextFormField(
                  controller: _customerNameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Customer Name (Optional)',
                    labelStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                    hintText: 'Walk-in Customer / John Banda',
                    hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13),
                    prefixIcon: Icon(Iconsax.user, size: 20, color: colors.onSurfaceVariant),
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
                ),
              ),
              const SizedBox(height: 16),

              // 2. Quantity Configuration (Copies & Pages)
              _buildSectionCard(
                context: context,
                title: 'Print Specification',
                icon: Iconsax.document_copy,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Copies Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Copies',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildCounterInput(
                                context: context,
                                controller: _copiesController,
                                icon: Iconsax.copy,
                                onDecrement: () => _incrementCopies(-1),
                                onIncrement: () => _incrementCopies(1),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Required';
                                  final n = int.tryParse(value);
                                  if (n == null || n <= 0) return '>= 1';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              // Quick Presets
                              Wrap(
                                spacing: 6,
                                children: [1, 2, 5, 10].map((val) {
                                  final isMatch = _copiesController.text == val.toString();
                                  return InkWell(
                                    onTap: () => _quickSetCopies(val),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isMatch ? colors.primary : colors.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isMatch ? colors.primary : colors.outlineVariant,
                                        ),
                                      ),
                                      child: Text(
                                        '$val',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isMatch ? Colors.white : colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Pages Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pages',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildCounterInput(
                                context: context,
                                controller: _pagesController,
                                icon: Iconsax.book_1,
                                onDecrement: () => _incrementPages(-1),
                                onIncrement: () => _incrementPages(1),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Required';
                                  final n = int.tryParse(value);
                                  if (n == null || n <= 0) return '>= 1';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              // Quick Presets
                              Wrap(
                                spacing: 6,
                                children: [1, 2, 5, 10].map((val) {
                                  final isMatch = _pagesController.text == val.toString();
                                  return InkWell(
                                    onTap: () => _quickSetPages(val),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isMatch ? colors.primary : colors.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isMatch ? colors.primary : colors.outlineVariant,
                                        ),
                                      ),
                                      child: Text(
                                        '$val',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isMatch ? Colors.white : colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Rate summary banner
                    Consumer<RecordProvider>(
                      builder: (context, provider, _) {
                        final configuredPrice = provider.config.pricePerPaper;
                        final totalSheets = (int.tryParse(_copiesController.text.trim()) ?? 0) *
                            (int.tryParse(_pagesController.text.trim()) ?? 0);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Iconsax.info_circle, size: 16, color: colors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Rate Per Sheet:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${NumberFormatter.formatCurrency(configuredPrice)}  •  ${NumberFormatter.format(totalSheets)} sheet(s)',
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: colors.onSurface,
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
              ),
              const SizedBox(height: 16),

              // 3. Payment Mode Selection Cards
              _buildSectionCard(
                context: context,
                title: 'Payment Method',
                icon: Iconsax.wallet_3,
                child: Column(
                  children: [
                    Row(
                      children: _paymentModes.map((mode) {
                        final isSelected = _selectedPaymentMode == mode;
                        IconData modeIcon;
                        if (mode == 'Airtel Money') {
                          modeIcon = Iconsax.mobile;
                        } else if (mode == 'TNM Mpamba') {
                          modeIcon = Iconsax.card;
                        } else if (mode == 'Bank') {
                          modeIcon = Iconsax.bank;
                        } else {
                          modeIcon = Iconsax.moneys;
                        }

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: InkWell(
                              onTap: () => setState(() => _selectedPaymentMode = mode),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? colors.primary : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? colors.primary : colors.outlineVariant,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colors.primary.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      modeIcon,
                                      size: 20,
                                      color: isSelected ? Colors.white : colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      mode,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? Colors.white : colors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 4. Grand Total & Checkout Box
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF0369A1),
                      Color(0xFF0284C7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.65, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Iconsax.calculator, color: Colors.white70, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Order Formula',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_copiesController.text.isEmpty ? '0' : _copiesController.text}c × ${_pagesController.text.isEmpty ? '0' : _pagesController.text}p @ ${NumberFormatter.formatCurrency(_pricePerPaper)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Charge',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _selectedPaymentMode,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Paid in full',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6EE7B7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            NumberFormatter.formatCurrency(_totalAmount),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 5. Submit Order Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _isSubmitting
                        ? [const Color(0xFF64748B), const Color(0xFF475569)]
                        : [const Color(0xFF0284C7), const Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSubmitting
                              ? const Color(0xFF64748B)
                              : const Color(0xFF0284C7))
                          .withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSubmitting ? null : _submitOrder,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSubmitting) ...[
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Saving Sale...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ] else ...[
                          const Icon(Iconsax.tick_circle, color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          const Text(
                            'Save Sale to Database',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
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
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildCounterInput({
    required BuildContext context,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required String? Function(String?) validator,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.remove, size: 16, color: colors.onSurfaceVariant),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            onPressed: onDecrement,
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
              onChanged: (_) => _calculateTotal(),
              validator: validator,
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 16, color: colors.onSurfaceVariant),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}
