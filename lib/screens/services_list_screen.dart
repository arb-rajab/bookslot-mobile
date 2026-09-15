import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_services.dart';
import '../models/service.dart';
import '../widgets/money.dart';
import 'my_bookings_screen.dart';
import 'slot_picker_screen.dart';

class ServicesListScreen extends StatefulWidget {
  const ServicesListScreen({super.key});

  @override
  State<ServicesListScreen> createState() => _ServicesListScreenState();
}

class _ServicesListScreenState extends State<ServicesListScreen> {
  late Future<List<Service>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = context.read<AppServices>().api.fetchServices();
  }

  void _refresh() {
    setState(
      () => _servicesFuture = context.read<AppServices>().api.fetchServices(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book an appointment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'My bookings',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
          ),
        ],
      ),
      body: FutureBuilder<List<Service>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: 'Could not load services.',
              onRetry: _refresh,
            );
          }
          final services = snapshot.data!;
          if (services.isEmpty) {
            return const Center(
              child: Text('No services are available right now.'),
            );
          }
          return ListView.separated(
            itemCount: services.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final service = services[index];
              return ListTile(
                title: Text(service.name),
                subtitle: Text(
                  '${service.durationMinutes} min · Deposit ${formatMinorUnits(service.estimatedDepositAmount(), service.currency)}',
                ),
                trailing: Text(
                  formatMinorUnits(service.priceAmount, service.currency),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SlotPickerScreen(service: service),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
