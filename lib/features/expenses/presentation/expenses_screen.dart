import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../../shared/models/event_item.dart';
import '../../../shared/widgets/primary_scaffold.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  Future<List<EventItem>>? _eventsFuture;
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
      _eventsFuture = app.api.getEvents(app.session!.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrimaryScaffold(
      title: 'Аналитика',
      action: IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
      body: _eventsFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<EventItem>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final events = snapshot.data ?? const [];
                if (events.isEmpty) {
                  return const Center(child: Text('Данных пока нет'));
                }

                final totalHours = events.fold<double>(
                  0,
                  (sum, e) => sum + e.endAt.difference(e.startAt).inMinutes / 60,
                );

                return ListView(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _kpi('Всего записей', '${events.length}'),
                            _kpi('Часов занято', totalHours.toStringAsFixed(1)),
                            _kpi('Категорий', '${events.map((e) => e.category).toSet().length}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Последние записи', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...events.take(10).map(
                          (e) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(e.title),
                              subtitle: Text('${e.category} • ${_dt(e.startAt)} - ${_dt(e.endAt)}'),
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
    );
  }

  Widget _kpi(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6C6678))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ],
    );
  }

  String _dt(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm $hh:$mi';
  }
}
