import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// Екран вибору ролі — відображається коли у користувача декілька ролей.
class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final roles = auth.user?.roles ?? [];
    final user = auth.user;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CLIXTheme.spaceLg),
          child: Column(
            children: [
              const Spacer(),

              // ── Привітання ──
              if (user?.firstName.isNotEmpty == true) ...[
                Text(
                  'Привіт, ${user!.firstName}! 👋',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: CLIXTheme.spaceSm),
              ],
              Text(
                'Оберіть роль',
                style: user?.firstName.isNotEmpty == true
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: CLIXTheme.spaceXs),
              Text(
                'Ви можете змінити роль у будь-який момент',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: CLIXTheme.spaceXl),

              // ── Картки вибору ролей ──
              Row(
                children: [
                  if (roles.contains('PASSENGER'))
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.person_rounded,
                        label: 'Пасажир',
                        subtitle: 'Замовити поїздку',
                        isSelected: auth.activeRole == 'PASSENGER',
                        onTap: () => auth.switchRole('PASSENGER'),
                      ),
                    ),
                  if (roles.contains('PASSENGER') && roles.contains('DRIVER'))
                    const SizedBox(width: CLIXTheme.spaceMd),
                  if (roles.contains('DRIVER'))
                    Expanded(
                      child: _RoleCard(
                        icon: Icons.directions_car_rounded,
                        label: 'Водій',
                        subtitle: 'Прийняти замовлення',
                        isSelected: auth.activeRole == 'DRIVER',
                        onTap: () => auth.switchRole('DRIVER'),
                      ),
                    ),
                ],
              ),
              if (roles.contains('DISPATCHER')) ...[
                const SizedBox(height: CLIXTheme.spaceMd),
                _RoleCard(
                  icon: Icons.headset_mic_rounded,
                  label: 'Диспетчер',
                  subtitle: 'Управляти замовленнями',
                  isSelected: auth.activeRole == 'DISPATCHER',
                  onTap: () => auth.switchRole('DISPATCHER'),
                ),
              ],

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Картка вибору ролі з іконкою та анімацією
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          vertical: CLIXTheme.spaceXl,
          horizontal: CLIXTheme.spaceMd,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? CLIXTheme.primary.withValues(alpha: 0.08)
              : CLIXTheme.surface,
          borderRadius: BorderRadius.circular(CLIXTheme.radiusXl),
          border: Border.all(
            color: isSelected ? CLIXTheme.primary : CLIXTheme.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CLIXTheme.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? CLIXTheme.primary
                    : CLIXTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.white : CLIXTheme.primary,
              ),
            ),
            const SizedBox(height: CLIXTheme.spaceMd),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? CLIXTheme.primary : CLIXTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CLIXTheme.spaceXs),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? CLIXTheme.primary.withValues(alpha: 0.7)
                    : CLIXTheme.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
