import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../../shared/models/chat_message_item.dart';
import '../../../shared/widgets/primary_scaffold.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _input = TextEditingController();
  late Future<List<ChatMessageItem>> _messagesFuture;

  @override
  void initState() {
    super.initState();
    _messagesFuture = Future.value(const []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    final eventId = app.selectedEventId;
    if (eventId != null) {
      _messagesFuture = app.api.getChatMessages(app.session!.token, eventId);
    }
  }

  Future<void> _send() async {
    final app = AppScope.of(context);
    final eventId = app.selectedEventId;
    if (eventId == null || _input.text.trim().isEmpty) return;
    await app.api.sendChatMessage(app.session!.token, eventId, _input.text.trim());
    _input.clear();
    setState(() {
      _messagesFuture = app.api.getChatMessages(app.session!.token, eventId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final eventId = app.selectedEventId;

    return PrimaryScaffold(
      title: 'Чат по событию',
      action: IconButton(
        onPressed: () {
          if (eventId != null) {
            setState(() {
              _messagesFuture = app.api.getChatMessages(app.session!.token, eventId);
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
                child: Text('Сначала выберите событие в разделе "Сеансы".'),
              ),
            )
          else
            Expanded(
              child: FutureBuilder<List<ChatMessageItem>>(
                future: _messagesFuture,
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
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                              Text(message.authorName, style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(height: 4),
                              Text(message.text),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: eventId != null,
                  decoration: const InputDecoration(hintText: 'Введите сообщение...'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: eventId == null ? null : _send, child: const Text('Отправить')),
            ],
          ),
        ],
      ),
    );
  }
}
