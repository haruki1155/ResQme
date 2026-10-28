import 'package:flutter/material.dart';

class EmergencyDashboardScreen extends StatelessWidget {
  const EmergencyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const destinations = [
      _EmergencyDestination('Scan QR', Icons.qr_code_scanner_outlined),
      _EmergencyDestination('First Aid', Icons.medical_information_outlined),
      _EmergencyDestination('Emergency Hotlines', Icons.call_outlined),
      _EmergencyDestination('DRRM Guidance', Icons.emergency_outlined),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Support')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 600 ? 2 : 1;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help is one step away.',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose a public emergency-support resource. Medical information is not shown here.',
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: columns == 1 ? 3.4 : 1.65,
                          children: destinations
                              .map(
                                (destination) =>
                                    _EmergencyDestinationCard(destination),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmergencyDestination {
  const _EmergencyDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _EmergencyDestinationCard extends StatelessWidget {
  const _EmergencyDestinationCard(this.destination);

  final _EmergencyDestination destination;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: destination.label,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(destination.icon, size: 34),
              const SizedBox(height: 12),
              Text(
                destination.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text('Coming next in Tier 1.'),
            ],
          ),
        ),
      ),
    );
  }
}
