import '../models/registration_draft.dart';
import '../models/student_registration_profile.dart';

enum RegistrationState {
  signedOut,
  pending,
  authCreatedProfileIncomplete,
  offline,
  failure,
}

class RegistrationResult {
  const RegistrationResult(this.state, {this.profile, this.message = ''});
  final RegistrationState state;
  final StudentRegistrationProfile? profile;
  final String message;
}

abstract interface class StudentRegistrationRepository {
  Future<RegistrationResult> register(
    RegistrationDraft draft, {
    required bool acknowledged,
  });
  Future<RegistrationResult> signIn(String email, String password);
  Future<RegistrationResult> sendPasswordReset(String email);
  Future<RegistrationResult> loadOwnProfile();
  Future<void> signOut();
}
