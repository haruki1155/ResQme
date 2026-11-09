import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/app_routes.dart';
import '../../qr/presentation/qr_scanner_screen.dart';

/// Public entry point. Opening this screen never starts the camera or signs in.
class ScannerEntryScreen extends StatefulWidget {
  const ScannerEntryScreen({super.key, this.onResolveQr});
  final Future<bool> Function(String payload)? onResolveQr;

  @override
  State<ScannerEntryScreen> createState() => _ScannerEntryScreenState();
}

class _ScannerEntryScreenState extends State<ScannerEntryScreen>
    with SingleTickerProviderStateMixin {
  bool _cameraEnabled = false;
  bool _detected = false;
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  void _updateSweep() {
    if (_cameraEnabled &&
        !_detected &&
        !MediaQuery.disableAnimationsOf(context)) {
      _scan.repeat(reverse: true);
    } else {
      _scan.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSweep();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _leave(String route) async {
    setState(() => _cameraEnabled = false);
    _updateSweep();
    // Dispose the camera before covering the entry with another route.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFF111214),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'RESQME | QR ID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: SizedBox.square(
                        dimension: (constraints.maxWidth - 80).clamp(
                          160.0,
                          300.0,
                        ),
                        child: CustomPaint(
                          foregroundPainter: _ScanFramePainter(_scan),
                          child: _cameraEnabled
                              ? QrScannerScreen(
                                  embedded: true,
                                  onResolveQr: widget.onResolveQr,
                                  onDetectionChanged: (detected) {
                                    _detected = detected;
                                    _updateSweep();
                                  },
                                  onDashboard: () =>
                                      _leave(AppRoutes.dashboard),
                                )
                              : Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 36,
                                      color: Color(0xFF25262A),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Scan emergency QR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Position a RESQME QR code in the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB8BAC0),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF111214),
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _cameraEnabled = !_cameraEnabled;
                          _detected = false;
                        });
                        _updateSweep();
                      },
                      child: Text(
                        _cameraEnabled ? 'Disable Camera' : 'Enable Camera',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scanning checks whether a ResQMe QR is active. It does not sign you in or reveal student information.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB8BAC0),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF74777F)),
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => _leave(AppRoutes.dashboard),
                      child: const Text(
                        'Go to Dashboard as Guest',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _leave(AppRoutes.register),
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter(this.scan) : super(repaint: scan);
  final Animation<double> scan;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const corner = 30.0;
    const inset = 2.0;
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(i * 3.141592653589793 / 2);
      canvas.translate(-size.width / 2, -size.height / 2);
      canvas.drawPath(
        Path()
          ..moveTo(inset, corner)
          ..lineTo(inset, 14)
          ..quadraticBezierTo(inset, inset, 14, inset)
          ..lineTo(corner, inset),
        frame,
      );
      canvas.restore();
    }
    canvas.drawLine(
      Offset(
        16,
        size.height * (.12 + .76 * Curves.easeInOut.transform(scan.value)),
      ),
      Offset(
        size.width - 16,
        size.height * (.12 + .76 * Curves.easeInOut.transform(scan.value)),
      ),
      Paint()
        ..color = const Color(0xFFE92B32)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) => false;
}
