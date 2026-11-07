import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/qr/domain/qr_payload_parser.dart';

void main() {
  group('QrPayloadParser', () {
    test('accepts canonical 32-byte base64url reference with resqme:v1 prefix', () {
      // 32 bytes of zeros produces 43 'A's in base64url without padding
      const validReference = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      const validPayload = 'resqme:v1:$validReference';

      final result = QrPayloadParser.parse(validPayload);
      expect(result, isA<ValidResQMeQr>());
    });

    test('accepts real random 32-byte canonical base64url reference', () {
      final bytes = Uint8List.fromList(List.generate(32, (i) => (i * 37 + 13) % 256));
      final reference = base64Url.encode(bytes).replaceAll('=', '');
      expect(reference.length, 43);

      final payload = 'resqme:v1:$reference';
      final result = QrPayloadParser.parse(payload);
      expect(result, isA<ValidResQMeQr>());
    });

    test('rejects non-canonical padding bits in 43rd character', () {
      // 'A' has index 0 (bits 000000). 'B' has index 1 (bits 000001, dirty padding bits)
      const nonCanonicalReference = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB';
      const payload = 'resqme:v1:$nonCanonicalReference';

      final result = QrPayloadParser.parse(payload);
      expect(result, isA<InvalidQr>());
      expect((result as InvalidQr).reason, contains('non-canonical'));
    });

    test('rejects null or empty payload', () {
      expect(QrPayloadParser.parse(null), isA<InvalidQr>());
      expect(QrPayloadParser.parse(''), isA<InvalidQr>());
      expect(QrPayloadParser.parse('   '), isA<InvalidQr>());
    });

    test('rejects arbitrary web URLs and plain text', () {
      expect(QrPayloadParser.parse('https://resqme.example.com/qr/123'), isA<InvalidQr>());
      expect(QrPayloadParser.parse('http://insecure.test'), isA<InvalidQr>());
      expect(QrPayloadParser.parse('tel:911'), isA<InvalidQr>());
      expect(QrPayloadParser.parse('Emergency Contact: John Doe'), isA<InvalidQr>());
    });

    test('rejects unsupported version prefixes', () {
      expect(
        QrPayloadParser.parse('resqme:v2:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
        isA<InvalidQr>(),
      );
      expect(
        QrPayloadParser.parse('custom:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
        isA<InvalidQr>(),
      );
    });

    test('rejects reference with incorrect length (not 43 characters)', () {
      // 42 chars
      expect(
        QrPayloadParser.parse('resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
        isA<InvalidQr>(),
      );
      // 44 chars
      expect(
        QrPayloadParser.parse('resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
        isA<InvalidQr>(),
      );
    });

    test('rejects non-URL-safe characters (+, /, =)', () {
      expect(
        QrPayloadParser.parse('resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+AA'),
        isA<InvalidQr>(),
      );
      expect(
        QrPayloadParser.parse('resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/AA'),
        isA<InvalidQr>(),
      );
      expect(
        QrPayloadParser.parse('resqme:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='),
        isA<InvalidQr>(),
      );
    });

    test('never exposes raw payload in InvalidQr', () {
      const sensitiveToken = 'resqme:v1:SECRET_TOKEN_DO_NOT_EXPOSE_1234567890123';
      final result = QrPayloadParser.parse(sensitiveToken);
      expect(result, isA<InvalidQr>());
      final invalid = result as InvalidQr;
      expect(invalid.reason, isNot(contains(sensitiveToken)));
      expect(invalid.reason, isNot(contains('SECRET')));
    });
  });
}
