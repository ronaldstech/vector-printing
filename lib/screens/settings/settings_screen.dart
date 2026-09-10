import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('Personalize your workspace', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Appearance', icon: Iconsax.brush_1),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Consumer<ThemeProvider>(
              builder: (context, theme, _) => Column(
                children: [
                  _ThemeOption(
                    icon: Iconsax.mobile,
                    title: 'Use device settings',
                    subtitle: 'Automatically follows your phone',
                    selected: theme.themeMode == ThemeMode.system,
                    onTap: () => theme.setThemeMode(ThemeMode.system),
                  ),
                  Divider(height: 1, indent: 64, color: colors.outlineVariant),
                  _ThemeOption(
                    icon: Iconsax.sun_1,
                    title: 'Light',
                    subtitle: 'Always use the light appearance',
                    selected: theme.themeMode == ThemeMode.light,
                    onTap: () => theme.setThemeMode(ThemeMode.light),
                  ),
                  Divider(height: 1, indent: 64, color: colors.outlineVariant),
                  _ThemeOption(
                    icon: Iconsax.moon,
                    title: 'Dark',
                    subtitle: 'Always use the dark appearance',
                    selected: theme.themeMode == ThemeMode.dark,
                    onTap: () => theme.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _SectionTitle(title: 'About', icon: Iconsax.info_circle),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: const ListTile(
              leading: Icon(Iconsax.printer),
              title: Text('Vector Printing', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Business workspace'),
            ),
          ),
          if (isDark) const SizedBox(height: 4),
        ],
      ),
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
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      );
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: colors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: Radio<bool>(value: true, groupValue: selected, onChanged: (_) => onTap()),
    );
  }
}
