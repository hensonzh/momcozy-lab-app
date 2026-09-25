String formatPostpartumDay(int day) {
  final stage = switch (day) {
    >= 0 && <= 3 => 'Early postpartum',
    <= 14 => 'Settling in at home',
    <= 42 => 'Early recovery',
    <= 84 => 'Building strength',
    <= 183 => 'Finding your rhythm',
    <= 365 => 'Ongoing recovery',
    _ => null,
  };
  if (day < 0) return 'Postpartum stage not set';
  return 'Postpartum day $day${stage == null ? '' : ' · $stage'}';
}
