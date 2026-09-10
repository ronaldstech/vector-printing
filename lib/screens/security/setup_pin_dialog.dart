import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../providers/security_provider.dart';

class SetupPinDialog extends StatefulWidget {
  const SetupPinDialog({super.key, this.isChanging = false});
  final bool isChanging;

  @override
  State<SetupPinDialog> createState() => _SetupPinDialogState();
}

class _SetupPinDialogState extends State<SetupPinDialog> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';

  void _onDigitPressed(String digit) {
    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = '');
    }

    if (!_isConfirming) {
      if (_firstPin.length < 4) {
        setState(() {
          _firstPin += digit;
        });
        if (_firstPin.length == 4) {
          Future.delayed(const Duration(milliseconds: 180), () {
            if (mounted) {
              setState(() {
                _isConfirming = true;
              });
            }
          });
        }
      }
    } else {
      if (_confirmPin.length < 4) {
        setState(() {
          _confirmPin += digit;
        });
        if (_confirmPin.length == 4) {
          _finalizePin();
        }
      }
    }
  }

  void _onDeletePressed() {
    setState(() {
      _errorMessage = '';
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
        }
      } else {
        if (_firstPin.isNotEmpty) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        }
      }
    });
  }

  Future<void> _finalizePin() async {
    if (_firstPin == _confirmPin) {
      try {
        final security = Provider.of<SecurityProvider>(context, listen: false);
        final success = await security.setPin(_firstPin);
        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Iconsax.shield_tick, color: Colors.white),
                  SizedBox(width: 8),
                  Text('PIN successfully set and App Lock enabled!'),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context, true);
        } else {
          setState(() {
            _errorMessage = 'Failed to save PIN. Please try again.';
            _confirmPin = '';
            _firstPin = '';
            _isConfirming = false;
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Error saving PIN: $e';
          _confirmPin = '';
          _firstPin = '';
          _isConfirming = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _confirmPin = '';
        _firstPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentPin = _isConfirming ? _confirmPin : _firstPin;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.lock, color: colors.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            _isConfirming ? 'Confirm your 4-digit PIN' : (widget.isChanging ? 'Enter New 4-digit PIN' : 'Set a 4-digit PIN'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            _isConfirming
                ? 'Re-enter your PIN code to confirm'
                : 'This PIN will be required whenever you open or return to the app',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          // PIN Indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < currentPin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
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
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 28),
          // Keypad
          Column(
            children: [
              _buildKeypadRow(['1', '2', '3']),
              const SizedBox(height: 14),
              _buildKeypadRow(['4', '5', '6']),
              const SizedBox(height: 14),
              _buildKeypadRow(['7', '8', '9']),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 68, height: 68),
                  _buildKeypadButton('0'),
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: IconButton(
                      icon: const Icon(Icons.backspace_outlined),
                      iconSize: 24,
                      color: colors.onSurface,
                      onPressed: _onDeletePressed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
      ),
    );
  }
}
