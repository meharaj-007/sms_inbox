// Copyright (c) 2026 Meheraj. Use of this source code is governed by the
// MIT license that can be found in the LICENSE file.

/// Why an [SmsInboxException] was thrown.
enum SmsInboxError {
  /// READ_SMS has not been granted.
  permissionDenied,

  /// `requestPermission` was called without a foreground activity.
  noActivity,

  /// Another permission prompt from this plugin is already showing.
  requestInProgress,

  /// The plugin is not attached to a Flutter engine.
  detached,

  /// Anything else reported by the platform.
  unknown,
}

/// Thrown by `SmsInbox` when the platform side fails.
class SmsInboxException implements Exception {
  /// Creates an exception with an error [code] and optional [message].
  const SmsInboxException(this.code, [this.message]);

  /// Maps a platform error code to an [SmsInboxError].
  factory SmsInboxException.fromPlatform(String code, String? message) {
    final error = switch (code) {
      'permission_denied' => SmsInboxError.permissionDenied,
      'no_activity' => SmsInboxError.noActivity,
      'in_progress' => SmsInboxError.requestInProgress,
      'detached' => SmsInboxError.detached,
      _ => SmsInboxError.unknown,
    };
    return SmsInboxException(error, message);
  }

  /// What went wrong.
  final SmsInboxError code;

  /// Platform message, for logs. Never contains message content.
  final String? message;

  @override
  String toString() => 'SmsInboxException(${code.name}: $message)';
}
