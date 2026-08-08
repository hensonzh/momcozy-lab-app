enum DeliveryType {
  vaginal,
  cesarean,
  assisted,
  other;

  String get apiValue => name;

  String get label => switch (this) {
    DeliveryType.vaginal => 'Vaginal birth',
    DeliveryType.cesarean => 'Cesarean birth',
    DeliveryType.assisted => 'Assisted birth',
    DeliveryType.other => 'Other',
  };

  static DeliveryType? tryParse(Object? value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}
