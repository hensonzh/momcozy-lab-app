String formatPostpartumDay(int day) {
  final stage = switch (day) {
    >= 0 && <= 3 => '产后初期',
    <= 14 => '居家适应期',
    <= 42 => '恢复建立期',
    <= 84 => '功能恢复期',
    <= 183 => '节律重建期',
    <= 365 => '长期恢复期',
    _ => null,
  };
  if (day < 0) return '产后阶段待确认';
  return '产后第 $day 天${stage == null ? '' : ' · $stage'}';
}
