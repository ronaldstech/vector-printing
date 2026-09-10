import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../providers/security_provider.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String _errorMessage = '';
  bool _isVerifying = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    // Automatically prompt for fingerprint upon showing lock screen if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometricAuthIfAvailable();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometricAuthIfAvailable() async {
    final security = Provider.of<SecurityProvider>(context, listen: false);
    if (security.isBiometricEnabled && security.canUseBiometrics) {
      await security.unlockWithBiometrics();
    }
  }

  void _onDigitPressed(String digit) {
    if (_isVerifying) return;
    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = '');
    }

    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_isVerifying) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);
    final security = Provider.of<SecurityProvider>(context, listen: false);
    final isMatch = await security.unlockWithPin(_enteredPin);

    if (!mounted) return;

    if (!isMatch) {
      _shakeController.forward(from: 0.0);
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Incorrect PIN. Try again.';
        _enteredPin = '';
      });
    } else {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final security = Provider.of<SecurityProvider>(context);

    return PopScope(
      canPop: false, // Prevent dismissing with back button
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              // App Brand / Security Header
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.lock5,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Vector Printing',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'App is locked. Enter your 4-digit PIN',
                style: TextStyle(
                  fontSize: 13.5,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // PIN Indicators with Shake Animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * (_shakeController.isAnimating ? 1 : 0), 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? colors.primary : colors.surfaceContainerHighest,
                        border: Border.all(
                          color: isFilled ? colors.primary : colors.outlineVariant,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _errorMessage.isNotEmpty ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _errorMessage.isNotEmpty ? _errorMessage : ' ',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const Spacer(),

              // Numeric Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 18),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 18),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Fingerprint Quick Action Button (if enabled)
                        if (security.isBiometricEnabled)
                          InkWell(
                            onTap: () async {
                              final unlocked = await security.unlockWithBiometrics();
                              if (!unlocked && mounted) {
                                setState(() {
                                  _errorMessage = 'Biometric scan was unsuccessful or cancelled.';
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(36),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primaryContainer.withValues(alpha: 0.7),
                              ),
                              child: Icon(
                                Iconsax.finger_scan,
                                color: colors.primary,
                                size: 30,
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 72, height: 72),

                        _buildKeypadButton('0'),

                        // Backspace Button
                        InkWell(
                          onTap: _onDeletePressed,
                          borderRadius: BorderRadius.circular(36),
                          child: Container(
                            width: 72,
                            height: 72,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.backspace_outlined,
                              size: 26,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
      ),
    );
  }
}
