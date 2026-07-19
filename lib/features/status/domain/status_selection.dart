enum StatusCareStage {
  pregnancy('pregnancy'),
  postpartum('postpartum');

  const StatusCareStage(this.storageValue);

  final String storageValue;

  static StatusCareStage? fromStorage(Object? value) {
    final normalized = value is String ? value.trim().toLowerCase() : '';
    return switch (normalized) {
      'pregnancy' => StatusCareStage.pregnancy,
      'postpartum' => StatusCareStage.postpartum,
      _ => null,
    };
  }
}

enum StatusIdentity {
  mom('mom'),
  baby('baby');

  const StatusIdentity(this.value);

  final String value;

  static StatusIdentity fromValue(Object? value) {
    return value == 'baby' ? StatusIdentity.baby : StatusIdentity.mom;
  }
}
