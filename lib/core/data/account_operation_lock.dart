class AccountOperationLock {
  bool busy = false;
  Future<T> run<T>(Future<T> Function() operation) async {
    if (busy) throw StateError('An account operation is in progress.');
    busy = true;
    try {
      return await operation();
    } finally {
      busy = false;
    }
  }
}
