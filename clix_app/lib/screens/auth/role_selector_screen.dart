import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// Екран вибору ролі — відображається коли у користувача декілька ролей.
/// "Я пасажир" / "Я водій"
class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final roles = auth.user?.roles ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Оберіть роль'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Оберіть роль',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ви можете змінити роль у будь-який момент',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Картки вибору ролей
            Row(
              children: [
                if (roles.contains('PASSENGER'))
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.person_outline,
                      label: 'Я пасажир',
                      isSelected: auth.activeRole == 'PASSENGER',
                      onTap: () => auth.switchRole('PASSENGER'),
                    ),
                  ),
                if (roles.contains('PASSENGER') && roles.contains('DRIVER'))
                  const SizedBox(width: 16),
                if (roles.contains('DRIVER'))
                  Expanded(
                    child: _RoleCard(
                      icon: Icons.directions_car,
                      label: 'Я водій',
                      isSelected: auth.activeRole == 'DRIVER',
                      onTap: () => auth.switchRole('DRIVER'),
                    ),
                  ),
              ],
            ),
            if (roles.contains('DISPATCHER')) ...[
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.headset_mic,
                label: 'Диспетчер',
                isSelected: auth.activeRole == 'DISPATCHER',
                onTap: () => auth.switchRole('DISPATCHER'),
              ),
            ],
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: auth.activeRole != null
                    ? () {
                        // Навігація до головного екрану відповідно до ролі
                        Navigator.of(context).pushReplacementNamed('/home');
                      }
                    : null,
                child: const Text('Продовжити'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Картка вибору ролі з іконкою та анімацією
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? CLIXTheme.primary.withValues(alpha: 0.1)
              : CLIXTheme.surface,
          borderRadius: BorderRadius.circular(CLIXTheme.radiusLg),
          border: Border.all(
            color: isSelected ? CLIXTheme.primary : CLIXTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? CLIXTheme.primary : CLIXTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? CLIXTheme.primary : CLIXTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
