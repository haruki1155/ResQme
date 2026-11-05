import 'dart:convert';
import 'dart:math';

String newPilotRequestId() => base64UrlEncode(
  List<int>.generate(18, (_) => Random.secure().nextInt(256)),
).replaceAll('=', '');

class SyntheticMedicalDraft {
  const SyntheticMedicalDraft({
    required this.conditionsState,
    required this.allergiesState,
    this.conditionsDetails,
    this.allergiesDetails,
    required this.syntheticConfirmed,
    this.minorAcknowledged = false,
    this.emergencyContact,
    this.expectedContact,
  });
  final String conditionsState, allergiesState;
  final String? conditionsDetails, allergiesDetails;
  final bool syntheticConfirmed, minorAcknowledged;
  final Map<String, dynamic>? emergencyContact, expectedContact;
  Map<String, dynamic> toPayload() => {
    'conditions': {
      'state': conditionsState,
      'details': conditionsState == 'listed' ? conditionsDetails?.trim() : null,
    },
    'allergies': {
      'state': allergiesState,
      'details': allergiesState == 'listed' ? allergiesDetails?.trim() : null,
    },
    'acknowledgment': {
      'version': 'synthetic-medical-v1',
      'syntheticDataConfirmed': syntheticConfirmed,
      'minorNoticeAcknowledged': minorAcknowledged,
    },
    if (emergencyContact != null) 'emergencyContact': emergencyContact,
    if (emergencyContact != null) 'expectedContact': expectedContact,
  };
  @override
  String toString() => 'SyntheticMedicalDraft(private test data)';
}
