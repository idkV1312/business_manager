import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../../shared/widgets/primary_scaffold.dart';

class DiscountsScreen extends StatelessWidget {
  const DiscountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rules = AppScope.of(context).repository.getDiscountRules();
    final theme = Theme.of(context);

    return PrimaryScaffold(
      title: 'Скидки',
      body: ListView(
        children: [
          Card(
            color: const Color(0xFFF3F7FF),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Глобальная скидка', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  const TextField(decoration: InputDecoration(hintText: '10%')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...rules.map(
            (r) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: const Color(0xFFEFF8F6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.service, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('${r.price} ₴ | ${r.duration} мин', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    const TextField(
                      decoration: InputDecoration(
                        hintText: 'Значение скидки',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 76),
        ],
      ),
    );
  }
}
