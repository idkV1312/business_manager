import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../../shared/widgets/primary_scaffold.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = AppScope.of(context).repository.getProducts();
    final theme = Theme.of(context);

    return PrimaryScaffold(
      title: 'Склад',
      action: IconButton(onPressed: () {}, icon: const Icon(Icons.file_download_outlined)),
      body: ListView(
        children: [
          const SizedBox(height: 2),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Все')),
              Chip(label: Text('Lashes')),
              Chip(label: Text('Brows')),
            ],
          ),
          const SizedBox(height: 16),
          ...products.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('${item.category} | Остаток: ${item.stock}', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 2),
                          Text('${item.price} ₴', style: theme.textTheme.labelLarge),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
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
}
