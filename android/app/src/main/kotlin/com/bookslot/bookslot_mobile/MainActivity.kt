package com.bookslot.bookslot_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

// flutter_stripe's Android plugin rejects every call (including the
// `initialise` main() makes via applySettings()) unless the host activity
// is a FlutterFragmentActivity: Stripe's PaymentSheet needs the support
// FragmentManager. See integration_test/android_startup_test.dart.
class MainActivity : FlutterFragmentActivity()
