import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'database_helper.dart';

class SecurityService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Hash PIN for secure local verification
  String _hashPin(String pin) {
    return sha256.convert(utf8.encode('maufa_salt_$pin')).toString();
  }

  Future<bool> isSecurityEnabled() async {
    try {
      final settings = await _dbHelper.getSecuritySettings();
      return (settings?['isAppLockEnabled'] == 1) && (settings?['pinHash'] != null);
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPinSet() async {
    try {
      final settings = await _dbHelper.getSecuritySettings();
      final hash = settings?['pinHash'] as String?;
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    try {
      final settings = await _dbHelper.getSecuritySettings();
      return settings?['isBiometricEnabled'] == 1;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setPin(String pin) async {
    try {
      final hash = _hashPin(pin);
      await _dbHelper.saveSecuritySettings(
        pinHash: hash,
        isAppLockEnabled: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final settings = await _dbHelper.getSecuritySettings();
      final storedHash = settings?['pinHash'] as String?;
      if (storedHash == null) return false;
      return storedHash == _hashPin(pin);
    } catch (_) {
      return false;
    }
  }

  Future<void> setSecurityEnabled(bool enabled) async {
    try {
      await _dbHelper.saveSecuritySettings(isAppLockEnabled: enabled);
    } catch (_) {}
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _dbHelper.saveSecuritySettings(isBiometricEnabled: enabled);
    } catch (_) {}
  }

  Future<void> clearSecurity() async {
    try {
      await _dbHelper.clearSecuritySettings();
    } catch (_) {}
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to unlock Vector Printing',
  }) async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) return false;

      // Try authenticating with biometrics
      try {
        return await _localAuth.authenticate(
          localizedReason: reason,
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
      } catch (_) {
        // Fallback for devices where biometricOnly is strict or biometric sensor requires default dialog
        return await _localAuth.authenticate(
          localizedReason: reason,
          persistAcrossBackgrounding: true,
        );
      }
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
