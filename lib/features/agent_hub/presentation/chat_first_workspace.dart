import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/primary_tab_activity.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/services/baby/baby_profiles_api_repository.dart';
import 'package:momcozy_flutter_app/services/baby/baby_records_api_repository.dart';
import 'package:momcozy_flutter_app/services/mother/mother_profile_api_repository.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';

import '../data/chat_first_voice.dart';
import '../domain/chat_first_daily_advice.dart';
import 'chat_first_avatar.dart';

const _roomAspectRatio = 1848 / 851;
const _navControlDecoration = BoxDecoration(
  color: Color(0xEEFFFDFB),
  shape: BoxShape.circle,
  border: Border.fromBorderSide(BorderSide(color: Color(0xA8FFFFFF))),
  boxShadow: [
    BoxShadow(color: Color(0x2251414C), blurRadius: 12, offset: Offset(0, 3)),
  ],
);
const _disabledNavControlDecoration = BoxDecoration(
  color: Color(0xFFDEDBD8),
  shape: BoxShape.circle,
  border: Border.fromBorderSide(BorderSide(color: Color(0xFFD2CECB))),
);

/// The board uses current-account baby facts, falling back to a confirmed
/// maternal delivery date only if no baby profile exists.
class ChatFirstWorkspace extends StatefulWidget {
  const ChatFirstWorkspace({
    super.key,
    required this.runtime,
    required this.role,
    required this.onOpenDrawer,
  });

  final MomCozyApiRuntime? runtime;
  final FamilyRole? role;
  final VoidCallback onOpenDrawer;

  @override
  State<ChatFirstWorkspace> createState() => _ChatFirstWorkspaceState();
}

class _ChatFirstWorkspaceState extends State<ChatFirstWorkspace>
    with WidgetsBindingObserver {
  Future<_DailyBoardData?>? _board;
  Future<DailyAdviceCatalog>? _catalog;
  final _clock = Stopwatch()..start();
  final _localAvatar = ChatFirstAvatarController();
  ChatFirstAvatarController? _avatar;
  ui.Image? _sceneImage;
  Timer? _frameTimer;
  Timer? _nextBoardDay;
  int? _seenHomeActivation;
  bool _imageRequested = false;
  bool _appVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _avatar = ChatFirstAvatarScope.maybeOf(context) ?? _localAvatar;
    _updateMotion();
    final tab = PrimaryTabActivity.maybeOf(context);
    if (tab?.selectedIndex == 2) {
      if (_seenHomeActivation != null &&
          _seenHomeActivation != tab!.activation) {
        // The owner may have changed their profile while on another page.
        _load();
      }
      _seenHomeActivation = tab!.activation;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasVisible = _appVisible;
    _appVisible = state == AppLifecycleState.resumed;
    _updateMotion();
    if (!_appVisible) {
      _nextBoardDay?.cancel();
      _nextBoardDay = null;
    } else if (!wasVisible) {
      _load(notify: true);
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (_avatar == null || !mounted) return;
    setState(_updateMotion);
  }

  bool get _reduceMotion => MomCozyMotion.isReduced(context);

  void _updateMotion() {
    final animate = mounted && _appVisible && !_reduceMotion;
    if (!animate) {
      _frameTimer?.cancel();
      _frameTimer = null;
      return;
    }
    if (!_imageRequested) {
      _imageRequested = true;
      unawaited(_loadSceneImage());
    }
    _frameTimer ??= Timer.periodic(const Duration(milliseconds: 64), (_) {
      if (mounted && _sceneImage != null) setState(() {});
    });
  }

  Future<void> _loadSceneImage() async {
    try {
      final bytes = await rootBundle.load(
        'assets/images/chat_first/momcozy-ai-room.png',
      );
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _sceneImage = frame.image);
    } catch (_) {
      // Image.asset remains the unmodified, accessible static fallback.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameTimer?.cancel();
    _nextBoardDay?.cancel();
    _clock.stop();
    _sceneImage?.dispose();
    _localAvatar.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatFirstWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtime != widget.runtime ||
        oldWidget.role != widget.role ||
        oldWidget.runtime?.currentSession.userId !=
            widget.runtime?.currentSession.userId ||
        oldWidget.runtime?.currentSession.babyId !=
            widget.runtime?.currentSession.babyId) {
      _load();
    }
  }

  void _load({bool notify = false}) {
    _nextBoardDay?.cancel();
    _nextBoardDay = null;
    final runtime = widget.runtime;
    final future = runtime == null ? null : _readBoard(runtime, widget.role);
    _board = future;
    if (notify && mounted) setState(() {});
    if (future != null) {
      unawaited(
        future.then((data) {
          if (mounted && identical(_board, future) && data != null) {
            if (dateInTimezone(runtime!.now(), data.timezone) != data.date) {
              // A read begun before midnight can finish after the day changes.
              _load(notify: true);
            } else {
              _scheduleNextBoardDay(data.timezone);
            }
          }
        }),
      );
    }
  }

  Future<DailyAdviceCatalog> _loadCatalog() => _catalog ??= rootBundle
      .load('assets/content/baby_daily_advice_0_364.json')
      .then(
        (bytes) => DailyAdviceCatalog.fromJson(
          Map<String, Object?>.from(
            jsonDecode(utf8.decode(bytes.buffer.asUint8List())) as Map,
          ),
        ),
      );

  Future<List<BabyRecord>> _recentBabyRecords(
    MomCozyApiRuntime runtime,
    String babyId,
    LocalDate today,
    String timezone,
    BabyRecordKind kind,
  ) async {
    final repository = BabyRecordsApiRepository(
      transport: runtime.jsonTransport,
    );
    final startDate = today.addDays(-1);
    final first = await repository.list(
      babyId: babyId,
      startDate: startDate,
      endDate: today.addDays(1),
      timezone: timezone,
      kind: kind,
      limit: 100,
    );
    // An incomplete page is not enough to make a personalized claim.
    if (first.total != first.items.length) return [];
    return first.items;
  }

  Future<_DailyBoardData?> _readBoard(
    MomCozyApiRuntime runtime,
    FamilyRole? role,
  ) async {
    try {
      final catalog = await _loadCatalog();
      final timezone = await runtime.timezoneProvider();
      final today = dateInTimezone(runtime.now(), timezone);
      final babies = await BabyProfilesApiRepository(
        transport: runtime.jsonTransport,
      ).list();
      final selectedId = runtime.currentSession.babyId;
      final selectedBaby = selectedId.isNotEmpty
          ? babies.where((baby) => baby.id == selectedId).firstOrNull
          : babies.length == 1
          ? babies.single
          : null;
      List<BabyRecord> records = const [];
      if (selectedBaby?.birthDate != null &&
          selectedBaby!.birthDate!.compareTo(today) <= 0 &&
          today.daysSince(selectedBaby.birthDate!) < 365) {
        try {
          final topic = catalog
              .entryFor(today.daysSince(selectedBaby.birthDate!))
              ?.topic;
          final kind = switch (topic) {
            DailyAdviceTopic.feeding => BabyRecordKind.feeding,
            DailyAdviceTopic.diaper => BabyRecordKind.diaper,
            DailyAdviceTopic.sleep => BabyRecordKind.sleep,
            _ => null,
          };
          if (kind != null) {
            records = await _recentBabyRecords(
              runtime,
              selectedBaby.id,
              today,
              timezone,
              kind,
            ).timeout(const Duration(seconds: 2));
          }
        } catch (_) {
          // A missing, partial or failed read leaves the exact daily copy.
        }
      }
      var banner = dailyBannerFor(
        babies,
        selectedBabyId: selectedId,
        today: today,
        catalog: catalog,
        recentRecords: records,
        recentWindowStart: zonedDayWindow(today.addDays(-1), timezone).start,
        now: runtime.now(),
      );
      // Chat-first accounts can have a confirmed delivery date but no baby
      // profile yet. Never associate maternal-only records with an infant.
      if (banner == null &&
          babies.isEmpty &&
          selectedId.isEmpty &&
          role == FamilyRole.mother) {
        final profile = await MotherProfileApiRepository(
          transport: runtime.jsonTransport,
          ownerUserId: runtime.currentSession.userId,
          timezoneProvider: runtime.timezoneProvider,
        ).get();
        banner = dailyBannerFromDeliveryDate(
          profile.deliveryDate,
          today,
          catalog: catalog,
        );
      }
      return banner == null ? null : _DailyBoardData(banner, timezone, today);
    } catch (_) {
      // No verified date, catalog, or timezone: do not invent a baby fact.
      return null;
    }
  }

  void _scheduleNextBoardDay(String timezone) {
    if (!_appVisible || widget.runtime == null) return;
    try {
      final instant = widget.runtime!.now();
      final date = dateInTimezone(instant, timezone);
      final untilTomorrow = zonedDayWindow(
        date,
        timezone,
      ).end.difference(instant);
      _nextBoardDay = Timer(
        untilTomorrow + const Duration(milliseconds: 100),
        () {
          if (mounted && _appVisible) _load(notify: true);
        },
      );
    } catch (_) {
      // Unknown timezone must not turn an unverified date into a baby fact.
    }
  }

  @override
  Widget build(BuildContext context) {
    final voice = ChatFirstVoiceScope.maybeOf(context);
    return Semantics(
      label: 'Momcozy AI 工作区',
      container: true,
      explicitChildNodes: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = MediaQuery.sizeOf(context).height < 680
              ? 170.0
              : (width * 0.49).clamp(174.0, 184.0);
          final figureWidth = width * 0.8;
          final boardWidth = width * 0.64;
          final boardSceneWidth = boardWidth * 2.07;
          return SizedBox(
            key: const ValueKey('chat-first-workspace'),
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFE9A575),
                          Color(0xFFD58B64),
                          Color(0xFFF0CEB2),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  top: 48,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned(
                          key: const ValueKey('chat-first-figure-scene'),
                          top: 0,
                          left: width * 0.23,
                          width: figureWidth,
                          height: figureWidth / _roomAspectRatio,
                          child:
                              !_reduceMotion &&
                                  _sceneImage != null &&
                                  _avatar != null
                              ? RepaintBoundary(
                                  child: CustomPaint(
                                    key: const ValueKey(
                                      'chat-first-avatar-paint',
                                    ),
                                    painter: ChatFirstAvatarPainter(
                                      image: _sceneImage!,
                                      controller: _avatar!,
                                      elapsedMilliseconds:
                                          _clock.elapsedMilliseconds,
                                      now: DateTime.now(),
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/chat_first/momcozy-ai-room.png',
                                  fit: BoxFit.fill,
                                  excludeFromSemantics: true,
                                ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          bottom: 0,
                          width: boardWidth,
                          child: ShaderMask(
                            key: const ValueKey('chat-first-board-crop'),
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0, 0.84, 1],
                            ).createShader(bounds),
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: boardSceneWidth,
                                maxWidth: boardSceneWidth,
                                minHeight: boardSceneWidth / _roomAspectRatio,
                                maxHeight: boardSceneWidth / _roomAspectRatio,
                                child: Image.asset(
                                  'assets/images/chat_first/momcozy-ai-room.png',
                                  width: boardSceneWidth,
                                  height: boardSceneWidth / _roomAspectRatio,
                                  fit: BoxFit.fill,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 79,
                  left: width * .68,
                  width: width * .23,
                  height: 64,
                  child: Semantics(
                    label: '和 Momcozy AI 打招呼',
                    button: true,
                    child: GestureDetector(
                      key: const ValueKey('chat-first-avatar-greet'),
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _avatar?.signal('greet'),
                    ),
                  ),
                ),
                Positioned(
                  top: 70,
                  bottom: 0,
                  left: width * 0.05,
                  width: width * 0.43,
                  child: FutureBuilder<_DailyBoardData?>(
                    future: _board,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done ||
                          snapshot.data == null) {
                        return const SizedBox.shrink();
                      }
                      final banner = snapshot.data!.banner;
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '宝宝出生 ${banner.ageDays} 天',
                              style: TextStyle(
                                color: Color(0xFF776A66),
                                fontSize: width < 360 ? 10 : 10.5,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            if (banner.advice != null)
                              Text(
                                banner.advice!,
                                key: const ValueKey('chat-first-daily-advice'),
                                style: TextStyle(
                                  color: Color(0xFF665D58),
                                  fontSize: width < 360 ? 9.5 : 10,
                                  height: 1.15,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  child: SizedBox(
                    height: 58,
                    child: Row(
                      children: [
                        IconButton(
                          key: const ValueKey('chat-first-menu'),
                          tooltip: '打开侧边栏',
                          onPressed: widget.onOpenDrawer,
                          icon: const DecoratedBox(
                            decoration: _navControlDecoration,
                            child: SizedBox.square(
                              dimension: 24,
                              child: Icon(Icons.menu_rounded, size: 14),
                            ),
                          ),
                          style: IconButton.styleFrom(
                            foregroundColor: const Color(0xFF66514C),
                            minimumSize: const Size.square(44),
                            maximumSize: const Size.square(44),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Momcozy AI',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF322D2D),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('chat-first-voice-toggle'),
                          tooltip: voice?.available == true
                              ? voice!.enabled
                                    ? voice.playing
                                          ? '正在播放语音，点击关闭'
                                          : '关闭语音播放'
                                    : '开启语音播放'
                              : '语音播放暂不可用',
                          onPressed: voice?.available == true
                              ? voice!.toggle
                              : null,
                          icon: DecoratedBox(
                            decoration:
                                voice?.available == true && voice!.enabled
                                ? _navControlDecoration
                                : _disabledNavControlDecoration,
                            child: SizedBox.square(
                              dimension: 24,
                              child: Icon(
                                voice?.available == true && voice!.enabled
                                    ? Icons.volume_up_outlined
                                    : Icons.volume_off_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                          style: IconButton.styleFrom(
                            foregroundColor: const Color(0xFFA55776),
                            disabledForegroundColor: const Color(0xFF706C6B),
                            minimumSize: const Size.square(44),
                            maximumSize: const Size.square(44),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 17,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.white, Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

final class _DailyBoardData {
  const _DailyBoardData(this.banner, this.timezone, this.date);
  final ChatFirstDailyBanner banner;
  final String timezone;
  final LocalDate date;
}
