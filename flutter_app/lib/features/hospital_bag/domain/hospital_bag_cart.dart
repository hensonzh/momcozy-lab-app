const hospitalBagCartUsdToCnyRate = 6.8;
const _maxHospitalBagCartGroups = 12;
const _maxHospitalBagCartItems = 120;

abstract interface class HospitalBagCartRepository {
  Future<HospitalBagCartSyncResult> syncCart({
    required HospitalBagCartSnapshot cart,
  });
}

enum HospitalBagCartTone {
  rose,
  mint,
  sky;

  static HospitalBagCartTone fromValue(Object? value) {
    return switch (_string(value)?.toLowerCase()) {
      'mint' => HospitalBagCartTone.mint,
      'sky' => HospitalBagCartTone.sky,
      _ => HospitalBagCartTone.rose,
    };
  }

  String get wireName => name;
}

class HospitalBagCartItem {
  const HospitalBagCartItem({
    required this.id,
    required this.name,
    required this.desc,
    required this.qty,
    required this.price,
    this.currency = 'CNY',
    this.priceLabel,
    this.salePriceLabel,
    this.officialPriceUsd,
    this.salePriceUsd,
    this.exchangeRateUsdCny,
    this.productUrl,
    this.imageUrl,
    this.imageAlt,
    this.skuId,
    this.model,
    this.keywords = const <String>[],
  });

  final String id;
  final String name;
  final String desc;
  final int qty;
  final double price;
  final String currency;
  final String? priceLabel;
  final String? salePriceLabel;
  final double? officialPriceUsd;
  final double? salePriceUsd;
  final double? exchangeRateUsdCny;
  final String? productUrl;
  final String? imageUrl;
  final String? imageAlt;
  final String? skuId;
  final String? model;
  final List<String> keywords;

  static HospitalBagCartItem? tryFromMap(Object? value) {
    final map = _map(value);
    if (map == null) return null;
    final id = _firstString(map, const ['id']);
    final name = _firstString(map, const ['name', 'label']);
    if (id == null && name == null) return null;

    return HospitalBagCartItem(
      id: id ?? name!,
      name: name ?? id!,
      desc: _firstString(map, const ['desc', 'description']) ?? '',
      qty: _positiveInt(
        _firstValue(map, const ['qty', 'quantity']),
        fallback: 1,
      ),
      price: _number(map['price']) ?? 0,
      currency: _normalizedCurrency(_firstString(map, const ['currency'])),
      priceLabel: _firstString(map, const ['price_label', 'priceLabel']),
      salePriceLabel: _firstString(map, const [
        'sale_price_label',
        'salePriceLabel',
      ]),
      officialPriceUsd: _number(
        _firstValue(map, const ['official_price_usd', 'officialPriceUsd']),
      ),
      salePriceUsd: _number(
        _firstValue(map, const ['sale_price_usd', 'salePriceUsd']),
      ),
      exchangeRateUsdCny: _number(
        _firstValue(map, const ['exchange_rate_usd_cny', 'exchangeRateUsdCny']),
      ),
      productUrl: _firstString(map, const ['product_url', 'productUrl']),
      imageUrl: _firstString(map, const ['image_url', 'imageUrl']),
      imageAlt: _firstString(map, const ['image_alt', 'imageAlt']),
      skuId: _firstString(map, const ['sku_id', 'skuId']),
      model: _firstString(map, const ['model']),
      keywords: _stringList(map['keywords']),
    );
  }

  bool get isUsd => currency.trim().toUpperCase() == 'USD';

  double get unitPriceCny =>
      _roundMoney(isUsd ? price * hospitalBagCartUsdToCnyRate : price);

  String get formattedPrice {
    if (isUsd) return formatHospitalBagCartMoney(unitPriceCny);
    final label = priceLabel?.trim();
    return label == null || label.isEmpty
        ? formatHospitalBagCartMoney(price)
        : label;
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'desc': desc,
    'qty': qty,
    'price': price,
    if (currency.trim().isNotEmpty) 'currency': currency,
    if (_hasText(priceLabel)) 'price_label': priceLabel,
    if (_hasText(salePriceLabel)) 'sale_price_label': salePriceLabel,
    if (officialPriceUsd != null) 'official_price_usd': officialPriceUsd,
    if (salePriceUsd != null) 'sale_price_usd': salePriceUsd,
    if (exchangeRateUsdCny != null) 'exchange_rate_usd_cny': exchangeRateUsdCny,
    if (_hasText(productUrl)) 'product_url': productUrl,
    if (_hasText(imageUrl)) 'image_url': imageUrl,
    if (_hasText(imageAlt)) 'image_alt': imageAlt,
    if (_hasText(skuId)) 'sku_id': skuId,
    if (_hasText(model)) 'model': model,
    if (keywords.isNotEmpty) 'keywords': List<String>.from(keywords),
  };
}

class HospitalBagCartGroup {
  const HospitalBagCartGroup({
    required this.title,
    required this.tone,
    required this.items,
  });

  final String title;
  final HospitalBagCartTone tone;
  final List<HospitalBagCartItem> items;

  static HospitalBagCartGroup? tryFromMap(
    Object? value, {
    int maxItems = _maxHospitalBagCartItems,
  }) {
    final map = _map(value);
    if (map == null || map['items'] is! List) return null;
    final items = (map['items']! as List)
        .take(maxItems)
        .map(HospitalBagCartItem.tryFromMap)
        .whereType<HospitalBagCartItem>()
        .toList(growable: false);
    return HospitalBagCartGroup(
      title: _firstString(map, const ['title']) ?? '待产包',
      tone: HospitalBagCartTone.fromValue(map['tone']),
      items: List<HospitalBagCartItem>.unmodifiable(items),
    );
  }

  HospitalBagCartGroup copyWith({List<HospitalBagCartItem>? items}) {
    return HospitalBagCartGroup(
      title: title,
      tone: tone,
      items: items ?? this.items,
    );
  }

  Map<String, Object?> toMap() => {
    'title': title,
    'tone': tone.wireName,
    'items': items.map((item) => item.toMap()).toList(growable: false),
  };
}

class HospitalBagCartTotals {
  const HospitalBagCartTotals({
    required this.subtotal,
    required this.itemCount,
    required this.discount,
    required this.shipping,
    required this.total,
  });

  final double subtotal;
  final int itemCount;
  final double discount;
  final double shipping;
  final double total;

  factory HospitalBagCartTotals.calculate(
    Iterable<HospitalBagCartGroup> groups,
  ) {
    var subtotal = 0.0;
    var itemCount = 0;
    for (final group in groups) {
      for (final item in group.items) {
        itemCount += item.qty;
        subtotal = _roundMoney(subtotal + item.unitPriceCny * item.qty);
      }
    }
    final discount = itemCount == 0 ? 0.0 : _roundMoney(subtotal * 0.08);
    const shipping = 0.0;
    return HospitalBagCartTotals(
      subtotal: subtotal,
      itemCount: itemCount,
      discount: discount,
      shipping: shipping,
      total: _roundMoney(subtotal - discount + shipping),
    );
  }

  Map<String, Object?> toMap() => {
    'subtotal': subtotal,
    'itemCount': itemCount,
    'discount': discount,
    'shipping': shipping,
    'total': total,
    'currency_totals': [
      {
        'currency': 'CNY',
        'subtotal': subtotal,
        'itemCount': itemCount,
        'discount': discount,
        'shipping': shipping,
        'total': total,
      },
    ],
    'mixed_currency': false,
  };
}

class HospitalBagCartSnapshot {
  HospitalBagCartSnapshot._(List<HospitalBagCartGroup> groups)
    : groups = List<HospitalBagCartGroup>.unmodifiable(groups),
      totals = HospitalBagCartTotals.calculate(groups);

  factory HospitalBagCartSnapshot.fromGroups(
    Iterable<HospitalBagCartGroup> groups,
  ) => HospitalBagCartSnapshot._(groups.toList(growable: false));

  final List<HospitalBagCartGroup> groups;
  final HospitalBagCartTotals totals;

  static HospitalBagCartSnapshot? tryFromCartUpdate(Object? value) {
    final map = _map(value);
    final rawGroups = map?['groups'];
    if (rawGroups is! List) return null;
    final groups = <HospitalBagCartGroup>[];
    var remainingItems = _maxHospitalBagCartItems;
    for (final rawGroup in rawGroups.take(_maxHospitalBagCartGroups)) {
      final group = HospitalBagCartGroup.tryFromMap(
        rawGroup,
        maxItems: remainingItems,
      );
      if (group == null) continue;
      groups.add(group);
      remainingItems -= group.items.length;
      if (remainingItems <= 0) break;
    }
    if (rawGroups.isNotEmpty && groups.isEmpty) return null;
    return HospitalBagCartSnapshot.fromGroups(groups);
  }

  HospitalBagCartSnapshot copyWithGroups(
    Iterable<HospitalBagCartGroup> groups,
  ) => HospitalBagCartSnapshot.fromGroups(groups);

  Iterable<HospitalBagCartItem> get items =>
      groups.expand((group) => group.items);

  Map<String, Object?> toAgentContext() => {
    'groups': groups.map((group) => group.toMap()).toList(growable: false),
    'totals': totals.toMap(),
  };
}

class HospitalBagCartArtifactSeed {
  const HospitalBagCartArtifactSeed({
    required this.artifactId,
    required this.snapshot,
  });

  final String artifactId;
  final HospitalBagCartSnapshot snapshot;

  static HospitalBagCartArtifactSeed? tryFromCartUpdate({
    required String artifactId,
    required Object? cartUpdate,
  }) {
    final normalizedId = artifactId.trim();
    final snapshot = HospitalBagCartSnapshot.tryFromCartUpdate(cartUpdate);
    if (normalizedId.isEmpty || snapshot == null) return null;
    return HospitalBagCartArtifactSeed(
      artifactId: normalizedId,
      snapshot: snapshot,
    );
  }
}

class HospitalBagCartRouteState {
  const HospitalBagCartRouteState({required this.cartId});

  final String cartId;
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

String formatHospitalBagCartMoney(double amount) {
  return '¥${amount.toStringAsFixed(2)}';
}

final defaultHospitalBagCartSnapshot = HospitalBagCartSnapshot.fromGroups(
  const [
    HospitalBagCartGroup(
      title: '妈妈护理',
      tone: HospitalBagCartTone.rose,
      items: [
        HospitalBagCartItem(
          id: 'mom-pad',
          name: '产褥垫组合装',
          desc: '入院与产后前几天使用',
          qty: 1,
          price: 59.9,
          keywords: ['产褥垫', '护理垫'],
        ),
        HospitalBagCartItem(
          id: 'mom-sanitary',
          name: '产妇卫生巾',
          desc: '夜用加长款，按住院天数准备',
          qty: 1,
          price: 39.9,
          keywords: ['卫生巾'],
        ),
        HospitalBagCartItem(
          id: 'mom-underwear',
          name: '一次性内裤',
          desc: '高腰柔软，产后更方便更换',
          qty: 1,
          price: 49.9,
          keywords: ['内裤', '一次性内裤'],
        ),
        HospitalBagCartItem(
          id: 'mom-wipes',
          name: '产后护理湿巾',
          desc: '温和清洁，适合住院随身包',
          qty: 1,
          price: 29.9,
          keywords: ['湿巾', '护理湿巾'],
        ),
        HospitalBagCartItem(
          id: 'mom-bottle',
          name: '产后冲洗瓶',
          desc: '产后清洁更方便，是否带去医院按医院建议',
          qty: 1,
          price: 39.9,
          keywords: ['冲洗瓶'],
        ),
        HospitalBagCartItem(
          id: 'mom-briefs',
          name: '高腰收腹内裤',
          desc: '不压腹，更适合产后恢复期穿着',
          qty: 1,
          price: 69.9,
          keywords: ['收腹', '高腰'],
        ),
      ],
    ),
    HospitalBagCartGroup(
      title: '宝宝出院',
      tone: HospitalBagCartTone.mint,
      items: [
        HospitalBagCartItem(
          id: 'baby-diaper',
          name: '新生儿纸尿裤',
          desc: 'NB 码小包装，避免带太多',
          qty: 1,
          price: 59.9,
          keywords: ['纸尿裤', '尿不湿'],
        ),
        HospitalBagCartItem(
          id: 'baby-wipes',
          name: '婴儿柔湿巾',
          desc: '无香精，适合换尿裤场景',
          qty: 1,
          price: 29.9,
          keywords: ['婴儿湿巾', '柔湿巾'],
        ),
        HospitalBagCartItem(
          id: 'baby-towel',
          name: '棉柔巾',
          desc: '洗脸、擦手、护理都可用',
          qty: 1,
          price: 29.9,
          keywords: ['棉柔巾'],
        ),
        HospitalBagCartItem(
          id: 'baby-blanket',
          name: '宝宝出院包被',
          desc: '柔软包裹，按季节搭配外层',
          qty: 1,
          price: 129,
          keywords: ['包被'],
        ),
        HospitalBagCartItem(
          id: 'baby-clothes',
          name: '新生儿连体衣礼盒',
          desc: '出院和回家第一周可替换穿',
          qty: 1,
          price: 159,
          keywords: ['连体衣', '衣服', '礼盒'],
        ),
        HospitalBagCartItem(
          id: 'baby-bath-towel',
          name: '婴儿浴巾',
          desc: '洗澡、包裹和保暖都可用',
          qty: 1,
          price: 59.9,
          keywords: ['浴巾'],
        ),
      ],
    ),
    HospitalBagCartGroup(
      title: '母乳喂养',
      tone: HospitalBagCartTone.sky,
      items: [
        HospitalBagCartItem(
          id: 'milk-pad',
          name: '防溢乳垫',
          desc: '母乳或混合喂养可先备小包装',
          qty: 1,
          price: 39.9,
          keywords: ['防溢乳垫', '乳垫'],
        ),
        HospitalBagCartItem(
          id: 'milk-cream',
          name: '乳头护理霜',
          desc: '哺乳初期不适时可咨询后使用',
          qty: 1,
          price: 49.9,
          keywords: ['乳头霜', '护理霜'],
        ),
        HospitalBagCartItem(
          id: 'milk-storage',
          name: '储奶袋',
          desc: '返家后储奶备用，住院可少量准备',
          qty: 1,
          price: 49.9,
          keywords: ['储奶袋'],
        ),
        HospitalBagCartItem(
          id: 'pump-m9',
          name: 'Momcozy M9 吸奶器',
          desc: '便携穿戴式双边吸乳，返家后排奶/储奶备用；是否带去医院先问医院',
          qty: 1,
          price: 1087.93,
          model: 'M9',
          keywords: ['吸奶器', '便携式吸奶器', 'M9', 'Mobile Flow'],
        ),
        HospitalBagCartItem(
          id: 'milk-bra',
          name: '哺乳文胸',
          desc: '产后和哺乳初期更舒适',
          qty: 1,
          price: 159,
          keywords: ['哺乳文胸', '文胸'],
        ),
        HospitalBagCartItem(
          id: 'milk-bottle',
          name: '宽口径奶瓶',
          desc: '混合喂养或返家后备用',
          qty: 1,
          price: 89.9,
          keywords: ['奶瓶'],
        ),
      ],
    ),
  ],
);

Map<String, Object?>? _map(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : null;
}

Object? _firstValue(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key)) return map[key];
  }
  return null;
}

String? _firstString(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _string(map[key]);
    if (value != null) return value;
  }
  return null;
}

String? _string(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(value.map(_string).whereType<String>());
}

double? _number(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int _positiveInt(Object? value, {required int fallback}) {
  final number = _number(value)?.toInt();
  return number == null || number < 1 ? fallback : number;
}

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String _normalizedCurrency(String? value) {
  return value?.trim().toUpperCase() == 'USD' ? 'USD' : 'CNY';
}
