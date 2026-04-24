import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../../shared/models/auth_session.dart';
import '../../../shared/models/event_item.dart';
import '../../../shared/models/pending_staff_member.dart';
import '../../../shared/models/staff_member.dart';
import '../../../shared/models/work_point.dart';
import '../../../shared/widgets/primary_scaffold.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
    final app = AppScope.of(context);
    final role = app.session!.role;
    final theme = Theme.of(context);

    return PrimaryScaffold(
      title: 'Nika Studio',
      action: IconButton(
        onPressed: _reload,
        icon: const Icon(Icons.refresh_rounded),
      ),
      body: Column(
        children: [
          if (role == UserRole.admin) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Управление командой',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Подтвердите новых сотрудников и назначьте им рабочую точку.',
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => const _StaffApprovalDialog(),
                        );
                      },
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Подтверждение сотрудников'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _eventsFuture == null
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
                        return const Center(child: Text('Пока нет записей'));
                      }

                      final today = DateTime.now();
                      final todaysCount = events.where((e) {
                        final d = e.startAt.toLocal();
                        return d.year == today.year &&
                            d.month == today.month &&
                            d.day == today.day;
                      }).length;

                      return ListView(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _kpi('Всего записей', '${events.length}'),
                                  _kpi('Сегодня', '$todaysCount'),
                                  _kpi(
                                    'Исполнителей',
                                    '${_countPerformers(events)}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ближайшие записи',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ...events
                              .take(6)
                              .map(
                                (e) => Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    onTap: () => _openEventDetails(e),
                                    title: Text(e.title),
                                    subtitle: Text(
                                      '${e.category} • ${_dt(e.startAt)} - ${_dt(e.endAt)}',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  int _countPerformers(List<EventItem> events) {
    final set = <String>{};
    for (final event in events) {
      for (final name in event.performerNames) {
        set.add(name);
      }
    }
    return set.length;
  }

  String _dt(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm $hh:$mi';
  }

  Widget _kpi(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6C6678))),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ],
    );
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
            Text('Начало: ${_dt(event.startAt)}'),
            Text('Конец: ${_dt(event.endAt)}'),
            const SizedBox(height: 8),
            Text(
              'Исполнители: ${event.performerNames.isEmpty ? 'Не назначены' : event.performerNames.join(', ')}',
            ),
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
}

class _StaffApprovalDialog extends StatefulWidget {
  const _StaffApprovalDialog();

  @override
  State<_StaffApprovalDialog> createState() => _StaffApprovalDialogState();
}

class _StaffApprovalDialogState extends State<_StaffApprovalDialog> {
  List<PendingStaffMember> _pending = const [];
  List<StaffMember> _staff = const [];
  List<WorkPointItem> _workPoints = const [];
  final Map<int, int> _selectedWorkPoint = {};
  bool _loading = true;
  bool _bootstrapped = false;

  final _wpTitle = TextEditingController();
  final _wpAddress = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _load();
  }

  @override
  void dispose() {
    _wpTitle.dispose();
    _wpAddress.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = AppScope.of(context);
    final token = app.session!.token;
    final pending = await app.api.getPendingStaff(token);
    final points = await app.api.getWorkPoints(token);
    final staff = await app.api.getStaff(token);
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _workPoints = points;
      _staff = staff;
      for (final staff in pending) {
        if (!_selectedWorkPoint.containsKey(staff.id) && points.isNotEmpty) {
          _selectedWorkPoint[staff.id] = points.first.id;
        }
      }
      _loading = false;
    });
  }

  Future<void> _createWorkPoint() async {
    final app = AppScope.of(context);
    final title = _wpTitle.text.trim();
    final address = _wpAddress.text.trim();
    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название рабочей точки')),
      );
      return;
    }
    await app.api.createWorkPoint(
      app.session!.token,
      title: title,
      address: address,
    );
    _wpTitle.clear();
    _wpAddress.clear();
    await _load();
  }

  Future<void> _approve(PendingStaffMember staff) async {
    final app = AppScope.of(context);
    final workPointId = _selectedWorkPoint[staff.id];
    if (workPointId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала добавьте рабочую точку')),
      );
      return;
    }
    await app.api.approveStaff(
      app.session!.token,
      userId: staff.id,
      workPointId: workPointId,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Подтверждение сотрудников'),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Рабочие точки'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _wpTitle,
                      decoration: const InputDecoration(
                        labelText: 'Название точки',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _wpAddress,
                      decoration: const InputDecoration(labelText: 'Адрес'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _createWorkPoint,
                      child: const Text('Добавить рабочую точку'),
                    ),
                    const Divider(height: 28),
                    Text('Ожидают подтверждения: ${_pending.length}'),
                    const SizedBox(height: 8),
                    if (_pending.isEmpty)
                      const Text('Новых сотрудников нет')
                    else
                      ..._pending.map(
                        (staff) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  staff.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text('Логин: ${staff.email}'),
                                Text(
                                  'Пароль: ${staff.password.isEmpty ? 'не задан' : staff.password}',
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedWorkPoint[staff.id],
                                  items: _workPoints
                                      .map(
                                        (point) => DropdownMenuItem<int>(
                                          value: point.id,
                                          child: Text(
                                            '${point.title} (${point.address})',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(
                                      () =>
                                          _selectedWorkPoint[staff.id] = value,
                                    );
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Рабочая точка',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: _workPoints.isEmpty
                                        ? null
                                        : () => _approve(staff),
                                    child: const Text('Подтвердить'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const Divider(height: 28),
                    Text('Все сотрудники: ${_staff.length}'),
                    const SizedBox(height: 8),
                    if (_staff.isEmpty)
                      const Text('Сотрудников пока нет')
                    else
                      ..._staff.map(
                        (staff) => Card(
                          child: ListTile(
                            title: Text(staff.name),
                            subtitle: Text(
                              'Логин: ${staff.email}\n'
                              'Пароль: ${staff.password.isEmpty ? 'не задан' : staff.password}\n'
                              'Статус: ${staff.isApproved ? 'подтвержден' : 'ожидает'}',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
