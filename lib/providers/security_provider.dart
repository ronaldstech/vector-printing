import 'package:flutter/material.dart';
import '../services/security_service.dart';

class SecurityProvider with ChangeNotifier {
  final SecurityService _securityService = SecurityService();

  bool _isInitialized = false;
  bool _isSecurityEnabled = false;
  bool _hasPin = false;
  bool _isBiometricEnabled = false;
  bool _canUseBiometrics = false;
  bool _isLocked = false;
  DateTime? _pausedTime;

  bool get isInitialized => _isInitialized;
  bool get isSecurityEnabled => _isSecurityEnabled;
  bool get hasPin => _hasPin;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get canUseBiometrics => _canUseBiometrics;
  bool get isLocked => _isLocked;

  SecurityProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _hasPin = await _securityService.hasPinSet();
    _isSecurityEnabled = (await _securityService.isSecurityEnabled()) && _hasPin;
    _canUseBiometrics = await _securityService.canCheckBiometrics();
    _isBiometricEnabled = (await _securityService.isBiometricEnabled()) && _canUseBiometrics;
    
    // If security is enabled when provider boots up, start locked
    if (_isSecurityEnabled) {
      _isLocked = true;
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  void handleAppPaused() {
    if (!_isSecurityEnabled) return;
    _pausedTime = DateTime.now();
    // App moved out / backgrounded -> Lock immediately
    _isLocked = true;
    notifyListeners();
  }

  void handleAppResumed() {
    if (!_isSecurityEnabled) return;
    if (_pausedTime != null) {
      _isLocked = true;
      notifyListeners();
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    final success = await _securityService.verifyPin(pin);
    if (success) {
      _isLocked = false;
      _pausedTime = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_isBiometricEnabled) return false;
    final success = await _securityService.authenticateWithBiometrics(
      reason: 'Scan fingerprint to unlock Vector Printing',
    );
    if (success) {
      _isLocked = false;
      _pausedTime = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> setPin(String pin) async {
    final ok = await _securityService.setPin(pin);
    if (ok) {
      _hasPin = true;
      _isSecurityEnabled = true;
      _isLocked = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<String?> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      final canAuth = await _securityService.canCheckBiometrics();
      if (!canAuth) {
        return 'Biometric sensor not detected or not supported on this device.';
      }
      final success = await _securityService.authenticateWithBiometrics(
        reason: 'Confirm your fingerprint to enable biometric unlock',
      );
      if (!success) {
        return 'Biometric authentication was cancelled or failed.';
      }
    }
    await _securityService.setBiometricEnabled(enabled);
    _isBiometricEnabled = enabled;
    notifyListeners();
    return null;
  }

  Future<void> toggleAppLock(bool enabled) async {
    if (!enabled) {
      await _securityService.setSecurityEnabled(false);
      _isSecurityEnabled = false;
      _isLocked = false;
      notifyListeners();
    } else {
      if (_hasPin) {
        await _securityService.setSecurityEnabled(true);
        _isSecurityEnabled = true;
        notifyListeners();
      }
    }
  }

  Future<void> removePinAndDisable() async {
    await _securityService.clearSecurity();
    _isSecurityEnabled = false;
    _hasPin = false;
    _isBiometricEnabled = false;
    _isLocked = false;
    notifyListeners();
  }
}
