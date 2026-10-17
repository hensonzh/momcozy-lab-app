/// Account-scoped role and the facts the chat-first flow actually collects.
enum FamilyRole {
  mother('mother', '妈妈'),
  father('father', '爸爸'),
  paternalGrandparent('paternal-grandparent', '爷爷/奶奶'),
  maternalGrandparent('maternal-grandparent', '外公/外婆'),
  otherFamily('other-family', '其他家庭成员');

  const FamilyRole(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static FamilyRole? fromWire(Object? value) {
    for (final role in values) {
      if (role.wireValue == value) return role;
    }
    return null;
  }
}

const chatFirstConcerns = <String, String>{
  'milk-supply': '奶量够不够',
  'feeding-enough': '宝宝吃饱了吗',
  'crying': '宝宝为什么哭',
  'stool': '宝宝便便情况',
  'baby-sleep': '宝宝睡得好吗',
  'growth': '宝宝生长发育',
  'recovery': '我的身体恢复',
  'mood': '情绪起伏或压力大',
  'fatigue': '睡不够、很疲惫',
  'support': '照顾宝宝缺少帮手',
};

class ChatFirstOnboardingDraft {
  ChatFirstOnboardingDraft({DateTime Function()? now})
    : now = now ?? DateTime.now;

  final DateTime Function() now;
  FamilyRole? role;
  final List<String> concerns = [];
  int? age;
  int? deliveryCount;
  DateTime? deliveryDate;
  int? gestationWeeks;
  int? gestationDays;
  int? babyCount;

  Map<String, Object?> toMap() {
    final selectedRole = role;
    if (selectedRole == null) {
      throw const FormatException('请选择家庭角色。');
    }
    if (selectedRole != FamilyRole.mother) {
      return {'role': selectedRole.wireValue};
    }
    if (age == null ||
        age! < 18 ||
        age! > 45 ||
        deliveryCount == null ||
        deliveryCount! < 1 ||
        deliveryCount! > 6) {
      throw const FormatException('请选择年龄与生育次数。');
    }
    final delivery = deliveryDate;
    final today = now();
    if (delivery == null ||
        DateTime(
          delivery.year,
          delivery.month,
          delivery.day,
        ).isAfter(DateTime(today.year, today.month, today.day)) ||
        delivery.isBefore(DateTime(today.year - 2, 1))) {
      throw const FormatException('请选择有效的分娩日期。');
    }
    if (gestationWeeks == null ||
        gestationWeeks! < 24 ||
        gestationWeeks! > 42 ||
        gestationDays == null ||
        gestationDays! < 0 ||
        gestationDays! > 6 ||
        (gestationWeeks! >= 37 && gestationDays != 0) ||
        babyCount == null ||
        babyCount! < 1 ||
        babyCount! > 4) {
      throw const FormatException('请完整选择分娩时孕周与宝宝数量。');
    }
    if (concerns.length != concerns.toSet().length ||
        concerns.any((item) => !chatFirstConcerns.containsKey(item))) {
      throw const FormatException('关注点包含无效选项。');
    }
    String two(int value) => value.toString().padLeft(2, '0');
    return {
      'role': selectedRole.wireValue,
      'stage': 'postpartum',
      'age': age,
      'delivery_count': deliveryCount,
      'delivery_date':
          '${delivery.year}-${two(delivery.month)}-${two(delivery.day)}',
      'client_timezone_offset_minutes': today.timeZoneOffset.inMinutes,
      'gestation_weeks': gestationWeeks,
      'gestation_days': gestationDays,
      'baby_count': babyCount,
      'concerns': List<String>.of(concerns),
    };
  }
}
