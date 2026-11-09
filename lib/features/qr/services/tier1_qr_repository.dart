import '../../../core/data/pilot_client.dart';
import '../domain/qr_payload_parser.dart';

class QrFailure implements Exception {
  const QrFailure();
  @override
  String toString() => 'Unable to load your QR. Please retry.';
}

class Tier1QrRepository {
  Tier1QrRepository(this.client);
  final PilotClient client;
  String validate(Map<String, dynamic> data) {
    if (data['verificationStatus'] != 'active' ||
        data['payload'] is! String ||
        !RegExp(
          r'^resqme:v1:[A-Za-z0-9_-]{43}$',
        ).hasMatch(data['payload'] as String)) {
      throw const QrFailure();
    }
    return data['payload'] as String;
  }

  Future<String?> loadMine() async {
    try {
      return await ensureMine();
    } catch (_) {
      throw const QrFailure();
    }
  }

  Future<String> ensureMine() async {
    try {
      return validate(await client.invoke('ensureMyTier1Qr', {}));
    } catch (_) {
      throw const QrFailure();
    }
  }

  Future<String> replaceMine() async {
    try {
      return validate(await client.invoke('replaceMyTier1Qr', {}));
    } catch (_) {
      throw const QrFailure();
    }
  }

  Future<bool> resolveScanned(String payload) async {
    if (QrPayloadParser.parse(payload) is! ValidResQMeQr) return false;
    try {
      return await client.resolveQr(payload);
    } catch (_) {
      return false;
    }
  }
}
