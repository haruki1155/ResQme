abstract interface class ConsentRepository {
  Future<bool> hasAcceptedTerms();
  Future<void> acceptTerms();
}
