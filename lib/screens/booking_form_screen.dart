import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/bookslot_api_client.dart';
import '../app_services.dart';
import '../models/mandate.dart';
import '../models/service.dart';
import '../models/slot.dart';
import '../widgets/money.dart';
import 'deposit_payment_screen.dart';

/// Collects customer details, shows bookslot's own server-rendered mandate
/// text (never client-authored copy — `MandateController`), and submits
/// the booking. Mirrors `05-api-contracts.md`/`BookingController`'s request
/// shape exactly: `mandate_accepted` and `mandate_template_version` only —
/// the mandate text itself is never sent back to the server.
class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen({
    super.key,
    required this.service,
    required this.slot,
  });

  final Service service;
  final Slot slot;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _mandateAccepted = false;
  bool _submitting = false;
  String? _submitError;
  late Future<Mandate> _mandateFuture;

  @override
  void initState() {
    super.initState();
    _mandateFuture = context.read<AppServices>().api.fetchMandate(
      widget.service.id,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit(Mandate mandate) async {
    if (!_formKey.currentState!.validate() || !_mandateAccepted) {
      setState(
        () => _submitError = !_mandateAccepted
            ? 'You must accept the deposit terms to continue.'
            : null,
      );
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final api = context.read<AppServices>().api;
      final result = await api.createBooking(
        serviceId: widget.service.id,
        staffId: widget.slot.staffId,
        startsAt: widget.slot.startsAt,
        customerName: _nameController.text.trim(),
        customerEmail: _emailController.text.trim(),
        customerPhone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        mandateTemplateVersion: mandate.templateVersion,
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DepositPaymentScreen(
            service: widget.service,
            slot: widget.slot,
            booking: result,
          ),
        ),
      );
    } on BookslotApiException catch (e) {
      setState(
        () => _submitError = e.errorCode == 'SLOT_ALREADY_BOOKED'
            ? 'That slot was just taken. Please pick another time.'
            : 'Could not create the booking. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your details')),
      body: FutureBuilder<Mandate>(
        future: _mandateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load booking terms.'));
          }
          final mandate = snapshot.data!;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.service.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  DateFormat.yMMMEd().add_jm().format(
                    widget.slot.startsAt.toLocal(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('nameField'),
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  key: const Key('emailField'),
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                TextFormField(
                  key: const Key('phoneField'),
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(mandate.text),
                  ),
                ),
                CheckboxListTile(
                  key: const Key('mandateCheckbox'),
                  value: _mandateAccepted,
                  onChanged: (v) =>
                      setState(() => _mandateAccepted = v ?? false),
                  title: Text(
                    'I agree to pay a deposit of ${formatMinorUnits(widget.service.estimatedDepositAmount(), widget.service.currency)} now',
                  ),
                ),
                if (_submitError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _submitError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _submitting ? null : () => _submit(mandate),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue to payment'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
