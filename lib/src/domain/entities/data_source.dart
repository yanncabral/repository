/// The source of the current data in the repository.
enum RepositoryDatasource {
  /// The data is coming from the remote source (e.g. Rest API).
  remote,

  /// The data is coming from the local cache.
  local,

  /// The data was injected by the `update` method
  /// of `PropagatingRepositoryMixin`.
  optimistic,
}
