import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import '../app_services.dart';
import '../models/booking.dart';
import '../models/service.dart';
import '../models/slot.dart';
import '../widgets/money.dart';
import 'booking_confirmation_screen.dart';

/// Collects the deposit via Stripe's PaymentSheet against the
/// `client_secret` bookslot's `BookingController` already created a
/// PaymentIntent for. Test mode only — this app never holds a Stripe
/// secret key, and `Env.stripePublishableKey` must be a `pk_test_...`
/// key, matching bookslot's own D-0036 (real Stripe credentials
/// permanently descoped for this portfolio).
class DepositPaymentScreen extends StatefulWidget {
  const DepositPaymentScreen({
    super.key,
    required this.service,
    required this.slot,
    required this.booking,
  });

  final Service service;
  final Slot slot;
  final BookingCreationResult booking;

  @override
  State<DepositPaymentScreen> createState() => _DepositPaymentScreenState();
}

class _DepositPaymentScreenState extends State<DepositPaymentScreen> {
  bool _processing = false;
  String? _error;
  bool _confirmed = false;

  Future<void> _pay() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    final services = context.read<AppServices>();

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: widget.booking.clientSecret,
          merchantDisplayName: 'bookslot demo',
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // The PaymentSheet only confirms with Stripe; bookslot's own
      // server-side state (appointment/payment rows) is only updated by
      // calling confirm-payment, matching PaymentConfirmationController's
      // documented, idempotent contract.
      final result = await services.api.confirmPayment(
        widget.booking.paymentConfirmationToken,
      );

      if (result['status'] != 'confirmed') {
        setState(() => _error = 'Payment did not complete. Please try again.');
        return;
      }

      await services.bookingsStore.add(
        LocalBooking(
          appointmentId: widget.booking.appointmentId,
          manageToken: widget.booking.manageToken,
          serviceName: widget.service.name,
          startsAt: widget.slot.startsAt,
        ),
      );
      await services.reminders.scheduleForAppointment(
        appointmentId: widget.booking.appointmentId,
        serviceName: widget.service.name,
        startsAt: widget.slot.startsAt,
      );

      setState(() => _confirmed = true);
    } on StripeException {
      setState(() => _error = 'Payment was cancelled or declined.');
    } catch (_) {
      setState(() => _error = 'Something went wrong confirming your payment.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed) {
      return BookingConfirmationScreen(
        service: widget.service,
        slot: widget.slot,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pay deposit')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Deposit due now: ${formatMinorUnits(widget.booking.depositAmount, widget.booking.depositCurrency)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!),
              ),
            FilledButton(
              onPressed: _processing ? null : _pay,
              child: _processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pay deposit'),
            ),
          ],
        ),
      ),
    );
  }
}
