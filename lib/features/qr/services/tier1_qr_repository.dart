import '../../../core/data/pilot_client.dart';

class QrFailure implements Exception {
  const QrFailure();
  @override
  String toString() => 'Unable to load your unverified QR. Please retry.';
}

class Tier1QrRepository {
  Tier1QrRepository(this.client);
  final PilotClient client;
  String validate(Map<String, dynamic> data) {
    if (data['verificationStatus'] != 'unverified' ||
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
      final data = await client.readMine('studentQrCredentials');
      return data == null ? null : validate(data);
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
}
