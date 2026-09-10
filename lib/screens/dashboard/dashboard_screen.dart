import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../../providers/record_provider.dart';
import '../records/record_details_screen.dart';
import '../../utils/number_formatter.dart';

import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../auth/login_screen.dart';
import '../settings/app_configuration_screen.dart';
import '../settings/settings_screen.dart';
import '../../providers/theme_provider.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToPOS;
  final VoidCallback onNavigateToRecords;

  const DashboardScreen({
    super.key,
    required this.onNavigateToPOS,
    required this.onNavigateToRecords,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vector Printing',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  user?.isAdmin == true ? 'Admin Workspace' : 'Staff Workspace',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: user?.isAdmin == true
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // User role avatar & modern dropdown menu
          PopupMenuButton<String>(
            offset: const Offset(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            elevation: 12,
            color: Theme.of(context).colorScheme.surface,
            shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.12),
            icon: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: user?.isAdmin == true
                      ? [const Color(0xFF0284C7), const Color(0xFF0369A1)]
                      : [const Color(0xFF10B981), const Color(0xFF059669)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (user?.isAdmin == true
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF10B981))
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: Text(
                  user?.email.isNotEmpty == true
                      ? user!.email[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: user?.isAdmin == true
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF059669),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            itemBuilder: (ctx) => [
              // User Profile Header Info
              PopupMenuItem(
                enabled: false,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: user?.isAdmin == true
                            ? const Color(0xFFE0F2FE)
                            : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        user?.isAdmin == true ? Iconsax.security_user : Iconsax.user,
                        size: 20,
                        color: user?.isAdmin == true
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.email ?? 'User',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.isAdmin == true ? 'Administrator' : 'Standard User',
                            style: TextStyle(
                              fontSize: 11,
                              color: user?.isAdmin == true
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF059669),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),

              // Sync with Cloud
              PopupMenuItem(
                value: 'sync',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Iconsax.refresh,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Sync Cloud Records',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Upload local pending data',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'settings',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _menuRow(context, Iconsax.setting_2, 'Settings', 'Appearance and preferences'),
              ),
              PopupMenuItem(
                value: 'theme',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _menuRow(
                  context,
                  Theme.of(context).brightness == Brightness.dark ? Iconsax.sun_1 : Iconsax.moon,
                  'Change theme',
                  Theme.of(context).brightness == Brightness.dark ? 'Switch to light mode' : 'Switch to dark mode',
                ),
              ),

              if (user?.isAdmin == true) ...[
                const PopupMenuDivider(height: 1),
                // Configure App
                PopupMenuItem(
                  value: 'configure',
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _menuRow(
                    context,
                    Iconsax.setting_2,
                    'App Configuration',
                    'Pricing, paper & user rules',
                  ),
                ),
              ],

              const PopupMenuDivider(height: 1),

              // Logout
              PopupMenuItem(
                value: 'logout',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Iconsax.logout,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Logout',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (val) async {
              if (val == 'sync') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Syncing records to Cloud Firestore...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                final count = await SyncService().syncLocalRecordsToCloud();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        count > 0
                            ? 'Synced $count records to Firestore!'
                            : 'All records already synced.',
                      ),
                      backgroundColor: const Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } else if (val == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              } else if (val == 'theme') {
                final theme = context.read<ThemeProvider>();
                theme.setThemeMode(Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
              } else if (val == 'configure') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppConfigurationScreen(),
                  ),
                );
              } else if (val == 'logout') {
                SyncService().stopRealtimeSync();
                auth.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: Consumer<RecordProvider>(
        builder: (context, provider, child) {
          final records = provider.records;
          final recentRecords = records.take(5).toList();

          return RefreshIndicator(
            color: const Color(0xFF0284C7),
            onRefresh: () => provider.fetchRecords(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              children: [
                _buildWelcomeHeader(context),
                const SizedBox(height: 18),
                _buildHeroCard(context, provider),
                const SizedBox(height: 16),
                _buildOperationalMetrics(context, provider),
                const SizedBox(height: 14),
                _buildCostBreakdownCard(context, provider),
                const SizedBox(height: 20),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildRecentHeader(context),
                const SizedBox(height: 12),
                if (recentRecords.isEmpty)
                  _buildEmptyRecent(context)
                else
                  ...recentRecords.map(
                    (record) => _buildRecentItem(context, record),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, String title, String subtitle) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.status, size: 14, color: colors.primary),
              const SizedBox(width: 4),
              Text(
                'Live',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context, RecordProvider provider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Dark slate premium tone
            Color(0xFF0369A1), // Deep vibrant cyan
            Color(0xFF0284C7), // Primary brand accent
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle ambient graphics
          Positioned(
            right: -25,
            bottom: -25,
            child: Icon(
              Iconsax.wallet_3,
              size: 170,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            top: -20,
            right: 40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Iconsax.wallet_money,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Today\'s Gross Revenue',
                          style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.calendar_1, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('d MMM').format(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  NumberFormatter.formatCurrency(provider.totalToday),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.receipt_item,
                        color: Color(0xFF38BDF8),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${NumberFormatter.format(provider.todayRecords.length)} orders processed today',
                        style: const TextStyle(
                          color: Color(0xFFF1F5F9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalMetrics(BuildContext context, RecordProvider provider) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Papers Remaining
          Builder(
            builder: (context) {
              final isLowStock = provider.papersRemaining < 100;
              return Container(
                decoration: BoxDecoration(
                  color: isLowStock
                      ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: _buildMetricRow(
                  context: context,
                  icon: Iconsax.document_copy,
                  iconColor: isLowStock ? const Color(0xFFDC2626) : colors.primary,
                  iconBg: isLowStock
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : colors.primaryContainer,
                  title: 'Paper Stock Remaining',
                  subtitle: '${NumberFormatter.format(provider.totalPagesPrinted)} sheets printed so far',
                  value: NumberFormatter.format(provider.papersRemaining),
                  badgeLabel: isLowStock ? 'Low Stock (<100)' : 'In Stock',
                  badgeBg: isLowStock
                      ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                      : Colors.green.withValues(alpha: 0.12),
                  badgeTextColor: isLowStock
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669),
                ),
              );
            },
          ),
          Divider(height: 1, indent: 64, endIndent: 16, color: colors.outlineVariant),

          // 2. Pending Sync Records
          InkWell(
            onTap: provider.pendingSyncRecordsCount == 0
                ? null
                : () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Syncing records to Cloud Firestore...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    final count = await SyncService().syncLocalRecordsToCloud();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            count > 0
                                ? 'Synced $count records to Firestore!'
                                : 'All records already synced.',
                          ),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  },
            borderRadius: BorderRadius.circular(16),
            child: _buildMetricRow(
              context: context,
              icon: Iconsax.cloud_change,
              iconColor: provider.pendingSyncRecordsCount == 0
                  ? const Color(0xFF059669)
                  : const Color(0xFFD97706),
              iconBg: provider.pendingSyncRecordsCount == 0
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.amber.withValues(alpha: 0.15),
              title: 'Cloud Synchronization',
              subtitle: provider.pendingSyncRecordsCount == 0
                  ? 'All records up to date on server'
                  : '${provider.pendingSyncRecordsCount} local orders waiting · tap to sync',
              value: provider.pendingSyncRecordsCount == 0
                  ? 'Synced'
                  : '${provider.pendingSyncRecordsCount} queued',
              badgeLabel: provider.pendingSyncRecordsCount == 0 ? 'Optimal' : 'Needs Sync',
              badgeBg: provider.pendingSyncRecordsCount == 0
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.amber.withValues(alpha: 0.15),
              badgeTextColor: provider.pendingSyncRecordsCount == 0
                  ? const Color(0xFF059669)
                  : const Color(0xFFD97706),
            ),
          ),
          Divider(height: 1, indent: 64, endIndent: 16, color: colors.outlineVariant),

          // 3. Profit Today
          _buildMetricRow(
            context: context,
            icon: Iconsax.trend_up,
            iconColor: const Color(0xFF10B981),
            iconBg: Colors.green.withValues(alpha: 0.12),
            title: 'Net Profit Today',
            subtitle: '${NumberFormatter.formatCurrency(provider.config.netProfitPerPaper)} net per sheet printed',
            value: NumberFormatter.formatCurrency(provider.profitToday),
            badgeLabel: 'Profit Margin',
            badgeBg: Colors.green.withValues(alpha: 0.12),
            badgeTextColor: const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String value,
    required String badgeLabel,
    required Color badgeBg,
    required Color badgeTextColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostBreakdownCard(BuildContext context, RecordProvider provider) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBreakdownPill(
            context: context,
            icon: Iconsax.tag,
            label: 'Sale Price',
            value: NumberFormatter.formatCurrency(provider.config.pricePerPaper),
            color: colors.primary,
          ),
          Container(height: 28, width: 1, color: colors.outlineVariant),
          _buildBreakdownPill(
            context: context,
            icon: Iconsax.money_send,
            label: 'Cost / Page',
            value: NumberFormatter.formatCurrency(provider.config.totalExpensePerPaper),
            color: const Color(0xFFD97706),
          ),
          Container(height: 28, width: 1, color: colors.outlineVariant),
          _buildBreakdownPill(
            context: context,
            icon: Iconsax.money_recive,
            label: 'Net Margin',
            value: NumberFormatter.formatCurrency(provider.config.netProfitPerPaper),
            color: const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownPill({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        // Primary POS Action
        Expanded(
          flex: 6,
          child: Container(
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
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onNavigateToPOS,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.shop, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'New Sale / POS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Secondary View Records Action
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onNavigateToRecords,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.receipt_2_1, color: colors.onSurface, size: 19),
                      const SizedBox(width: 8),
                      Text(
                        'All Orders',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Iconsax.clock, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: onNavigateToRecords,
          icon: const Icon(Iconsax.arrow_right_3, size: 14),
          label: const Text('View All'),
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentItem(BuildContext context, dynamic record) {
    final bool hasBalance = record.balance > 0;
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecordDetailsScreen(record: record),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.receipt,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Customer & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.customerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${record.jobDescription} • ${DateFormat('dd MMM').format(record.timestamp)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            record.isSynced ? Iconsax.cloud_add : Iconsax.cloud_cross,
                            size: 13,
                            color: record.isSynced
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            record.isSynced ? 'Synced' : 'Queued',
                            style: TextStyle(
                              fontSize: 10,
                              color: record.isSynced
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Price & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      NumberFormatter.formatCurrency(record.totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasBalance
                            ? Colors.red.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasBalance
                            ? 'Due: ${NumberFormatter.formatCurrency(record.balance)}'
                            : '${record.paymentMode} • Paid',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: hasBalance
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRecent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.receipt_item,
              size: 36,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No orders created yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "New Sale / POS" above to record your first print job.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
