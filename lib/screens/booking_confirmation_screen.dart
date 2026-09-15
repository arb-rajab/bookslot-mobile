import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/service.dart';
import '../models/slot.dart';
import 'services_list_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.service,
    required this.slot,
  });

  final Service service;
  final Slot slot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booked!'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              '${service.name} is confirmed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(DateFormat.yMMMEd().add_jm().format(slot.startsAt.toLocal())),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ServicesListScreen()),
                (route) => false,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
