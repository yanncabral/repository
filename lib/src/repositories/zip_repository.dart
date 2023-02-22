// import 'package:transfero_crypto/capabilites/repository/repositories/repository.dart';

// import 'custom_zip_repository.dart';

// /// A [Repository] that combines multiple [Repository]s into one.
// /// It takes a list of [Repository]s and a [zipper] function.
// /// The [zipper] function takes a list of streams and returns a single stream.
// /// The [zipper] function is called every time one of the [Repository]s emits a
// /// new value.
// class ZipRepository<Data> extends CustomZipRepository<Data> {
//   /// The list of [Repository]s to combine.
//   /// The [zipper] function will be called every time one of the [Repository]s
//   /// emits a new value.
//   @override
//   final List<Repository> repositories;

//   /// The function that combines the streams of the [Repository]s into one.
//   final Data Function(List<dynamic> streams) _zipper;

//   /// Creates a [ZipRepository] that combines multiple [Repository]s into one.
//   /// It takes a list of [Repository]s and a [zipper] function.
//   /// The [zipper] function takes a list of streams and returns a single stream.
//   /// The [zipper] function is called every time one of the [Repository]s emits a
//   /// new value.
//   ZipRepository({
//     required this.repositories,
//     required Data Function(List<dynamic> streams) zipper,
//     super.autoRefreshInterval,
//     super.resolveOnCreate,
//   }) : _zipper = zipper;

//   /// This function is called on resolve to get the streams to combine.
//   @override
//   Data zipper(List<dynamic> values) => _zipper(values);
// }
