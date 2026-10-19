import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/primary_tab_activity.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_profile.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/services/mother/mother_profile_api_repository.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';

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

/// The board uses only current-account maternal facts. Missing, future and
/// failed reads deliberately leave it blank instead of displaying demo data.
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
  Future<MotherProfile?>? _profile;
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
            widget.runtime?.currentSession.userId) {
      _load();
    }
  }

  void _load({bool notify = false}) {
    _nextBoardDay?.cancel();
    _nextBoardDay = null;
    final runtime = widget.runtime;
    final future = runtime == null || widget.role != FamilyRole.mother
        ? null
        : MotherProfileApiRepository(
                transport: runtime.jsonTransport,
                ownerUserId: runtime.currentSession.userId,
                timezoneProvider: runtime.timezoneProvider,
              )
              .get()
              .then<MotherProfile?>((profile) => profile)
              .catchError((_) => null);
    _profile = future;
    if (notify && mounted) setState(() {});
    if (future != null) {
      unawaited(
        future.then((profile) {
          if (mounted && identical(_profile, future) && profile != null) {
            _scheduleNextBoardDay(profile);
          }
        }),
      );
    }
  }

  void _scheduleNextBoardDay(MotherProfile profile) {
    if (!_appVisible || widget.runtime == null) return;
    try {
      final instant = widget.runtime!.now();
      final date = dateInTimezone(instant, profile.timezone);
      final untilTomorrow = zonedDayWindow(
        date,
        profile.timezone,
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
    final runtime = widget.runtime;
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
                  left: width * 0.05,
                  width: width * 0.43,
                  child: FutureBuilder<MotherProfile?>(
                    future: _profile,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done ||
                          runtime == null) {
                        return const SizedBox.shrink();
                      }
                      int? days;
                      final profile = snapshot.data;
                      if (profile != null) {
                        try {
                          days = profile.postpartumDay(
                            dateInTimezone(runtime.now(), profile.timezone),
                          );
                        } catch (_) {
                          // Failed timezone resolution leaves the board blank.
                        }
                      }
                      if (days == null) return const SizedBox.shrink();
                      return Text(
                        '宝宝出生 $days 天',
                        style: TextStyle(
                          color: Color(0xFF776A66),
                          fontSize: width < 360 ? 10 : 10.5,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
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
                          tooltip: '语音播放暂不可用',
                          onPressed: null,
                          icon: const DecoratedBox(
                            decoration: _disabledNavControlDecoration,
                            child: SizedBox.square(
                              dimension: 24,
                              child: Icon(Icons.volume_off_outlined, size: 18),
                            ),
                          ),
                          style: IconButton.styleFrom(
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
