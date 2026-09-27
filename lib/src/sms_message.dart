// Copyright (c) 2026 Meheraj. Use of this source code is governed by the
// MIT license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';

/// A message from the Android SMS inbox.
@immutable
class SmsMessage {
  /// Creates a message. Normally you get these from `SmsInbox.query`.
  const SmsMessage({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.isRead,
    this.dateSent,
    this.subscriptionId,
    this.threadId,
  });

  /// `_id` in the inbox content provider. New messages get larger ids, so it
  /// works as a cursor for incremental reads (see `SmsInbox.query`).
  final int id;

  /// Sender: a phone number, a short code or an alphanumeric sender ID such as
  /// `bKash`.
  final String address;

  /// Full message text.
  final String body;

  /// When the phone received the message, in UTC.
  final DateTime date;

  /// When the sender's network sent it, in UTC, if the phone recorded it.
  final DateTime? dateSent;

  /// SIM subscription that received the message, on multi-SIM phones.
  final int? subscriptionId;

  /// Conversation thread id in the SMS provider.
  final int? threadId;

  /// Whether the message has been read in the messaging app.
  final bool isRead;

  @override
  bool operator ==(Object other) =>
      other is SmsMessage &&
      other.id == id &&
      other.address == address &&
      other.body == body &&
      other.date == date &&
      other.dateSent == dateSent &&
      other.subscriptionId == subscriptionId &&
      other.threadId == threadId &&
      other.isRead == isRead;

  @override
  int get hashCode => Object.hash(
    id,
    address,
    body,
    date,
    dateSent,
    subscriptionId,
    threadId,
    isRead,
  );

  @override
  String toString() =>
      'SmsMessage(id: $id, address: $address, date: $date, '
      'body: ${body.length} chars)';
}
