## 0.1.0

- First release.
- `SmsInbox.hasPermission` and `SmsInbox.requestPermission` for READ_SMS.
- `SmsInbox.query`: inbox messages after a message id, with optional
  received-time window, sender filter and page size.
- `SmsInbox.pages`: reads the whole inbox (or a window) page by page.
- Queries run on a background thread; the plugin declares no permissions and
  has no network access.
