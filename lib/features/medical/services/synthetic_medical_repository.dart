import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/pilot_client.dart';
import '../models/synthetic_medical_draft.dart';

class MedicalFailure implements Exception {
  const MedicalFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class MedicalSnapshot {
  const MedicalSnapshot({
    required this.ownerUid,
    required this.revision,
    required this.completed,
    required this.primaryContact,
    this.conditions,
    this.allergies,
  });
  final String ownerUid;
  final int revision;
  final bool completed;
  final Map<String, dynamic> primaryContact;
  final Map<String, dynamic>? conditions, allergies;
  @override
  String toString() => 'MedicalSnapshot(private test data)';
}

class SyntheticMedicalRepository {
  SyntheticMedicalRepository(this.client);
  final PilotClient client;
  String? _sessionUid, _snoozedUid;
  void syncSession() {
    if (_sessionUid != client.uid) {
      _sessionUid = client.uid;
      _snoozedUid = null;
    }
  }

  bool get reminderSnoozed {
    syncSession();
    return client.uid != null && _snoozedUid == client.uid;
  }

  void snoozeReminder() {
    syncSession();
    _snoozedUid = client.uid;
  }

  Future<T> _safe<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (error is MedicalFailure) rethrow;
      final code = error is FirebaseException ? error.code : '';
      throw MedicalFailure(switch (code) {
        'permission-denied' =>
          'Test record saving is not enabled for this account. You can Skip for now.',
        'failed-precondition' =>
          'Record or contact changed. Reload before saving.',
        'already-exists' => 'This request changed. Reload before trying again.',
        'unavailable' ||
        'deadline-exceeded' => 'Connection unavailable. Retry or Skip for now.',
        _ =>
          error is TimeoutException
              ? 'Connection unavailable. Retry or Skip for now.'
              : 'Unable to complete this test-record operation. Retry or Skip for now.',
      });
    }
  }

  Future<MedicalSnapshot> loadMine() => _safe(() async {
    final owner = client.uid;
    if (owner == null) {
      throw const MedicalFailure('Sign in to access your test record.');
    }
    final profile = await client.readMine('studentProfiles');
    final data = await client.readMine('studentMedicalRecords');
    if (client.uid != owner || profile == null) {
      throw const MedicalFailure(
        'Account changed or registration unavailable.',
      );
    }
    final contacts = profile['emergencyContacts'];
    final primary = contacts is Map ? contacts['primary'] : null;
    final contact = <String, dynamic>{
      for (final key in ['fullName', 'relationship', 'phoneNumber'])
        key: primary is Map ? primary[key] : null,
    };
    if (contact.values.any((value) => value != null && value is! String)) {
      throw const FormatException();
    }
    if (data != null &&
        (data['schemaVersion'] != 1 ||
            data['syntheticOnly'] != true ||
            data['guardianAuthorizationStatus'] != 'not_verified' ||
            data['revision'] is! int ||
            ![
              'not_started',
              'completed_synthetic',
            ].contains(data['medicalStatus']))) {
      throw const FormatException();
    }
    Map<String, dynamic>? answer(String key) {
      if (data == null || data['medicalStatus'] == 'not_started') return null;
      final value = data[key];
      if (value is! Map ||
          !['unknown', 'none_known', 'listed'].contains(value['state']) ||
          (value['state'] == 'listed' &&
              (value['details'] is! String ||
                  (value['details'] as String).trim().isEmpty))) {
        throw const FormatException();
      }
      return Map<String, dynamic>.from(value);
    }

    return MedicalSnapshot(
      ownerUid: owner,
      revision: data?['revision'] as int? ?? 0,
      completed: data?['medicalStatus'] == 'completed_synthetic',
      primaryContact: Map.unmodifiable(contact),
      conditions: answer('conditions'),
      allergies: answer('allergies'),
    );
  });
  Future<void> save(
    SyntheticMedicalDraft draft, {
    required int expectedRevision,
    required String requestId,
    String? expectedUid,
  }) => _safe(() async {
    if (expectedUid != null && client.uid != expectedUid) {
      throw const MedicalFailure('Account changed. Reopen your test record.');
    }
    await client.invoke('saveMySyntheticMedicalRecord', {
      ...draft.toPayload(),
      'expectedRevision': expectedRevision,
      'requestId': requestId,
    });
  });
  Future<void> clearMine({
    required int expectedRevision,
    required String requestId,
    required String expectedUid,
  }) => _safe(() async {
    if (client.uid != expectedUid) {
      throw const MedicalFailure('Account changed. Reopen your test record.');
    }
    await client.invoke('clearMySyntheticMedicalRecord', {
      'expectedRevision': expectedRevision,
      'requestId': requestId,
    });
  });
}
