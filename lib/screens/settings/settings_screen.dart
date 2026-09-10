import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../providers/security_provider.dart';
import '../../services/auth_service.dart';
import '../security/setup_pin_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        children: [
          // Profile / Workspace Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFBAE6FD),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Iconsax.printer5,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.email ?? 'Vector Printing Staff',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user?.isAdmin == true
                                ? 'Administrator'
                                : 'Staff Terminal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Security & App Lock Section
          _SectionTitle(
            title: 'Security & App Lock',
            icon: Iconsax.shield_security,
          ),
          const SizedBox(height: 10),
          Consumer<SecurityProvider>(
            builder: (context, security, _) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
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
                    // Main Toggle: App Lock
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                      secondary: _buildIconBadge(
                        icon: Iconsax.lock,
                        color: const Color(0xFF0284C7),
                        bgColor: colors.primaryContainer,
                      ),
                      title: const Text(
                        'Passcode / App Lock',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        security.hasPin
                            ? (security.isSecurityEnabled
                                  ? 'Locked when exiting app'
                                  : 'Lock is currently paused')
                            : 'Set a 4-digit PIN to secure your app',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      value: security.isSecurityEnabled,
                      activeThumbColor: const Color(0xFF0284C7),
                      onChanged: (enabled) async {
                        if (enabled) {
                          if (!security.hasPin) {
                            // Show setup PIN modal
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const SetupPinDialog(),
                            );
                          } else {
                            await security.toggleAppLock(true);
                          }
                        } else {
                          // Prompt confirm disable
                          final shouldDisable = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text(
                                'Turn Off App Lock?',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              content: const Text(
                                'Anyone who accesses this phone will be able to view print sales without entering a PIN.',
                                style: TextStyle(fontSize: 13.5),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Turn Off'),
                                ),
                              ],
                            ),
                          );
                          if (shouldDisable == true) {
                            await security.toggleAppLock(false);
                          }
                        }
                      },
                    ),

                    // Change PIN Option (Visible if PIN exists)
                    if (security.hasPin) ...[
                      Divider(
                        height: 1,
                        indent: 64,
                        color: colors.outlineVariant,
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                        leading: _buildIconBadge(
                          icon: Iconsax.key,
                          color: const Color(0xFF8B5CF6),
                          bgColor: const Color(0xFF8B5CF6)
                              .withValues(alpha: 0.12),
                        ),
                        title: const Text(
                          'Change PIN Code',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        subtitle: Text(
                          'Update your existing 4-digit security PIN',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Iconsax.arrow_right_3,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                const SetupPinDialog(isChanging: true),
                          );
                        },
                      ),
                    ],

                    // Fingerprint / Biometric Option
                    if (security.hasPin) ...[
                      Divider(
                        height: 1,
                        indent: 64,
                        color: colors.outlineVariant,
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 4,
                        ),
                        secondary: _buildIconBadge(
                          icon: Iconsax.finger_scan,
                          color: const Color(0xFF10B981),
                          bgColor: const Color(0xFF10B981)
                              .withValues(alpha: 0.12),
                        ),
                        title: const Text(
                          'Fingerprint Unlock',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        subtitle: Text(
                          'Unlock instantly using your biometric sensor',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        value: security.isBiometricEnabled,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) async {
                          final err = await security.setBiometricEnabled(val);
                          if (!context.mounted) return;
                          if (err != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(err)),
                                  ],
                                ),
                                backgroundColor: Colors.red.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          } else if (val) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: const [
                                    Icon(Iconsax.finger_scan, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Fingerprint unlock enabled!'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF059669),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                      ),
                    ],

                    // Security Info Note
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.info_circle,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'When enabled, minimizing or leaving Vector Printing locks the app automatically.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // Appearance Section
          _SectionTitle(title: 'Appearance', icon: Iconsax.brush_1),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Consumer<ThemeProvider>(
              builder: (context, theme, _) => Column(
                children: [
                  _ThemeOption(
                    icon: Iconsax.mobile,
                    title: 'Use device settings',
                    subtitle: 'Automatically sync with your system theme',
                    selected: theme.themeMode == ThemeMode.system,
                    onTap: () => theme.setThemeMode(ThemeMode.system),
                  ),
                  Divider(height: 1, indent: 64, color: colors.outlineVariant),
                  _ThemeOption(
                    icon: Iconsax.sun_1,
                    title: 'Light Theme',
                    subtitle: 'Clean, high-contrast daylight mode',
                    selected: theme.themeMode == ThemeMode.light,
                    onTap: () => theme.setThemeMode(ThemeMode.light),
                  ),
                  Divider(height: 1, indent: 64, color: colors.outlineVariant),
                  _ThemeOption(
                    icon: Iconsax.moon,
                    title: 'Dark Theme',
                    subtitle: 'Deep slate theme for night environments',
                    selected: theme.themeMode == ThemeMode.dark,
                    onTap: () => theme.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // About Section
          _SectionTitle(title: 'About System', icon: Iconsax.info_circle),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildIconBadge(
                      icon: Iconsax.verify,
                      color: const Color(0xFF0284C7),
                      bgColor: colors.primaryContainer,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vector Printing Workspace',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Production POS & Biometric Inventory Suite',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'v0.1.0',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildIconBadge({
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      ),
    ],
  );
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : colors.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: selected ? colors.primary : colors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
      ),
      trailing: selected
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            )
          : null,
    );
  }
}
