import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../services/student_registration_repository.dart';

class StudentLoginQrScannerScreen extends StatefulWidget {
  const StudentLoginQrScannerScreen({
    super.key,
    required this.onScanned,
  });

  final ValueChanged<String> onScanned;

  @override
  State<StudentLoginQrScannerScreen> createState() =>
      _StudentLoginQrScannerScreenState();
}

class _StudentLoginQrScannerScreenState
    extends State<StudentLoginQrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed && !_handled) {
      _controller.start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    _controller.stop();
    widget.onScanned(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Student Login QR')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Point the camera at your personal ResQMe Login QR code. You will still need to enter your account password to finish signing in.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (_, _) => ColoredBox(
                      color: const Color(0xFF25262A),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.no_photography_outlined,
                              color: Colors.white,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Camera access is unavailable. Allow camera permission in Android Settings or sign in using your email and password.',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Use Email & Password Instead'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManageStudentLoginQrScreen extends StatefulWidget {
  const ManageStudentLoginQrScreen({
    super.key,
    required this.repository,
  });

  final StudentRegistrationRepository repository;

  @override
  State<ManageStudentLoginQrScreen> createState() =>
      _ManageStudentLoginQrScreenState();
}

class _ManageStudentLoginQrScreenState
    extends State<ManageStudentLoginQrScreen> {
  StudentLoginQrCredential? _credential;
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final res = await widget.repository.ensureMyLoginQr();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _credential = res.credential;
      _message = res.errorMessage;
    });
  }

  Future<void> _replace() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final res = await widget.repository.replaceMyLoginQr();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.credential != null) {
        _credential = res.credential;
        _message = 'Login QR replaced. Previous Login QR codes will no longer work.';
      } else {
        _message = res.errorMessage ?? 'Unable to replace Login QR.';
      }
    });
  }

  Future<void> _revoke() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final err = await widget.repository.revokeMyLoginQr();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err == null) {
        _credential = null;
        _message = 'Login QR revoked. Generate a new one whenever needed.';
      } else {
        _message = err;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Login QR')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: const Color(0xFFFFF8E1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.security_outlined,
                            color: Color(0xFF8D6E00),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This QR code identifies your account for faster sign-in. It never contains your password, LRN, or medical details, and your password is always required to sign in.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_credential != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(16),
                              child: SizedBox.square(
                                dimension: 200,
                                child: PrettyQrView.data(
                                  data: _credential!.payload,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Version ${_credential!.credentialVersion} • Active',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _replace,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Replace Login QR'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _revoke,
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Revoke Login QR'),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: _busy ? null : _load,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Generate New Login QR'),
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
