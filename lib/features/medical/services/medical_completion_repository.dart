import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/pilot_client.dart';

class MedicalCompletionFailure implements Exception {
  const MedicalCompletionFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class MedicalCompletionRepository {
  MedicalCompletionRepository(this.client);
  final PilotClient client;

  Future<Map<String, dynamic>> loadEligibility() async {
    final uid = client.uid;
    if (uid == null) {
      throw const MedicalCompletionFailure('Sign in to continue.');
    }
    try {
      final profile = await client.invoke('getMyStudentProfile', {});
      if (client.uid != uid ||
          !['not_started', 'complete'].contains(profile['medicalStatus']) ||
          profile['medicalRevision'] is! int) {
        throw const FormatException();
      }
      return profile;
    } catch (error) {
      if (error is MedicalCompletionFailure) rethrow;
      throw const MedicalCompletionFailure(
        'Medical form status is unavailable. Retry.',
      );
    }
  }

  Future<void> complete({
    required int expectedRevision,
    required String requestId,
    required Map<String, dynamic> conditions,
    required Map<String, dynamic> allergies,
    required Map<String, dynamic> primaryContact,
    required String expectedUid,
  }) async {
    if (client.uid != expectedUid) {
      throw const MedicalCompletionFailure(
        'Account changed. Reopen the medical form.',
      );
    }
    try {
      await client.invoke('completeMyMedicalRecord', {
        'conditions': conditions,
        'allergies': allergies,
        'primaryContact': primaryContact,
        'selfReportConfirmed': true,
        'expectedRevision': expectedRevision,
        'requestId': requestId,
      });
      if (client.uid != expectedUid) {
        throw const MedicalCompletionFailure(
          'Account changed. Reopen the medical form.',
        );
      }
    } catch (error) {
      if (error is MedicalCompletionFailure) rethrow;
      final code = error is FirebaseException ? error.code : '';
      throw MedicalCompletionFailure(switch (code) {
        'failed-precondition' =>
          'Your information changed or the form is locked. Reload and retry.',
        'already-exists' =>
          'This form request was already used. Reload and retry.',
        'unavailable' ||
        'deadline-exceeded' => 'Connection unavailable. Retry when online.',
        _ =>
          error is TimeoutException
              ? 'Connection unavailable. Retry when online.'
              : 'Unable to save the required medical information. Retry.',
      });
    }
  }
}
