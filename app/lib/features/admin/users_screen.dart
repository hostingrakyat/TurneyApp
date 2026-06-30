import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/models/app_user.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';

final usersProvider = FutureProvider<List<AppUser>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    final me = ref.watch(authControllerProvider);
    return me == null ? const [] : [me];
  }
  final rows = await client
      .from('profiles')
      .select('id, display_name, role')
      .order('created_at');
  return (rows as List)
      .map((r) => AppUser.fromMap(r as Map<String, dynamic>))
      .toList();
});

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final users = ref.watch(usersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('admin.users'))),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            EmptyState(title: s.t('detail.loadError'), subtitle: '$e'),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final u = list[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.violet.withValues(alpha: 0.2),
                  child: Text(
                    u.displayName.isNotEmpty
                        ? u.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(u.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(u.email.isEmpty ? u.id : u.email),
                trailing: DropdownButton<UserRole>(
                  value: u.role,
                  underline: const SizedBox.shrink(),
                  onChanged: (role) {
                    if (role != null) {
                      ref
                          .read(authControllerProvider.notifier)
                          .setRole(u.id, role)
                          .then((_) => ref.invalidate(usersProvider));
                    }
                  },
                  items: UserRole.values
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ))
                      .toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
