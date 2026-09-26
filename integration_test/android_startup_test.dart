import 'package:bookslot_mobile/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Native startup smoke tests. Unlike booking_flow_test.dart, these use no
/// fakes: they go through the real platform plugins, so they only mean
/// anything on a device or emulator (see
/// `.github/workflows/android-native.yml`).
///
/// They exist because booking_flow_test.dart pumps `BookslotMobileApp`
/// directly and never runs `main()`, so it can't catch a native plugin that
/// fails at startup. flutter_stripe's Android plugin answers *every* call,
/// including the `initialise` that `main()`'s `applySettings()` makes, with
/// a `PlatformException` unless `MainActivity` is a
/// `FlutterFragmentActivity` (stripe_android's `StripeAndroidPlugin
/// .onAttachedToActivity`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stripe native SDK initialises', (tester) async {
    Stripe.publishableKey = 'pk_test_placeholder';
    await Stripe.instance.applySettings();
  });

  testWidgets('real main() starts the app', (tester) async {
    await app.main();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
