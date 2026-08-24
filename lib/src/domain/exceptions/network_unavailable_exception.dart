/// Indicates that an HTTP request could not reach the network.
class NetworkUnavailableException implements Exception {
  /// Creates a network-unavailable exception with its original [cause].
  const NetworkUnavailableException([this.cause]);

  /// The transport error that caused this exception.
  final Object? cause;

  @override
  String toString() {
    return 'NetworkUnavailableException: $cause';
  }
}
