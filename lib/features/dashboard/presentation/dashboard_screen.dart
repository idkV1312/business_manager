import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../../shared/widgets/primary_scaffold.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    final today = repo.getWeekAppointments().take(2).toList();
    final theme = Theme.of(context);

    return PrimaryScaffold(
      title: 'Pulse Studio',
      action: IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
      body: ListView(
        children: [
          Text('Доброе утро', style: theme.textTheme.bodyLarge),
          Text('Ваша смена', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _kpi('Записи', '${today.length}')),
                  Expanded(child: _kpi('Выручка', '3400')),
                  Expanded(child: _kpi('Свободно', '2ч')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Ближайшие клиенты', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          ...today.map(
            (a) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.client, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(a.service, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 2),
                          Text('${a.start} - ${a.end}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chat_bubble_outline_rounded, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 72),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF59647B))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
