import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../domain/qr_payload_parser.dart';
import 'unverified_qr_modal.dart';

/// Camera screen for scanning ResQMe emergency QR codes offline.
///
/// Handles complete camera lifecycle via [WidgetsBindingObserver] with
/// serialized start/stop operations, debounced detection, and unverified format display.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    this.controllerOverride,
  });

  /// Optional controller override for unit/widget testing without physical camera hardware.
  final MobileScannerController? controllerOverride;

  @override
  State<QrScannerScreen> createState() => QrScannerScreenState();
}

class QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _ownsController = false;

  bool _isOperatingCamera = false;
  bool _isModalOpen = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.controllerOverride != null) {
      _controller = widget.controllerOverride!;
      _ownsController = false;
    } else {
      _controller = MobileScannerController(
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
      _ownsController = true;
    }

    // Initialize camera startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isModalOpen) {
          _startCamera();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopCamera();
    }
  }

  Future<void> _startCamera() async {
    if (!mounted || _isOperatingCamera) return;
    _isOperatingCamera = true;
    try {
      if (!_controller.value.isRunning) {
        await _controller.start();
      }
    } catch (_) {
      // Error state is captured and rendered via MobileScanner's errorBuilder
    } finally {
      if (mounted) {
        setState(() => _isOperatingCamera = false);
      }
    }
  }

  Future<void> _stopCamera() async {
    if (!mounted || _isOperatingCamera) return;
    _isOperatingCamera = true;
    try {
      if (_controller.value.isRunning) {
        await _controller.stop();
      }
    } catch (_) {
      // Ignore stop errors on unmount
    } finally {
      if (mounted) {
        setState(() => _isOperatingCamera = false);
      }
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isModalOpen || !mounted) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isModalOpen = true);
    _stopCamera();

    final result = QrPayloadParser.parse(rawValue);

    UnverifiedQrModal.show(
      context: context,
      result: result,
      onScanAgain: () {
        if (!mounted) return;
        setState(() => _isModalOpen = false);
        _startCamera();
      },
      onDashboard: () {
        if (!mounted) return;
        Navigator.of(context).pop();
      },
    );
  }

  @visibleForTesting
  void handleBarcodeDetected(BarcodeCapture capture) => _onBarcodeDetected(capture);

  @visibleForTesting
  bool get isModalOpen => _isModalOpen;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Scan QR',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _torchEnabled ? Colors.amber : Colors.white,
            ),
            tooltip: 'Toggle Flashlight',
            onPressed: () async {
              try {
                await _controller.toggleTorch();
                if (mounted) {
                  setState(() => _torchEnabled = !_torchEnabled);
                }
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
            errorBuilder: (context, error) {
              final isPermissionDenied =
                  error.errorCode == MobileScannerErrorCode.permissionDenied;

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPermissionDenied
                              ? Icons.no_photography_outlined
                              : Icons.videocam_off_outlined,
                          color: const Color(0xFFE92B32),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isPermissionDenied
                              ? 'Camera Permission Required'
                              : 'Camera Unavailable',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isPermissionDenied
                              ? 'Camera access is needed to scan emergency QR codes in the field. Please enable camera access in your device settings.'
                              : 'Unable to access the camera hardware. Please check your camera permissions or restart the app.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A5568),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE92B32),
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          child: const Text('Back to Dashboard'),
                        ),
                        if (isPermissionDenied) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _startCamera,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const _ViewfinderOverlay(),
        ],
      ),
    );
  }
}

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize =
            (constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight) *
                0.68;

        return Stack(
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withAlpha(140),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: SizedBox(
                width: scanAreaSize,
                height: scanAreaSize,
                child: CustomPaint(
                  painter: _CornerBracketPainter(
                    color: const Color(0xFFE92B32),
                    strokeWidth: 4.0,
                    bracketLength: 28.0,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: constraints.maxHeight * 0.12,
              left: 24,
              right: 24,
              child: const Text(
                'Point camera at a ResQMe emergency QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.bracketLength,
  });

  final Color color;
  final double strokeWidth;
  final double bracketLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), Offset(bracketLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, bracketLength), paint);

    // Top-Right
    canvas.drawLine(Offset(w, 0), Offset(w - bracketLength, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, bracketLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, h), Offset(bracketLength, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - bracketLength), paint);

    // Bottom-Right
    canvas.drawLine(Offset(w, h), Offset(w - bracketLength, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - bracketLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
