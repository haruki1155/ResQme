import 'package:flutter/material.dart';
import 'package:resqme/app/app_routes.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.consentRepository});

  final ConsentRepository consentRepository;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openInitialRoute();
  }

  Future<void> _openInitialRoute() async {
    final accepted = await widget.consentRepository.hasAcceptedTerms();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed(accepted ? AppRoutes.entry : AppRoutes.terms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9232B),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final ringSize = constraints.maxWidth * .9;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: -ringSize * .4,
                right: -ringSize * .3,
                child: _ring(ringSize, const Color(0x12FFFFFF)),
              ),
              Positioned(
                bottom: -ringSize * .4,
                left: -ringSize * .45,
                child: _ring(ringSize, const Color(0x0D000000)),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 80),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1F730A13),
                                    blurRadius: 28,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/App logo/resqme_logo_splash.png',
                                fit: BoxFit.contain,
                                cacheWidth: 432,
                                semanticLabel: 'ResQme logo',
                              ),
                            ),
                            const SizedBox(height: 28),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                const Text(
                                  'RESQME',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.white38,
                                ),
                                const Text(
                                  'QR ID',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'EMERGENCY IDENTITY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 2.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: Semantics(
                        label: 'Loading ResQme',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 3; i++)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: i == 0
                                      ? Colors.white70
                                      : Colors.white38,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: size * .16),
    ),
  );
}
