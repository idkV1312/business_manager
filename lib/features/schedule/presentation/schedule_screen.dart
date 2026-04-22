import 'package:business_manager/core/di/app_scope.dart';
import 'package:business_manager/shared/models/auth_session.dart';
import 'package:business_manager/shared/models/event_item.dart';
import 'package:business_manager/shared/models/performer_item.dart';
import 'package:business_manager/shared/models/service_type.dart';
import 'package:business_manager/shared/widgets/primary_scaffold.dart';
import 'package:flutter/material.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Future<List<EventItem>>? _eventsFuture;
  bool _bootstrapped = false;
  DateTime _selectedDate = DateTime.now();
  bool _performerShowAll = false;
  int? _selectedPerformerId;

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

  Future<void> _book(int eventId) async {
    final app = AppScope.of(context);
    await app.api.bookEvent(app.session!.token, eventId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Запись подтверждена')),
    );
    _reload();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<EventItem> _filterForRole(List<EventItem> events, UserRole role, int userId) {
    var filtered = events.where((e) => _isSameDay(e.startAt, _selectedDate)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    if (role == UserRole.performer && !_performerShowAll) {
      filtered = filtered.where((e) => e.performerUserIds.contains(userId)).toList();
    }

    if (role == UserRole.user && _selectedPerformerId != null) {
      filtered = filtered.where((e) => e.performerIds.contains(_selectedPerformerId)).toList();
    }

    return filtered;
  }

  void _openEventDetails(EventItem event) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Категория: ${event.category}'),
            const SizedBox(height: 8),
            Text('Время: ${_dt(event.startAt)} - ${_dt(event.endAt)}'),
            const SizedBox(height: 8),
            Text('Исполнитель: ${event.performerNames.isEmpty ? 'Не назначен' : event.performerNames.join(', ')}'),
            const SizedBox(height: 8),
            Text(event.isBooked ? (event.bookedByMe ? 'Статус: вы записаны' : 'Статус: занято') : 'Статус: свободно'),
            if (event.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Описание: ${event.description.trim()}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final role = app.session!.role;

    return PrimaryScaffold(
      title: role == UserRole.user ? 'Календарь записи' : 'Календарь событий',
      action: IconButton(
        onPressed: () async {
          if (role == UserRole.admin || role == UserRole.performer) {
            final createdEvent = await showDialog<EventItem>(
              context: context,
              builder: (_) => _CreateSlotDialog(isPerformer: role == UserRole.performer),
            );
            if (createdEvent != null) {
              app.selectEvent(createdEvent.id);
              setState(() => _selectedDate = createdEvent.startAt);
              _reload();
              if (!mounted) return;
              _openEventDetails(createdEvent);
            }
            return;
          }
          _reload();
        },
        icon: Icon((role == UserRole.admin || role == UserRole.performer) ? Icons.add_circle_outline : Icons.refresh_rounded),
      ),
      body: _eventsFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<EventItem>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
                }
                final events = snapshot.data ?? const [];
                final dayEvents = _filterForRole(events, role, app.session!.userId);

                final performersById = <int, String>{};
                for (final event in events) {
                  for (var i = 0; i < event.performerIds.length; i++) {
                    final id = event.performerIds[i];
                    final name = i < event.performerNames.length ? event.performerNames[i] : 'Исполнитель #$id';
                    performersById[id] = name;
                  }
                }

                return Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Дата: ${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                      initialDate: _selectedDate,
                                    );
                                    if (date != null) {
                                      setState(() => _selectedDate = date);
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_month_outlined),
                                  label: const Text('Выбрать дату'),
                                ),
                              ],
                            ),
                            if (role == UserRole.performer) ...[
                              const SizedBox(height: 10),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(value: false, label: Text('Мои события')),
                                  ButtonSegment(value: true, label: Text('Все события')),
                                ],
                                selected: {_performerShowAll},
                                onSelectionChanged: (v) => setState(() => _performerShowAll = v.first),
                              ),
                            ],
                            if (role == UserRole.user && performersById.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              DropdownButtonFormField<int?>(
                                value: _selectedPerformerId,
                                decoration: const InputDecoration(labelText: 'Исполнитель'),
                                items: [
                                  const DropdownMenuItem<int?>(value: null, child: Text('Все исполнители')),
                                  ...performersById.entries.map(
                                    (e) => DropdownMenuItem<int?>(value: e.key, child: Text(e.value)),
                                  ),
                                ],
                                onChanged: (value) => setState(() => _selectedPerformerId = value),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: dayEvents.isEmpty
                          ? const Center(child: Text('На выбранную дату свободных слотов нет'))
                          : ListView.separated(
                              itemCount: dayEvents.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final event = dayEvents[index];
                                final canBook = role == UserRole.user && !event.isBooked;
                                return Card(
                                  child: ListTile(
                                    onTap: () {
                                      app.selectEvent(event.id);
                                      _openEventDetails(event);
                                    },
                                    title: Text('${_time(event.startAt)} - ${_time(event.endAt)}  ${event.title}'),
                                    subtitle: Text(
                                      '${event.category}\n${event.performerNames.join(', ')}\n'
                                      '${event.isBooked ? (event.bookedByMe ? 'Вы уже записаны' : 'Занято') : 'Свободно'}',
                                    ),
                                    isThreeLine: true,
                                    trailing: canBook
                                        ? FilledButton.tonal(
                                            onPressed: () => _book(event.id),
                                            child: const Text('Записаться'),
                                          )
                                        : const Icon(Icons.chevron_right_rounded),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  String _dt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _time(DateTime dt) {
    final d = dt.toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _CreateSlotDialog extends StatefulWidget {
  const _CreateSlotDialog({required this.isPerformer});

  final bool isPerformer;

  @override
  State<_CreateSlotDialog> createState() => _CreateSlotDialogState();
}

class _CreateSlotDialogState extends State<_CreateSlotDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();

  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  DateTime _end = DateTime.now().add(const Duration(hours: 2));
  List<PerformerItem> _performers = const [];
  List<ServiceTypeItem> _services = const [];
  final Set<int> _selectedPerformers = {};
  int? _selectedServiceId;

  bool _loading = true;
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = AppScope.of(context);
    final token = app.session!.token;
    final services = await app.api.getServices(token);
    final performers = widget.isPerformer ? const <PerformerItem>[] : await app.api.getPerformers(token);
    if (!mounted) return;
    setState(() {
      _services = services;
      _performers = performers;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final app = AppScope.of(context);
    ServiceTypeItem? selectedService;
    for (final service in _services) {
      if (service.id == _selectedServiceId) {
        selectedService = service;
        break;
      }
    }

    final title = _title.text.trim().isEmpty ? (selectedService?.title ?? '') : _title.text.trim();
    final category = _category.text.trim().isEmpty ? (selectedService?.category ?? '') : _category.text.trim();
    final endAt = selectedService != null ? _start.add(Duration(minutes: selectedService.durationMinutes)) : _end;

    if (title.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название и категорию или выберите услугу')),
      );
      return;
    }

    if (!widget.isPerformer && _selectedPerformers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного исполнителя')),
      );
      return;
    }

    final created = await app.api.createEvent(
      app.session!.token,
      title: title,
      description: _description.text.trim(),
      category: category,
      startAt: _start,
      endAt: endAt,
      performerIds: _selectedPerformers.toList(),
    );
    if (!mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isPerformer ? 'Создать свой слот' : 'Новый слот'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: _selectedServiceId,
                      items: _services
                          .map((s) => DropdownMenuItem<int>(value: s.id, child: Text('${s.title} • ${s.durationMinutes} мин')))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedServiceId = value),
                      decoration: const InputDecoration(labelText: 'Услуга'),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: _title, decoration: const InputDecoration(labelText: 'Название')),
                    const SizedBox(height: 8),
                    TextField(controller: _category, decoration: const InputDecoration(labelText: 'Категория')),
                    const SizedBox(height: 8),
                    TextField(controller: _description, decoration: const InputDecoration(labelText: 'Описание')),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Начало: ${_start.toLocal()}'),
                      trailing: IconButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDate: _start,
                          );
                          if (date == null || !mounted) return;
                          setState(() {
                            _start = DateTime(date.year, date.month, date.day, _start.hour, _start.minute);
                          });
                        },
                        icon: const Icon(Icons.event),
                      ),
                    ),
                    if (!widget.isPerformer) ...[
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
        FilledButton(onPressed: _create, child: const Text('Создать')),
      ],
    );
  }
}
