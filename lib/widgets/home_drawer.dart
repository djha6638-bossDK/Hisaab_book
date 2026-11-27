import 'package:flutter/material.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    required this.displayName,
    required this.onOpenSavedRecords,
    required this.onOpenRecurringExpenses,
    required this.onOpenDailyServices,
    required this.onOpenPaymentPeople,
    super.key,
  });

  final String displayName;
  final VoidCallback onOpenSavedRecords;
  final VoidCallback onOpenRecurringExpenses;
  final VoidCallback onOpenDailyServices;
  final VoidCallback onOpenPaymentPeople;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Hisaab Book',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _DrawerItem(
              key: const ValueKey<String>('drawer-saved-records'),
              icon: Icons.folder_open_outlined,
              label: 'Purane record',
              subtitle: 'Saved mahino ka hisaab',
              onTap: onOpenSavedRecords,
            ),
            _DrawerItem(
              key: const ValueKey<String>('drawer-recurring-expenses'),
              icon: Icons.repeat,
              label: 'Recurring kharch',
              subtitle: 'Har mahine ke fixed kharch',
              onTap: onOpenRecurringExpenses,
            ),
            _DrawerItem(
              key: const ValueKey<String>('drawer-daily-services'),
              icon: Icons.fact_check_outlined,
              label: 'Tuition & Milk',
              subtitle: 'Daily attendance aur amount',
              onTap: onOpenDailyServices,
            ),
            _DrawerItem(
              key: const ValueKey<String>('drawer-payment-people'),
              icon: Icons.people_outline,
              label: 'Payment log',
              subtitle: 'Logon ka payment hisaab',
              onTap: onOpenPaymentPeople,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(icon),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
