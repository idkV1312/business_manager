import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../../shared/widgets/primary_scaffold.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = AppScope.of(context).repository.getExpenses();
    final total = expenses.fold<int>(0, (sum, e) => sum + e.amount);
    final theme = Theme.of(context);

    return PrimaryScaffold(
      title: 'Расходы',
      body: ListView(
        children: [
          Card(
            color: const Color(0xFF2E315D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Всего за месяц', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                  Text('₴$total', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...expenses.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(item.category, style: theme.textTheme.titleMedium),
                subtitle: Text('${item.date} | ${item.payment}', style: theme.textTheme.bodySmall),
                trailing: Text('₴${item.amount}', style: theme.textTheme.labelLarge),
              ),
            ),
          ),
          const SizedBox(height: 72),
        ],
      ),
    );
  }
}
