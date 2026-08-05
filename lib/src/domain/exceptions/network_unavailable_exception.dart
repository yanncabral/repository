class NetworkUnavailableException implements Exception {
  const NetworkUnavailableException([this.cause]);

  final Object? cause;

  @override
  String toString() {
    return 'NetworkUnavailableException: $cause';
  }
}
