import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../../shared/models/auth_session.dart';
import '../../../shared/models/event_item.dart';
import '../../../shared/models/performer_item.dart';
import '../../../shared/widgets/primary_scaffold.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Future<List<EventItem>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final app = AppScope.of(context);
    _eventsFuture = app.api.getEvents(app.session!.token);
  }

  Future<void> _book(int eventId) async {
    final app = AppScope.of(context);
    await app.api.bookEvent(app.session!.token, eventId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Запись подтверждена')));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final role = app.session!.role;

    return PrimaryScaffold(
      title: 'События',
      action: IconButton(
        onPressed: () async {
          if (role == UserRole.admin) {
            await showDialog<void>(context: context, builder: (_) => const _AdminCreateDialog());
            setState(_reload);
          }
        },
        icon: Icon(role == UserRole.admin ? Icons.add_circle_outline : Icons.refresh_rounded),
      ),
      body: FutureBuilder<List<EventItem>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }
          final events = snapshot.data ?? const [];
          if (events.isEmpty) {
            return const Center(child: Text('Пока нет событий'));
          }

          return ListView.separated(
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final e = events[index];
              return Card(
                child: ListTile(
                  onTap: () => app.selectEvent(e.id),
                  title: Text(e.title),
                  subtitle: Text(
                    '${e.category} • ${_dt(e.startAt)} - ${_dt(e.endAt)}\n${e.performerNames.join(', ')}',
                  ),
                  isThreeLine: true,
                  trailing: role == UserRole.user
                      ? FilledButton.tonal(
                          onPressed: () => _book(e.id),
                          child: const Text('Записаться'),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          );
        },
      ),
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

class _AdminCreateDialog extends StatefulWidget {
  const _AdminCreateDialog();

  @override
  State<_AdminCreateDialog> createState() => _AdminCreateDialogState();
}

class _AdminCreateDialogState extends State<_AdminCreateDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _performerName = TextEditingController();
  final _performerSpec = TextEditingController();
  final Set<int> _selectedPerformers = {};
  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  DateTime _end = DateTime.now().add(const Duration(hours: 2));
  List<PerformerItem> _performers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPerformers();
  }

  Future<void> _loadPerformers() async {
    final app = AppScope.of(context);
    final data = await app.api.getPerformers(app.session!.token);
    if (!mounted) return;
    setState(() {
      _performers = data;
      _loading = false;
    });
  }

  Future<void> _addPerformer() async {
    final app = AppScope.of(context);
    if (_performerName.text.trim().isEmpty || _performerSpec.text.trim().isEmpty) return;
    await app.api.createPerformer(
      app.session!.token,
      name: _performerName.text.trim(),
      specialization: _performerSpec.text.trim(),
    );
    _performerName.clear();
    _performerSpec.clear();
    await _loadPerformers();
  }

  Future<void> _createEvent() async {
    final app = AppScope.of(context);
    await app.api.createEvent(
      app.session!.token,
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category.text.trim(),
      startAt: _start,
      endAt: _end,
      performerIds: _selectedPerformers.toList(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новое событие'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Название')),
              const SizedBox(height: 8),
              TextField(controller: _category, decoration: const InputDecoration(labelText: 'Категория')),
              const SizedBox(height: 8),
              TextField(controller: _description, decoration: const InputDecoration(labelText: 'Описание')),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Старт: ${_start.toLocal()}'),
                trailing: IconButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _start,
                    );
                    if (date == null || !mounted) return;
                    setState(() => _start = DateTime(date.year, date.month, date.day, _start.hour, _start.minute));
                  },
                  icon: const Icon(Icons.event),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Конец: ${_end.toLocal()}'),
                trailing: IconButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _end,
                    );
                    if (date == null || !mounted) return;
                    setState(() => _end = DateTime(date.year, date.month, date.day, _end.hour, _end.minute));
                  },
                  icon: const Icon(Icons.event_available),
                ),
              ),
              const SizedBox(height: 8),
              TextField(controller: _performerName, decoration: const InputDecoration(labelText: 'Исполнитель')),
              const SizedBox(height: 8),
              TextField(controller: _performerSpec, decoration: const InputDecoration(labelText: 'Специализация')),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(onPressed: _addPerformer, child: const Text('Добавить исполнителя')),
              ),
              const SizedBox(height: 10),
              if (_loading) const CircularProgressIndicator() else ...[
                const Align(alignment: Alignment.centerLeft, child: Text('Назначить исполнителей')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _performers
                      .map(
                        (p) => FilterChip(
                          label: Text('${p.name} (${p.specialization})'),
                          selected: _selectedPerformers.contains(p.id),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPerformers.add(p.id);
                              } else {
                                _selectedPerformers.remove(p.id);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
        FilledButton(onPressed: _createEvent, child: const Text('Создать')),
      ],
    );
  }
}
