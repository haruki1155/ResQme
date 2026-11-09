import 'dart:convert';
import 'dart:typed_data';

/// Represents the validated local outcome of parsing a QR code.
sealed class QrScanResult {
  const QrScanResult();
}

/// A recognized ResQMe v1 QR format matching the canonical 32-byte reference standard.
/// Note: This indicates format validity only, NOT identity or enrollment verification.
class ValidResQMeQr extends QrScanResult {
  const ValidResQMeQr();
}

/// An unrecognized or invalid QR code.
/// Raw snippets and sensitive tokens are strictly excluded from this model.
class InvalidQr extends QrScanResult {
  const InvalidQr({required this.reason});
  final String reason;
}

/// A syntactically valid QR that the server did not confirm as active.
class InactiveQr extends QrScanResult {
  const InactiveQr();
}

/// Strict offline syntactic parser for ResQMe emergency QR payloads.
abstract final class QrPayloadParser {
  static const String prefix = 'resqme:v1:';
  static final RegExp _base64UrlPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// Parses and validates a raw scanned payload against the ResQMe v1 specification.
  ///
  /// Rejects malformed strings, arbitrary URLs, non-canonical encodings,
  /// and any payload that does not represent an exact canonical 32-byte reference.
  static QrScanResult parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const InvalidQr(reason: 'Empty QR code payload.');
    }

    final trimmed = raw.trim();

    if (!trimmed.startsWith(prefix)) {
      return const InvalidQr(reason: 'Unsupported QR scheme or format.');
    }

    final reference = trimmed.substring(prefix.length);

    if (!_base64UrlPattern.hasMatch(reference)) {
      return const InvalidQr(reason: 'Invalid reference format or length.');
    }

    // Decode base64url and verify exactly 32 bytes with canonical encoding.
    try {
      final normalized = base64.normalize(reference);
      final Uint8List decoded = base64Url.decode(normalized);

      if (decoded.length != 32) {
        return const InvalidQr(reason: 'Invalid credential payload size.');
      }

      // Re-encode and verify strict equality to detect non-zero padding bits.
      final reEncoded = base64Url.encode(decoded).replaceAll('=', '');
      if (reEncoded != reference) {
        return const InvalidQr(reason: 'Non-canonical reference encoding.');
      }

      return const ValidResQMeQr();
    } catch (_) {
      return const InvalidQr(
        reason: 'Malformed or non-canonical base64url encoding.',
      );
    }
  }
}
