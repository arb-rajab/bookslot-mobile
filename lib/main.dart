import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'app_services.dart';
import 'config/env.dart';
import 'screens/services_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  Stripe.publishableKey = Env.stripePublishableKey;
  await Stripe.instance.applySettings();

  final services = await AppServices.bootstrap();
  runApp(BookslotMobileApp(services: services));
}

class BookslotMobileApp extends StatelessWidget {
  const BookslotMobileApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return Provider<AppServices>.value(
      value: services,
      child: MaterialApp(
        title: 'bookslot',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const ServicesListScreen(),
      ),
    );
  }
}
