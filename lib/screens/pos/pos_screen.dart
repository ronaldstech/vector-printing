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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Iconsax.shop,
                color: Color(0xFF0284C7),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'POS Terminal',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Quick Print Sale & Checkout',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
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
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              tooltip: 'Reset Form',
              icon: const Icon(Iconsax.refresh, size: 18, color: Color(0xFF475569)),
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
                title: 'Customer Details',
                icon: Iconsax.user_edit,
                child: TextFormField(
                  controller: _customerNameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Customer Name (Optional)',
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    hintText: 'Walk-in Customer / John Banda',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Iconsax.user, size: 20, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Quantity Configuration (Copies & Pages)
              _buildSectionCard(
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
                              const Text(
                                'Copies',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildCounterInput(
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
                                        color: isMatch ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isMatch ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        '$val',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isMatch ? Colors.white : const Color(0xFF475569),
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
                              const Text(
                                'Pages',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildCounterInput(
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
                                        color: isMatch ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isMatch ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        '$val',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isMatch ? Colors.white : const Color(0xFF475569),
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
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Iconsax.info_circle, size: 16, color: Color(0xFF0284C7)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Rate Per Sheet:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${NumberFormatter.formatCurrency(configuredPrice)}  •  ${NumberFormatter.format(totalSheets)} total sheet(s)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
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
                                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.3),
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
                                      color: isSelected ? Colors.white : const Color(0xFF475569),
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
                                        color: isSelected ? Colors.white : const Color(0xFF334155),
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
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
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
              Icon(icon, size: 18, color: const Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
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
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: Color(0xFF475569)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            onPressed: onDecrement,
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
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
            icon: const Icon(Icons.add, size: 16, color: Color(0xFF475569)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}
