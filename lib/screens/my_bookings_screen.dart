import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/bookslot_api_client.dart';
import '../app_services.dart';
import '../models/booking.dart';

/// Lists bookings made on this device (see `LocalBookingsStore`'s docblock
/// for why this is per-device, not per-account) and refreshes each one's
/// real, current status from bookslot's `GET /bookings/manage/{token}`.
///
/// Cancellation calls bookslot's real customer-facing endpoint (D-0052,
/// `POST /bookings/manage/{token}/cancel`), reusing the same
/// `manage_booking` token already stored locally for that booking — no
/// separate cancellation token exists. A 409 `INVALID_STATUS_TRANSITION`
/// response (the booking is already cancelled/completed/no-show) is
/// surfaced as a clear message, never treated as success or retried.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late List<LocalBooking> _localBookings;
  final Map<String, Future<BookingStatus>> _statusFutures = {};
  final Set<String> _cancellingIds = {};

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

  Future<void> _confirmAndCancel(LocalBooking local) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text('This will cancel your ${local.serviceName} booking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _cancellingIds.add(local.appointmentId));
    final services = context.read<AppServices>();
    try {
      final status = await services.api.cancelBooking(local.manageToken);
      await services.reminders.cancelForAppointment(local.appointmentId);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusFutures[local.appointmentId] = Future.value(status);
        _cancellingIds.remove(local.appointmentId);
      });
    } on BookslotApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _cancellingIds.remove(local.appointmentId));
      final message = e.statusCode == 409
          ? 'This booking is already cancelled or otherwise can\'t be '
                'cancelled anymore.'
          : 'Couldn\'t cancel this booking. Please try again.';
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancellation failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
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
                      final isCancelled = statusText == 'cancelled';
                      final isCancelling = _cancellingIds.contains(
                        local.appointmentId,
                      );

                      return ListTile(
                        title: Text(local.serviceName),
                        subtitle: Text(
                          '${DateFormat.yMMMEd().add_jm().format(local.startsAt.toLocal())} · $statusText',
                        ),
                        trailing: TextButton(
                          onPressed: isCancelled || isCancelling
                              ? null
                              : () => _confirmAndCancel(local),
                          child: isCancelling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Cancel'),
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
