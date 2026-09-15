import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_services.dart';
import '../models/service.dart';
import '../models/slot.dart';
import 'booking_form_screen.dart';

/// Shows real, derived availability for [service] over the next
/// [lookaheadDays] days, via bookslot's `GET /tenants/{slug}/availability`
/// (`AvailabilityController`) — never a client-side guess at open slots.
class SlotPickerScreen extends StatefulWidget {
  const SlotPickerScreen({
    super.key,
    required this.service,
    this.lookaheadDays = 14,
  });

  final Service service;
  final int lookaheadDays;

  @override
  State<SlotPickerScreen> createState() => _SlotPickerScreenState();
}

class _SlotPickerScreenState extends State<SlotPickerScreen> {
  late Future<List<Slot>> _slotsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final now = DateTime.now();
    _slotsFuture = context.read<AppServices>().api.fetchAvailability(
      serviceId: widget.service.id,
      from: now,
      to: now.add(Duration(days: widget.lookaheadDays)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.service.name)),
      body: FutureBuilder<List<Slot>>(
        future: _slotsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load availability.'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => setState(_load),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final slots = snapshot.data!;
          if (slots.isEmpty) {
            return const Center(
              child: Text('No open slots in the next two weeks.'),
            );
          }
          final byDay = groupByDay(slots);
          final days = byDay.keys.toList()..sort();

          return ListView(
            children: [
              for (final day in days) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    DateFormat.yMMMEd().format(day),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in byDay[day]!)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BookingFormScreen(
                                service: widget.service,
                                slot: slot,
                              ),
                            ),
                          ),
                          child: Text(
                            DateFormat.Hm().format(slot.startsAt.toLocal()),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

Map<DateTime, List<Slot>> groupByDay(List<Slot> slots) {
  final map = <DateTime, List<Slot>>{};
  for (final slot in slots) {
    final local = slot.startsAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    map.putIfAbsent(day, () => []).add(slot);
  }
  return map;
}
