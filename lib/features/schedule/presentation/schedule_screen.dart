import 'dart:math' as math;

import 'package:business_manager/core/di/app_scope.dart';
import 'package:business_manager/shared/models/auth_session.dart';
import 'package:business_manager/shared/models/event_item.dart';
import 'package:business_manager/shared/models/performer_item.dart';
import 'package:business_manager/shared/models/service_type.dart';
import 'package:business_manager/shared/widgets/primary_scaffold.dart';
import 'package:flutter/material.dart';

enum CalendarDisplayMode {
  cube,
  standard;

  String get storageValue => switch (this) {
    CalendarDisplayMode.cube => 'cube',
    CalendarDisplayMode.standard => 'standard',
  };

  String get title => switch (this) {
    CalendarDisplayMode.cube => 'Календарь «Кубиком»',
    CalendarDisplayMode.standard => 'Календарь «Обычный»',
  };

  IconData get icon => switch (this) {
    CalendarDisplayMode.cube => Icons.view_week_rounded,
    CalendarDisplayMode.standard => Icons.view_agenda_rounded,
  };

  static CalendarDisplayMode fromStorage(String? raw) {
    return switch (raw) {
      'cube' => CalendarDisplayMode.cube,
      _ => CalendarDisplayMode.standard,
    };
  }
}

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

  CalendarDisplayMode _calendarMode = CalendarDisplayMode.standard;
  bool _openingInitialModePicker = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _reload();
    _loadSavedCalendarMode();
  }

  void _reload() {
    final app = AppScope.of(context);
    setState(() {
      _eventsFuture = app.api.getEvents(app.session!.token);
    });
  }

  Future<void> _loadSavedCalendarMode() async {
    final app = AppScope.of(context);
    final savedMode = await app.getScheduleCalendarMode();
    if (!mounted) return;

    if (savedMode == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _openingInitialModePicker) return;
        _openingInitialModePicker = true;
        _openCalendarModeSetup(forceChoice: true).whenComplete(() {
          _openingInitialModePicker = false;
        });
      });
      return;
    }

    setState(() {
      _calendarMode = CalendarDisplayMode.fromStorage(savedMode);
    });
  }

  Future<void> _openCalendarModeSetup({bool forceChoice = false}) async {
    final selected = await Navigator.of(context).push<CalendarDisplayMode>(
      MaterialPageRoute(
        builder: (_) => _CalendarModeSetupScreen(
          initialMode: _calendarMode,
          forceChoice: forceChoice,
        ),
      ),
    );

    if (!mounted || selected == null) return;
    setState(() => _calendarMode = selected);
    await AppScope.of(context).setScheduleCalendarMode(selected.storageValue);
  }

  Future<void> _book(int eventId) async {
    final app = AppScope.of(context);
    await app.api.bookEvent(app.session!.token, eventId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Запись подтверждена')));
    _reload();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<EventItem> _filterForRole(
    List<EventItem> events,
    UserRole role,
    int userId,
  ) {
    var filtered =
        events.where((e) => _isSameDay(e.startAt, _selectedDate)).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    if (role == UserRole.performer && !_performerShowAll) {
      filtered = filtered
          .where((e) => e.performerUserIds.contains(userId))
          .toList();
    }

    if (role == UserRole.user && _selectedPerformerId != null) {
      filtered = filtered
          .where((e) => e.performerIds.contains(_selectedPerformerId))
          .toList();
    }

    return filtered;
  }

  Future<void> _openEventDetails(EventItem event) async {
    final app = AppScope.of(context);
    final role = app.session!.role;
    final canBook = role == UserRole.user && !event.isBooked;

    final shouldBook = await showDialog<bool>(
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
            Text(
              'Исполнитель: ${event.performerNames.isEmpty ? 'Не назначен' : event.performerNames.join(', ')}',
            ),
            const SizedBox(height: 8),
            Text(
              event.isBooked
                  ? (event.bookedByMe
                        ? 'Статус: вы записаны'
                        : 'Статус: занято')
                  : 'Статус: свободно',
            ),
            if (event.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Описание: ${event.description.trim()}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Закрыть'),
          ),
          if (canBook)
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Записаться'),
            ),
        ],
      ),
    );

    if (shouldBook == true) {
      await _book(event.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final role = app.session!.role;

    return PrimaryScaffold(
      title: role == UserRole.user ? 'Календарь записи' : 'Календарь событий',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Изменить вид календаря',
            onPressed: () => _openCalendarModeSetup(),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            onPressed: () async {
              if (role == UserRole.admin || role == UserRole.performer) {
                final createdEvent = await showDialog<EventItem>(
                  context: context,
                  builder: (_) => _CreateSlotDialog(
                    isPerformer: role == UserRole.performer,
                  ),
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
            icon: Icon(
              (role == UserRole.admin || role == UserRole.performer)
                  ? Icons.add_circle_outline
                  : Icons.refresh_rounded,
            ),
          ),
        ],
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
                  return Center(
                    child: Text('Ошибка загрузки: ${snapshot.error}'),
                  );
                }
                final events = snapshot.data ?? const [];
                final dayEvents = _filterForRole(
                  events,
                  role,
                  app.session!.userId,
                );

                final performersById = <int, String>{};
                for (final event in events) {
                  for (var i = 0; i < event.performerIds.length; i++) {
                    final id = event.performerIds[i];
                    final name = i < event.performerNames.length
                        ? event.performerNames[i]
                        : 'Исполнитель #$id';
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime.now().subtract(
                                        const Duration(days: 365),
                                      ),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                      initialDate: _selectedDate,
                                    );
                                    if (date != null) {
                                      setState(() => _selectedDate = date);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.calendar_month_outlined,
                                  ),
                                  label: const Text('Выбрать дату'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(_calendarMode.icon, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Вид: ${_calendarMode.title}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _openCalendarModeSetup(),
                                  child: const Text('Изменить'),
                                ),
                              ],
                            ),
                            if (role == UserRole.performer) ...[
                              const SizedBox(height: 10),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Мои события'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Все события'),
                                  ),
                                ],
                                selected: {_performerShowAll},
                                onSelectionChanged: (v) =>
                                    setState(() => _performerShowAll = v.first),
                              ),
                            ],
                            if (role == UserRole.user &&
                                performersById.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              DropdownButtonFormField<int?>(
                                initialValue: _selectedPerformerId,
                                decoration: const InputDecoration(
                                  labelText: 'Исполнитель',
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Все исполнители'),
                                  ),
                                  ...performersById.entries.map(
                                    (e) => DropdownMenuItem<int?>(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _selectedPerformerId = value,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: dayEvents.isEmpty
                          ? const Center(
                              child: Text(
                                'На выбранную дату свободных слотов нет',
                              ),
                            )
                          : switch (_calendarMode) {
                              CalendarDisplayMode.cube => _buildCubeCalendar(
                                dayEvents,
                                role,
                                app,
                              ),
                              CalendarDisplayMode.standard =>
                                _buildStandardCalendar(dayEvents, role, app),
                            },
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildStandardCalendar(
    List<EventItem> dayEvents,
    UserRole role,
    AppController app,
  ) {
    return ListView.separated(
      itemCount: dayEvents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final event = dayEvents[index];
        final canBook = role == UserRole.user && !event.isBooked;
        return Card(
          child: ListTile(
            onTap: () {
              app.selectEvent(event.id);
              _openEventDetails(event);
            },
            title: Text(
              '${_time(event.startAt)} - ${_time(event.endAt)}  ${event.title}',
            ),
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
    );
  }

  Widget _buildCubeCalendar(
    List<EventItem> dayEvents,
    UserRole role,
    AppController app,
  ) {
    final lanes = _buildTimelineLanes(dayEvents);
    final range = _resolveRangeHours(dayEvents);

    const timeColumnWidth = 62.0;
    const laneWidth = 170.0;
    const headerHeight = 46.0;
    const hourHeight = 86.0;

    final totalHours = range.endHour - range.startHour;
    final contentHeight = totalHours * hourHeight;
    final canvasHeight = headerHeight + contentHeight;
    final canvasWidth = timeColumnWidth + lanes.length * laneWidth;
    final dayStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: const [
            _StatusLegend(color: Color(0xFFFFE3D9), label: 'Свободно'),
            _StatusLegend(color: Color(0xFFE7EAF0), label: 'Занято'),
            _StatusLegend(color: Color(0xFFCDEFC8), label: 'Вы записаны'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: canvasWidth,
                        height: canvasHeight,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: ColoredBox(color: Color(0xFFF8FBFF)),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              right: 0,
                              height: headerHeight,
                              child: const ColoredBox(color: Colors.white),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              width: timeColumnWidth,
                              height: headerHeight,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: Color(0xFFD7DCE6)),
                                    bottom: BorderSide(
                                      color: Color(0xFFD7DCE6),
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Время',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF504A5D),
                                  ),
                                ),
                              ),
                            ),
                            for (var i = 0; i < lanes.length; i++)
                              Positioned(
                                left: timeColumnWidth + (i * laneWidth),
                                top: 0,
                                width: laneWidth,
                                height: headerHeight,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: i.isEven
                                        ? const Color(0xFFFFF7F4)
                                        : const Color(0xFFF2F8FF),
                                    border: Border(
                                      right: BorderSide(
                                        color: i == lanes.length - 1
                                            ? const Color(0xFFD7DCE6)
                                            : const Color(0xFFE5E9F1),
                                      ),
                                      bottom: const BorderSide(
                                        color: Color(0xFFD7DCE6),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    lanes[i].name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            for (var i = 0; i <= lanes.length; i++)
                              Positioned(
                                left: timeColumnWidth + (i * laneWidth),
                                top: headerHeight,
                                width: 1,
                                height: contentHeight,
                                child: const ColoredBox(
                                  color: Color(0xFFE3E8F2),
                                ),
                              ),
                            for (
                              var h = range.startHour;
                              h <= range.endHour;
                              h++
                            ) ...[
                              Positioned(
                                left: 0,
                                top:
                                    headerHeight +
                                    ((h - range.startHour) * hourHeight),
                                right: 0,
                                height: 1,
                                child: const ColoredBox(
                                  color: Color(0xFFD7DCE6),
                                ),
                              ),
                              Positioned(
                                left: 6,
                                top:
                                    headerHeight +
                                    ((h - range.startHour) * hourHeight) -
                                    9,
                                width: timeColumnWidth - 12,
                                child: Text(
                                  '${h.toString().padLeft(2, '0')}:00',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF625D70),
                                  ),
                                ),
                              ),
                              if (h != range.endHour)
                                Positioned(
                                  left: timeColumnWidth,
                                  top:
                                      headerHeight +
                                      ((h - range.startHour) * hourHeight) +
                                      (hourHeight / 2),
                                  right: 0,
                                  height: 1,
                                  child: const ColoredBox(
                                    color: Color(0xFFECEFF5),
                                  ),
                                ),
                            ],
                            for (final event in dayEvents)
                              ..._laneIndicesForEvent(lanes, event).map((
                                laneIndex,
                              ) {
                                final eventStartMinute = event.startAt
                                    .difference(dayStart)
                                    .inMinutes;
                                final eventEndMinute = math.max(
                                  event.endAt.difference(dayStart).inMinutes,
                                  eventStartMinute + 15,
                                );
                                final visibleStart = math.max(
                                  eventStartMinute,
                                  range.startHour * 60,
                                );
                                final visibleEnd = math.min(
                                  eventEndMinute,
                                  range.endHour * 60,
                                );
                                if (visibleEnd <= visibleStart) {
                                  return const SizedBox.shrink();
                                }

                                final top =
                                    headerHeight +
                                    (((visibleStart - (range.startHour * 60)) /
                                            60.0) *
                                        hourHeight) +
                                    4;
                                final height = math.max(
                                  40.0,
                                  (((visibleEnd - visibleStart) / 60.0) *
                                          hourHeight) -
                                      8,
                                );
                                final left =
                                    timeColumnWidth +
                                    (laneIndex * laneWidth) +
                                    6;
                                final canBook =
                                    role == UserRole.user && !event.isBooked;

                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: laneWidth - 12,
                                  height: height,
                                  child: Material(
                                    color: _eventColor(event, role),
                                    borderRadius: BorderRadius.circular(12),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () {
                                        app.selectEvent(event.id);
                                        _openEventDetails(event);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              event.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_time(event.startAt)} - ${_time(event.endAt)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF514B5D),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              canBook
                                                  ? 'Свободно • тап для записи'
                                                  : (event.isBooked
                                                        ? (event.bookedByMe
                                                              ? 'Вы записаны'
                                                              : 'Занято')
                                                        : 'Свободно'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF5F586C),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<_TimelineLane> _buildTimelineLanes(List<EventItem> dayEvents) {
    final lanesById = <int?, String>{};

    for (final event in dayEvents) {
      if (event.performerIds.isEmpty) {
        lanesById.putIfAbsent(null, () => 'Без исполнителя');
        continue;
      }

      for (var i = 0; i < event.performerIds.length; i++) {
        final id = event.performerIds[i];
        final fallback = 'Исполнитель #$id';
        final name = i < event.performerNames.length
            ? event.performerNames[i]
            : fallback;
        lanesById.putIfAbsent(id, () => name);
      }
    }

    if (lanesById.isEmpty) {
      lanesById[null] = 'Сеансы';
    }

    return lanesById.entries
        .map((entry) => _TimelineLane(id: entry.key, name: entry.value))
        .toList();
  }

  List<int> _laneIndicesForEvent(List<_TimelineLane> lanes, EventItem event) {
    final result = <int>[];

    if (event.performerIds.isEmpty) {
      final withoutPerformer = lanes.indexWhere((lane) => lane.id == null);
      if (withoutPerformer >= 0) {
        result.add(withoutPerformer);
      }
      return result;
    }

    for (final performerId in event.performerIds) {
      final laneIndex = lanes.indexWhere((lane) => lane.id == performerId);
      if (laneIndex >= 0 && !result.contains(laneIndex)) {
        result.add(laneIndex);
      }
    }

    if (result.isEmpty) {
      result.add(0);
    }

    return result;
  }

  _HourRange _resolveRangeHours(List<EventItem> dayEvents) {
    if (dayEvents.isEmpty) {
      return const _HourRange(startHour: 8, endHour: 20);
    }

    final dayStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    var minMinute = 24 * 60;
    var maxMinute = 0;

    for (final event in dayEvents) {
      final startMinute = event.startAt.difference(dayStart).inMinutes;
      final endMinute = math.max(
        event.endAt.difference(dayStart).inMinutes,
        startMinute + 15,
      );
      minMinute = math.min(minMinute, startMinute);
      maxMinute = math.max(maxMinute, endMinute);
    }

    var startHour = ((minMinute ~/ 60) - 1).clamp(0, 22).toInt();
    var endHour = (((maxMinute + 59) ~/ 60) + 1)
        .clamp(startHour + 1, 24)
        .toInt();

    if ((endHour - startHour) < 8) {
      final targetSpan = 8;
      final half = ((targetSpan - (endHour - startHour)) / 2).floor();
      startHour = (startHour - half).clamp(0, 24 - targetSpan).toInt();
      endHour = startHour + targetSpan;
    }

    return _HourRange(startHour: startHour, endHour: endHour);
  }

  Color _eventColor(EventItem event, UserRole role) {
    if (event.isBooked && event.bookedByMe) {
      return const Color(0xFFCDEFC8);
    }
    if (event.isBooked) {
      return const Color(0xFFE7EAF0);
    }
    if (role == UserRole.user) {
      return const Color(0xFFFFE3D9);
    }
    return const Color(0xFFD9ECFF);
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

class _TimelineLane {
  const _TimelineLane({required this.id, required this.name});

  final int? id;
  final String name;
}

class _HourRange {
  const _HourRange({required this.startHour, required this.endHour});

  final int startHour;
  final int endHour;
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFD5D8DF)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CalendarModeSetupScreen extends StatefulWidget {
  const _CalendarModeSetupScreen({
    required this.initialMode,
    required this.forceChoice,
  });

  final CalendarDisplayMode initialMode;
  final bool forceChoice;

  @override
  State<_CalendarModeSetupScreen> createState() =>
      _CalendarModeSetupScreenState();
}

class _CalendarModeSetupScreenState extends State<_CalendarModeSetupScreen> {
  late CalendarDisplayMode _selectedMode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceChoice,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Изменить вид календаря'),
          automaticallyImplyLeading: !widget.forceChoice,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Выберите календарь',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    children: [
                      _CalendarOptionCard(
                        title: CalendarDisplayMode.cube.title,
                        selected: _selectedMode == CalendarDisplayMode.cube,
                        preview: const _CubeCalendarPreview(),
                        onTap: () => setState(
                          () => _selectedMode = CalendarDisplayMode.cube,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _CalendarOptionCard(
                        title: CalendarDisplayMode.standard.title,
                        selected: _selectedMode == CalendarDisplayMode.standard,
                        preview: const _ClassicCalendarPreview(),
                        onTap: () => setState(
                          () => _selectedMode = CalendarDisplayMode.standard,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selectedMode),
                    child: Text(
                      widget.forceChoice ? 'Продолжить' : 'Сохранить',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarOptionCard extends StatelessWidget {
  const _CalendarOptionCard({
    required this.title,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFE39A85) : const Color(0xFFE3DFE6),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1AE39A85),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(height: 210, child: preview),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected
                        ? const Color(0xFFE39A85)
                        : const Color(0xFFCCBFC2),
                    size: 30,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CubeCalendarPreview extends StatelessWidget {
  const _CubeCalendarPreview();

  @override
  Widget build(BuildContext context) {
    Widget cube(Color color, double height, {String? text}) {
      return Container(
        width: 28,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: text == null
            ? null
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3E384B),
                ),
              ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(height: 8),
                Text(
                  '09:00',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B5567),
                  ),
                ),
                SizedBox(height: 42),
                Text(
                  '10:00',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B5567),
                  ),
                ),
                SizedBox(height: 40),
                Text(
                  '11:00',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B5567),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      cube(const Color(0xFFCBE8C4), 62),
                      const SizedBox(height: 8),
                      cube(const Color(0xFFCBE8C4), 98),
                    ],
                  ),
                  Column(
                    children: [
                      cube(const Color(0xFFFF8B8B), 94),
                      const SizedBox(height: 8),
                      cube(const Color(0xFFF8E7B4), 44, text: 'Перерыв'),
                    ],
                  ),
                  Column(
                    children: [
                      cube(const Color(0xFFCBE8C4), 122),
                      const SizedBox(height: 8),
                      cube(const Color(0xFFCBE8C4), 64),
                    ],
                  ),
                  Column(
                    children: [
                      cube(const Color(0xFFC9E7EF), 132),
                      const SizedBox(height: 8),
                      cube(const Color(0xFFC9E7EF), 54),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassicCalendarPreview extends StatelessWidget {
  const _ClassicCalendarPreview();

  @override
  Widget build(BuildContext context) {
    const days = ['7', '8', '9', '10', '11', '12', '13'];
    const row2 = ['14', '15', '16', '17', '18', '19', '20'];
    const row3 = ['21', '22', '23', '24', '25', '26', '27'];

    Widget dayCell(String value, {bool selected = false}) {
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? const Color(0xFFE49A87) : Colors.transparent,
        ),
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF3B3548),
          ),
        ),
      );
    }

    Widget row(List<String> values, {int selectedIndex = -1}) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < values.length; i++)
            dayCell(values[i], selected: i == selectedIndex),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFDDF1F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  row(days),
                  const SizedBox(height: 8),
                  row(row2, selectedIndex: 3),
                  const SizedBox(height: 8),
                  row(row3),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE39A85), width: 3),
              ),
              child: const Icon(Icons.add, color: Color(0xFFE39A85), size: 30),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
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
  final DateTime _end = DateTime.now().add(const Duration(hours: 2));
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
    final performers = widget.isPerformer
        ? const <PerformerItem>[]
        : await app.api.getPerformers(token);
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

    final title = _title.text.trim().isEmpty
        ? (selectedService?.title ?? '')
        : _title.text.trim();
    final category = _category.text.trim().isEmpty
        ? (selectedService?.category ?? '')
        : _category.text.trim();
    final endAt = selectedService != null
        ? _start.add(Duration(minutes: selectedService.durationMinutes))
        : _end;

    if (title.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните название и категорию или выберите услугу'),
        ),
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
                      initialValue: _selectedServiceId,
                      items: _services
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(
                                '${s.title} • ${s.durationMinutes} мин',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedServiceId = value),
                      decoration: const InputDecoration(labelText: 'Услуга'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Название'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _category,
                      decoration: const InputDecoration(labelText: 'Категория'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _description,
                      decoration: const InputDecoration(labelText: 'Описание'),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Начало: $_start'),
                      trailing: IconButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            initialDate: _start,
                          );
                          if (date == null || !mounted) return;
                          setState(() {
                            _start = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              _start.hour,
                              _start.minute,
                            );
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _create, child: const Text('Создать')),
      ],
    );
  }
}
