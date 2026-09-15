import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_services.dart';
import '../models/booking.dart';

/// Lists bookings made on this device (see `LocalBookingsStore`'s docblock
/// for why this is per-device, not per-account) and refreshes each one's
/// real, current status from bookslot's `GET /bookings/manage/{token}`.
///
/// **Cancellation is intentionally not wired to a live endpoint.**
/// bookslot's public API has no customer-initiated cancel route — only an
/// owner-authenticated `POST /owner/appointments/{id}/cancel` exists
/// (Session 20). Building a working "Cancel" button here would mean either
/// faking success against nothing, or silently calling an owner-only
/// endpoint this app has no credentials for. Neither is honest, so the
/// action is visible (customers should be able to find it) but explains
/// the real limitation instead of pretending to work. See this repo's
/// backlog for the tracked gap.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late List<LocalBooking> _localBookings;
  final Map<String, Future<BookingStatus>> _statusFutures = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final services = context.read<AppServices>();
    _localBookings = services.bookingsStore.all();
    _statusFutures.clear();
    for (final booking in _localBookings) {
      _statusFutures[booking.appointmentId] = services.api.fetchBookingStatus(
        booking.manageToken,
      );
    }
  }

  void _showCancelUnavailable() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancellation'),
        content: const Text(
          'Self-service cancellation isn\'t available yet in the public booking '
          'API. Please contact the studio directly to cancel this appointment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: _localBookings.isEmpty
          ? const Center(child: Text('No bookings made from this device yet.'))
          : RefreshIndicator(
              onRefresh: () async => setState(_reload),
              child: ListView.separated(
                itemCount: _localBookings.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final local = _localBookings[index];
                  return FutureBuilder<BookingStatus>(
                    future: _statusFutures[local.appointmentId],
                    builder: (context, snapshot) {
                      final statusText = switch (snapshot.connectionState) {
                        ConnectionState.done when snapshot.hasData =>
                          snapshot.data!.status,
                        ConnectionState.done => 'unavailable',
                        _ => 'loading…',
                      };

                      return ListTile(
                        title: Text(local.serviceName),
                        subtitle: Text(
                          '${DateFormat.yMMMEd().add_jm().format(local.startsAt.toLocal())} · $statusText',
                        ),
                        trailing: TextButton(
                          onPressed: _showCancelUnavailable,
                          child: const Text('Cancel'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}
