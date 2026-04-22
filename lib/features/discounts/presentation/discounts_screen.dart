import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../../shared/models/service_type.dart';
import '../../../shared/widgets/primary_scaffold.dart';

class DiscountsScreen extends StatefulWidget {
  const DiscountsScreen({super.key});

  @override
  State<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends State<DiscountsScreen> {
  Future<List<ServiceTypeItem>>? _servicesFuture;
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _reload();
  }

  void _reload() {
    final app = AppScope.of(context);
    setState(() {
      _servicesFuture = app.api.getServices(app.session!.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScaffold(
      title: 'Прайс-лист',
      action: IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
      body: _servicesFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<ServiceTypeItem>>(
              future: _servicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }
                final services = snapshot.data ?? const [];
                if (services.isEmpty) {
                  return const Center(child: Text('Услуги ещё не добавлены'));
                }
                return ListView.separated(
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = services[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFDE7EF),
                          child: Icon(Icons.local_offer_outlined),
                        ),
                        title: Text(item.title),
                        subtitle: Text('${item.category} • ${item.durationMinutes} мин'),
                        trailing: Text('${item.price} ₽'),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
