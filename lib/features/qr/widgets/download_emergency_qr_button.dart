import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class DownloadEmergencyQrButton extends StatefulWidget {
  const DownloadEmergencyQrButton({super.key, required this.payload});

  final String payload;

  @override
  State<DownloadEmergencyQrButton> createState() =>
      _DownloadEmergencyQrButtonState();
}

class _DownloadEmergencyQrButtonState extends State<DownloadEmergencyQrButton> {
  bool _saving = false;

  Future<void> _download() async {
    final payload = widget.payload;
    setState(() => _saving = true);
    try {
      final qr = QrCode.fromData(
        data: payload,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final bytes = await QrImage(qr).toImageAsBytes(
        size: 660,
        decoration: const PrettyQrDecoration(
          background: Colors.white,
          quietZone: PrettyQrQuietZone.standard,
        ),
      );
      if (bytes == null) throw StateError('QR image unavailable.');
      if (!mounted || widget.payload != payload) return;
      final saved = await const MethodChannel('resqme/qr_download')
          .invokeMethod<bool>(
            'savePng',
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
      if (mounted && saved == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Emergency QR saved.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the emergency QR.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _saving ? null : _download,
    icon: const Icon(Icons.download),
    label: const Text('Download QR'),
  );
}
