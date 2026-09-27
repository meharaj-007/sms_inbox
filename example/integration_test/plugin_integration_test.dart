// Runs on a device or emulator: flutter test integration_test
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sms_inbox/sms_inbox.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hasPermission reaches the platform', (tester) async {
    final granted = await SmsInbox().hasPermission();
    expect(granted, isA<bool>());
  });

  testWidgets('query without permission throws permissionDenied', (
    tester,
  ) async {
    final inbox = SmsInbox();
    if (await inbox.hasPermission()) {
      markTestSkipped('READ_SMS already granted on this device');
      return;
    }
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
