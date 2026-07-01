abstract interface class HospitalBagCartRepository {
  Future<HospitalBagCartSyncResult> syncCart({
    required String userId,
    required List<HospitalBagPackedItem> items,
  });
}

class HospitalBagPackedItem {
  const HospitalBagPackedItem({
    required this.id,
    required this.title,
    required this.packed,
  });

  final String id;
  final String title;
  final bool packed;

  Map<String, Object?> toMap() => {'id': id, 'title': title, 'packed': packed};
}

class HospitalBagCartSyncResult {
  const HospitalBagCartSyncResult({
    required this.message,
    required this.syncedCount,
  });

  final String message;
  final int syncedCount;
}
