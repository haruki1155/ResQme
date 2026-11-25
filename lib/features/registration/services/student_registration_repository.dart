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

class StudentLoginQrCredential {
  const StudentLoginQrCredential({
    required this.payload,
    required this.credentialVersion,
    required this.status,
  });

  final String payload;
  final int credentialVersion;
  final String status;
}

class StudentLoginQrManageResult {
  const StudentLoginQrManageResult({this.credential, this.errorMessage});

  final StudentLoginQrCredential? credential;
  final String? errorMessage;
}

class LoginQrResolutionResult {
  const LoginQrResolutionResult.resolved({
    required this.email,
    required this.maskedEmail,
  })  : resolved = true,
        message = '';

  const LoginQrResolutionResult.failure(this.message)
      : resolved = false,
        email = null,
        maskedEmail = null;

  final bool resolved;
  final String? email;
  final String? maskedEmail;
  final String message;
}

abstract interface class StudentRegistrationRepository {
  Future<RegistrationResult> register(
    RegistrationDraft draft, {
    required bool acknowledged,
  });
  Future<RegistrationResult> signIn(String email, String password);
  Future<LoginQrResolutionResult> resolveLoginQr(String qrPayload);
  Future<StudentLoginQrManageResult> ensureMyLoginQr();
  Future<StudentLoginQrManageResult> replaceMyLoginQr();
  Future<String?> revokeMyLoginQr();
  Future<RegistrationResult> sendPasswordReset(String email);
  Future<RegistrationResult> loadOwnProfile();
  Future<void> signOut();
}
