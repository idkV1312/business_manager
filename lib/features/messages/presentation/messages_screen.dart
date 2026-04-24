import 'package:business_manager/core/di/app_scope.dart';
import 'package:business_manager/shared/models/auth_session.dart';
import 'package:business_manager/shared/models/chat_message_item.dart';
import 'package:business_manager/shared/models/chat_participant_item.dart';
import 'package:business_manager/shared/widgets/primary_scaffold.dart';
import 'package:flutter/material.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  late Future<List<ChatMessageItem>> _eventMessagesFuture;
  late Future<List<ChatMessageItem>> _directMessagesFuture;
  late Future<List<ChatParticipantItem>> _directUsersFuture;
  late TabController _tabController;
  int? _directUserId;

  @override
  void initState() {
    super.initState();
    _eventMessagesFuture = Future.value(const []);
    _directMessagesFuture = Future.value(const []);
    _directUsersFuture = Future.value(const []);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadAll();
  }

  void _reloadAll() {
    final app = AppScope.of(context);
    final eventId = app.selectedEventId;
    if (eventId != null) {
      _eventMessagesFuture = app.api.getChatMessages(
        app.session!.token,
        eventId,
      );
      _reloadDirectData();
    } else {
      _eventMessagesFuture = Future.value(const []);
      _directMessagesFuture = Future.value(const []);
      _directUsersFuture = Future.value(const []);
      _directUserId = null;
    }
  }

  void _reloadDirectData() {
    final app = AppScope.of(context);
    final eventId = app.selectedEventId;
    if (eventId == null) {
      _directMessagesFuture = Future.value(const []);
      return;
    }

    if (app.session!.role == UserRole.admin) {
      _directUsersFuture = app.api.getEventBookedUsers(
        app.session!.token,
        eventId,
      );
      _directMessagesFuture = _directUsersFuture.then((users) {
        if (users.isEmpty) {
          _directUserId = null;
          return const <ChatMessageItem>[];
        }
        _directUserId ??= users.first.id;
        return app.api.getDirectChatMessages(
          app.session!.token,
          eventId,
          userId: _directUserId,
        );
      });
      return;
    }

    if (app.session!.role == UserRole.user) {
      _directUsersFuture = Future.value(const []);
      _directMessagesFuture = app.api.getDirectChatMessages(
        app.session!.token,
        eventId,
      );
      return;
    }

    _directUsersFuture = Future.value(const []);
    _directMessagesFuture = Future.value(const []);
    _directUserId = null;
  }

  Future<void> _sendEventMessage() async {
    final app = AppScope.of(context);
    final eventId = app.selectedEventId;
    if (eventId == null || _input.text.trim().isEmpty) return;
    await app.api.sendChatMessage(
      app.session!.token,
      eventId,
      _input.text.trim(),
    );
    _input.clear();
    setState(() {
      _eventMessagesFuture = app.api.getChatMessages(
        app.session!.token,
        eventId,
      );
    });
  }

  Future<void> _sendDirectMessage() async {
    final app = AppScope.of(context);
    final eventId = app.selectedEventId;
    if (eventId == null || _input.text.trim().isEmpty) return;
    if (app.session!.role == UserRole.admin && _directUserId == null) return;

    await app.api.sendDirectChatMessage(
      app.session!.token,
      eventId,
      _input.text.trim(),
      userId: _directUserId,
    );
    _input.clear();
    setState(() {
      _directMessagesFuture = app.api.getDirectChatMessages(
        app.session!.token,
        eventId,
        userId: _directUserId,
      );
    });
  }

  Widget _buildMessagesList(Future<List<ChatMessageItem>> source) {
    final app = AppScope.of(context);
    return FutureBuilder<List<ChatMessageItem>>(
      future: source,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
        }
        final messages = snapshot.data ?? const [];
        if (messages.isEmpty) {
          return const Center(child: Text('Сообщений пока нет'));
        }

        return ListView.separated(
          itemCount: messages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMine = message.authorId == app.session!.userId;

            return Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMine ? const Color(0xFFDCEBFF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6ECF4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.authorName,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(message.text),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final eventId = app.selectedEventId;
    final isDirectTab = _tabController.index == 1;
    final canUseDirect =
        app.session!.role == UserRole.user ||
        app.session!.role == UserRole.admin;
    final canSend =
        eventId != null &&
        (!isDirectTab ||
            (canUseDirect &&
                (app.session!.role == UserRole.user || _directUserId != null)));

    return PrimaryScaffold(
      title: 'Сообщения',
      action: IconButton(
        onPressed: () {
          if (eventId != null) {
            setState(() {
              _reloadAll();
            });
          }
        },
        icon: const Icon(Icons.refresh_rounded),
      ),
      body: Column(
        children: [
          if (eventId == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Выберите событие в разделе "Расписание".'),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Чат по событию'),
                      Tab(text: 'Клиент и пользователь'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMessagesList(_eventMessagesFuture),
                        if (!canUseDirect)
                          const Center(
                            child: Text(
                              'Личный чат доступен только администратору и пользователю',
                            ),
                          )
                        else
                          Column(
                            children: [
                              if (app.session!.role == UserRole.admin)
                                FutureBuilder<List<ChatParticipantItem>>(
                                  future: _directUsersFuture,
                                  builder: (context, snapshot) {
                                    final users =
                                        snapshot.data ??
                                        const <ChatParticipantItem>[];
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const LinearProgressIndicator(
                                        minHeight: 2,
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          'Не удалось загрузить пользователей: ${snapshot.error}',
                                        ),
                                      );
                                    }
                                    if (users.isEmpty) {
                                      return const Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Нет пользователей с записью на событие',
                                        ),
                                      );
                                    }

                                    final selectedId =
                                        _directUserId ?? users.first.id;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: DropdownButtonFormField<int>(
                                        initialValue: selectedId,
                                        decoration: const InputDecoration(
                                          labelText: 'Пользователь',
                                        ),
                                        items: users
                                            .map(
                                              (user) => DropdownMenuItem<int>(
                                                value: user.id,
                                                child: Text(user.name),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _directUserId = value;
                                            _directMessagesFuture = app.api
                                                .getDirectChatMessages(
                                                  app.session!.token,
                                                  eventId,
                                                  userId: value,
                                                );
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              Expanded(
                                child: _buildMessagesList(
                                  _directMessagesFuture,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: canSend,
                  decoration: InputDecoration(
                    hintText: isDirectTab
                        ? 'Сообщение для личного чата...'
                        : 'Введите сообщение...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: canSend
                    ? (isDirectTab ? _sendDirectMessage : _sendEventMessage)
                    : null,
                child: const Text('Отправить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
