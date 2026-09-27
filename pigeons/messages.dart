// Source of truth for the platform channel. Regenerate after editing:
//   dart run pigeon --input pigeons/messages.dart
//   dart format lib/src/messages.g.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/io/github/meharaj007/sms_inbox/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'io.github.meharaj007.sms_inbox'),
    dartPackageName: 'sms_inbox',
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
class SmsMessageData {
  SmsMessageData({
    required this.id,
    required this.address,
    required this.body,
    required this.dateMillis,
    required this.isRead,
    this.dateSentMillis,
    this.subscriptionId,
    this.threadId,
  });

  int id;
  String address;
  String body;
  int dateMillis;
  int? dateSentMillis;
  int? subscriptionId;
  int? threadId;
  bool isRead;
}

class InboxQueryData {
  InboxQueryData({
    required this.afterId,
    required this.limit,
    this.sinceMillis,
    this.untilMillis,
    this.senders,
  });

  int afterId;
  int limit;
  int? sinceMillis;
  int? untilMillis;

  /// Lower-cased sender addresses; null or empty means all senders.
  List<String>? senders;
}

@HostApi()
abstract class SmsInboxHostApi {
  bool hasPermission();

  @async
  bool requestPermission();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  List<SmsMessageData> query(InboxQueryData query);
}
