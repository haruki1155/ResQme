import '../../../core/data/pilot_client.dart';
import '../domain/qr_payload_parser.dart';

class QrFailure implements Exception {
  const QrFailure();
  @override
  String toString() => 'Unable to load your QR. Please retry.';
}

class Tier1QrCredential {
  const Tier1QrCredential({
    required this.payload,
    required this.verificationStatus,
    this.issuedAt,
  });
  final String payload, verificationStatus;
  final String? issuedAt;
}

class Tier1QrRepository {
  Tier1QrRepository(this.client);
  final PilotClient client;
  Tier1QrCredential validate(Map<String, dynamic> data) {
    if (!['pending', 'active'].contains(data['verificationStatus']) ||
        data['payload'] is! String ||
        !RegExp(
          r'^resqme:v1:[A-Za-z0-9_-]{43}$',
        ).hasMatch(data['payload'] as String)) {
      throw const QrFailure();
    }
    return Tier1QrCredential(
      payload: data['payload'] as String,
      verificationStatus: data['verificationStatus'] as String,
      issuedAt: data['issuedAt'] as String?,
    );
  }

  String? get ownerReference => client.uid;

  Future<String?> loadMine() async {
    try {
      return await ensureMine();
    } catch (_) {
      throw const QrFailure();
    }
  }

  Future<Tier1QrCredential> ensureMineCredential() async {
    try {
      return validate(await client.invoke('ensureMyTier1Qr', {}));
    } catch (_) {
      throw const QrFailure();
    }
  }

  Future<String> ensureMine() async => (await ensureMineCredential()).payload;

  Future<Tier1QrCredential> replaceMineCredential() async {
    try {
      return validate(await client.invoke('replaceMyTier1Qr', {}));
    } catch (_) {
      throw const QrFailure();
    }
  }

  Future<String> replaceMine() async => (await replaceMineCredential()).payload;

  Future<bool> resolveScanned(String payload) async {
    if (QrPayloadParser.parse(payload) is! ValidResQMeQr) return false;
    try {
      return await client.resolveQr(payload);
    } catch (_) {
      return false;
    }
  }
}
