import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_inbox/sms_inbox.dart';
import 'package:sms_inbox/src/messages.g.dart';

const _prefix = 'dev.flutter.pigeon.sms_inbox.SmsInboxHostApi';
const _codec = SmsInboxHostApi.pigeonChannelCodec;

/// Fake host side: answers Pigeon messages the way the Kotlin plugin would.
class _FakeHost {
  _FakeHost(this.messages);

  final List<SmsMessageData> messages;
  bool granted = true;
  final queries = <InboxQueryData>[];
  PlatformException? failWith;

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void handle(String method, Object? Function(List<Object?> args) body) {
      messenger.setMockMessageHandler('$_prefix.$method', (data) async {
        final args = (_codec.decodeMessage(data) as List<Object?>?) ?? [];
        final error = failWith;
        if (error != null) {
          return _codec.encodeMessage([error.code, error.message, null]);
        }
        return _codec.encodeMessage([body(args)]);
      });
    }

    handle('hasPermission', (_) => granted);
    handle('requestPermission', (_) => granted = true);
    handle('query', (args) {
      final query = args.single! as InboxQueryData;
      queries.add(query);
      final senders = query.senders;
      return messages
          .where((m) => m.id > query.afterId)
          .where(
            (m) => senders == null || senders.contains(m.address.toLowerCase()),
          )
          .take(query.limit)
          .toList();
    });
  }
}

SmsMessageData _message(int id, {String address = 'bKash'}) => SmsMessageData(
  id: id,
  address: address,
  body: 'Message $id',
  dateMillis: 1790000000000 + id,
  isRead: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeHost host;
  late SmsInbox inbox;

  setUp(() {
    host = _FakeHost([for (var id = 1; id <= 7; id++) _message(id)])..install();
    inbox = SmsInbox();
  });

  test('maps platform rows to SmsMessage with UTC dates', () async {
    final messages = await inbox.query(limit: 2);
    expect(messages.map((m) => m.id), [1, 2]);
    expect(messages.first.address, 'bKash');
    expect(messages.first.date.isUtc, isTrue);
    expect(
      messages.first.date,
      DateTime.fromMillisecondsSinceEpoch(1790000000001, isUtc: true),
    );
  });

  test('sends the window, cursor and lower-cased unique senders', () async {
    await inbox.query(
      afterId: 3,
      since: DateTime.utc(2026, 6, 1),
      until: DateTime.utc(2026, 9, 1),
      senders: ['bKash', 'BKASH', 'NAGAD'],
      limit: 10,
    );
    final sent = host.queries.single;
    expect(sent.afterId, 3);
    expect(sent.limit, 10);
    expect(sent.sinceMillis, DateTime.utc(2026, 6, 1).millisecondsSinceEpoch);
    expect(sent.untilMillis, DateTime.utc(2026, 9, 1).millisecondsSinceEpoch);
    expect(sent.senders, ['bkash', 'nagad']);
  });

  test('pages walks the inbox with the last id as cursor', () async {
    final pages = await inbox.pages(pageSize: 3).toList();
    expect(pages.map((p) => p.map((m) => m.id).toList()), [
      [1, 2, 3],
      [4, 5, 6],
      [7],
    ]);
    expect(host.queries.map((q) => q.afterId), [0, 3, 6]);
  });

  test('pages stops after an exactly full last page', () async {
    final pages = await inbox.pages(afterId: 1, pageSize: 3).toList();
    expect(pages.expand((p) => p).map((m) => m.id), [2, 3, 4, 5, 6, 7]);
    expect(host.queries, hasLength(3));
  });

  test('rejects limits outside 1..maxLimit before calling the platform', () {
    expect(() => inbox.query(limit: 0), throwsRangeError);
    expect(() => inbox.query(limit: SmsInbox.maxLimit + 1), throwsRangeError);
    expect(host.queries, isEmpty);
  });

  test('permission calls pass through', () async {
    host.granted = false;
    expect(await inbox.hasPermission(), isFalse);
    expect(await inbox.requestPermission(), isTrue);
  });

  test('platform errors become SmsInboxException', () async {
    host.failWith = PlatformException(
      code: 'permission_denied',
      message: 'READ_SMS has not been granted',
    );
    await expectLater(
      inbox.query(),
      throwsA(
        isA<SmsInboxException>().having(
          (e) => e.code,
          'code',
          SmsInboxError.permissionDenied,
        ),
      ),
    );
  });
}
