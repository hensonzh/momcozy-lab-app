/// A deletion receipt is required to undo the exact version that was removed.
final class RecordDeletion {
  const RecordDeletion({required this.id, required this.version});
  final String id;
  final int version;
}
