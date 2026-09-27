import 'package:flutter/material.dart';
import 'package:sms_inbox/sms_inbox.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const InboxPage(),
    );
  }
}

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _inbox = SmsInbox();
  List<SmsMessage>? _messages;
  String? _error;

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      if (!await _inbox.requestPermission()) {
        setState(() => _error = 'READ_SMS was not granted.');
        return;
      }
      // Last 7 days, read page by page. Messages come oldest first.
      final since = DateTime.now().subtract(const Duration(days: 7));
      final messages = <SmsMessage>[];
      await for (final page in _inbox.pages(since: since)) {
        messages.addAll(page);
      }
      setState(() => _messages = messages.reversed.toList());
    } on SmsInboxException catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    return Scaffold(
      appBar: AppBar(title: const Text('sms_inbox example')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _load,
        icon: const Icon(Icons.inbox),
        label: const Text('Read last 7 days'),
      ),
      body: switch ((messages, _error)) {
        (_, final String error) => Center(child: Text(error)),
        (null, _) => const Center(child: Text('Tap the button to read SMS.')),
        (final List<SmsMessage> list, _) when list.isEmpty => const Center(
          child: Text('No SMS in the last 7 days.'),
        ),
        (final List<SmsMessage> list, _) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final message = list[index];
            return ListTile(
              title: Text(message.address),
              subtitle: Text(
                message.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '${message.date.toLocal()}'.substring(0, 16),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        ),
      },
    );
  }
}
