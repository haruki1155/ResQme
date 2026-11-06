import 'package:flutter/material.dart';
import 'package:resqme/app/app_routes.dart';

class EmergencyDashboardScreen extends StatelessWidget {
  const EmergencyDashboardScreen({super.key, this.accountPanel});
  final Widget? accountPanel;

  @override
  Widget build(BuildContext context) {
    const destinations = [
      _EmergencyDestination(
        'Tier 2 information',
        'Restricted personal information',
        Icons.lock_outline,
        true,
        AppRoutes.medicalBoundary,
      ),
      _EmergencyDestination(
        'First-aid instructions',
        'Quick guidance for common injuries',
        Icons.add_circle_outline,
        false,
        AppRoutes.firstAid,
      ),
      _EmergencyDestination(
        'Emergency hotlines',
        'One-tap access to emergency services',
        Icons.call_outlined,
        false,
        AppRoutes.hotlines,
      ),
      _EmergencyDestination(
        'DRRM instructions',
        'Preparedness for disasters & hazards',
        Icons.shield_outlined,
        false,
        AppRoutes.drrm,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE92B32),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RESQME  |  QR ID',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 42),
                            Text(
                              'Good day,',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Ready when it matters.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 20),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0x33FFFFFF),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(Icons.qr_code_2, color: Colors.white),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'RESQME STATUS',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'Public emergency support is available',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.circle,
                                      color: Color(0xFF54E0B6),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ?accountPanel,
                      const SizedBox(height: 36),
                      const Text(
                        'PUBLIC ACCESS',
                        style: TextStyle(
                          color: Color(0xFFE92B32),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _SectionHeading(),
                      const SizedBox(height: 18),
                      ...destinations.map(_EmergencyDestinationCard.new),
                      const SizedBox(height: 34),
                      const _BottomNavigationVisual(),
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
  const _EmergencyDestination(
    this.label,
    this.description,
    this.icon,
    this.isRestricted,
    this.route,
  );

  final String label;
  final String description;
  final IconData icon;
  final bool isRestricted;
  final String route;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading();

  @override
  Widget build(BuildContext context) {
    const title = Text(
      'Tier 1 information',
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
    );
    const count = Text(
      '4 services',
      style: TextStyle(color: Color(0xFF8C9AB0), fontWeight: FontWeight.w700),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, SizedBox(height: 4), count],
          );
        }

        return const Row(children: [title, Spacer(), count]);
      },
    );
  }
}

class _EmergencyDestinationCard extends StatelessWidget {
  const _EmergencyDestinationCard(this.destination);

  final _EmergencyDestination destination;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: destination.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).pushNamed(destination.route),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: destination.isRestricted
                          ? const Color(0xFF02061E)
                          : const Color(0xFFFFF0F1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      destination.icon,
                      color: destination.isRestricted
                          ? Colors.white
                          : const Color(0xFFE92B32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          destination.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          destination.description,
                          style: const TextStyle(color: Color(0xFF8C9AB0)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFB6C0CE)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationVisual extends StatelessWidget {
  const _BottomNavigationVisual();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.home_outlined, color: Color(0xFFE92B32)),
        IconButton(
          tooltip: 'Scan QR',
          icon: const Icon(Icons.qr_code_2, size: 34),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.scanner),
        ),
        IconButton(
          tooltip: 'Profile',
          icon: const Icon(Icons.person_outline, color: Color(0xFF8C9AB0)),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
        ),
      ],
    ),
  );
}
