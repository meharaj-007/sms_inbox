// Copyright (c) 2026 Meheraj. Use of this source code is governed by the
// MIT license that can be found in the LICENSE file.

import 'package:flutter/services.dart';

import 'messages.g.dart';
import 'sms_inbox_exception.dart';
import 'sms_message.dart';

/// Read-only access to the Android SMS inbox.
///
/// The app must declare `android.permission.READ_SMS` in its own
/// `AndroidManifest.xml`; this plugin declares no permissions.
class SmsInbox {
  /// Creates an inbox reader.
  SmsInbox();

  final _api = SmsInboxHostApi();

  /// Largest page size a single [query] returns.
  static const maxLimit = 5000;

  /// Whether READ_SMS is currently granted.
  Future<bool> hasPermission() => _guard(_api.hasPermission);

  /// Shows the system READ_SMS prompt if needed and returns whether it is
  /// granted. Google Play expects an in-app explanation before this call.
  Future<bool> requestPermission() => _guard(_api.requestPermission);

  /// Inbox messages with [SmsMessage.id] greater than [afterId], oldest first,
  /// at most [limit] (capped at [maxLimit]).
  ///
  /// - [since] / [until]: received-time window, `since` inclusive and `until`
  ///   exclusive.
  /// - [senders]: only these sender addresses, compared case-insensitively.
  ///
  /// To read everything, call again with the last returned id until a page is
  /// shorter than [limit], or use [pages].
  Future<List<SmsMessage>> query({
    int afterId = 0,
    DateTime? since,
    DateTime? until,
    Iterable<String>? senders,
    int limit = 500,
  }) async {
    RangeError.checkValueInInterval(limit, 1, maxLimit, 'limit');
    final rows = await _guard(
      () => _api.query(
        InboxQueryData(
          afterId: afterId,
          limit: limit,
          sinceMillis: since?.millisecondsSinceEpoch,
          untilMillis: until?.millisecondsSinceEpoch,
          senders: senders?.map((s) => s.toLowerCase()).toSet().toList(),
        ),
      ),
    );
    return [for (final row in rows) _toMessage(row)];
  }

  /// Reads the inbox page by page, oldest first, starting after [afterId].
  ///
  /// Each event is one page of at most [pageSize] messages. The stream ends
  /// after the first short page.
  Stream<List<SmsMessage>> pages({
    int afterId = 0,
    DateTime? since,
    DateTime? until,
    Iterable<String>? senders,
    int pageSize = 500,
  }) async* {
    var cursor = afterId;
    while (true) {
      final page = await query(
        afterId: cursor,
        since: since,
        until: until,
        senders: senders,
        limit: pageSize,
      );
      if (page.isNotEmpty) {
        yield page;
        cursor = page.last.id;
      }
      if (page.length < pageSize) {
        return;
      }
    }
  }

  static SmsMessage _toMessage(SmsMessageData data) => SmsMessage(
    id: data.id,
    address: data.address,
    body: data.body,
    date: DateTime.fromMillisecondsSinceEpoch(data.dateMillis, isUtc: true),
    dateSent: data.dateSentMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            data.dateSentMillis!,
            isUtc: true,
          ),
    subscriptionId: data.subscriptionId,
    threadId: data.threadId,
    isRead: data.isRead,
  );

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw SmsInboxException.fromPlatform(e.code, e.message);
    }
  }
}
