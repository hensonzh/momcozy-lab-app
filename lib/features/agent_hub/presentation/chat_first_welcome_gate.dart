import 'dart:async';

import 'package:flutter/material.dart';

import '../agent_hub_page.dart';
import '../data/chat_first_welcome_coordinator.dart';
import '../domain/chat_first_welcome.dart';

typedef ChatFirstWelcomeBuilder =
    Widget Function(
      BuildContext context,
      AgentHubAutoRunRequest? request,
      String currentWelcomeKey,
      ValueChanged<String> onAccepted,
      VoidCallback onRejected,
      int retryToken,
    );

/// Keep normal chat usable while an account-scoped, real-profile welcome is
/// prepared. Fail closed on uncertain history rather than sending twice.
class ChatFirstWelcomeGate extends StatefulWidget {
  const ChatFirstWelcomeGate({
    super.key,
    required this.activationKey,
    required this.coordinator,
    required this.visible,
    required this.builder,
  });

  final String activationKey;
  final ChatFirstWelcomeCoordinator coordinator;
  final bool visible;
  final ChatFirstWelcomeBuilder builder;

  @override
  State<ChatFirstWelcomeGate> createState() => _ChatFirstWelcomeGateState();
}

class _ChatFirstWelcomeGateState extends State<ChatFirstWelcomeGate>
    with WidgetsBindingObserver {
  ChatFirstWelcomeRequest? _prepared;
  String _currentWelcomeKey = '';
  bool _loading = true;
  bool _loadFailed = false;
  bool _runFailed = false;
  int _generation = 0;
  int _retryToken = 0;
  bool _appForeground = true;
  Timer? _nextLocalDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepare();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nextLocalDay?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _appForeground;
    _appForeground = state == AppLifecycleState.resumed;
    if (!_appForeground) {
      _nextLocalDay?.cancel();
      _nextLocalDay = null;
    }
    if (!wasForeground && _appForeground && widget.visible) {
      _prepare(notify: true);
    }
  }

  @override
  void didUpdateWidget(covariant ChatFirstWelcomeGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationKey != widget.activationKey ||
        oldWidget.coordinator.role != widget.coordinator.role ||
        (!oldWidget.visible && widget.visible)) {
      _prepare(notify: true);
    } else if (oldWidget.visible && !widget.visible) {
      _nextLocalDay?.cancel();
      _nextLocalDay = null;
    }
  }

  void _prepare({bool notify = false}) {
    final generation = ++_generation;
    _scheduleLocalDayRefresh();
    void start() {
      _prepared = null;
      _currentWelcomeKey = '';
      _loading = true;
      _loadFailed = false;
      _runFailed = false;
    }

    if (notify) {
      setState(start);
    } else {
      start();
    }
    unawaited(() async {
      try {
        final preparation = await widget.coordinator.prepareState();
        if (!mounted || generation != _generation) return;
        setState(() {
          _prepared = preparation.request;
          _currentWelcomeKey = preparation.currentKey;
          _loading = false;
        });
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _loadFailed = true;
          _loading = false;
        });
      }
    }());
  }

  void _scheduleLocalDayRefresh() {
    _nextLocalDay?.cancel();
    _nextLocalDay = null;
    if (!widget.visible || !_appForeground) return;
    final now = widget.coordinator.now().toLocal();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _nextLocalDay = Timer(
      tomorrow.difference(now) + const Duration(milliseconds: 100),
      () {
        if (mounted && widget.visible && _appForeground) {
          _prepare(notify: true);
        }
      },
    );
  }

  void _accepted(String key) {
    if (_prepared?.idempotencyKey != key) return;
    final generation = _generation;
    unawaited(() async {
      try {
        await widget.coordinator.markAccepted(key);
      } catch (_) {
        // On restart, owner-scoped Agent history still prevents a duplicate.
      }
      if (mounted && generation == _generation) {
        setState(() {
          _prepared = null;
          _runFailed = false;
        });
      }
    }());
  }

  void _rejected() {
    if (mounted) setState(() => _runFailed = true);
  }

  void _retry() {
    if (_loadFailed) {
      _prepare(notify: true);
      return;
    }
    setState(() {
      _runFailed = false;
      ++_retryToken;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(6),
          child: Text('正在准备欢迎语…', style: TextStyle(fontSize: 12)),
        ),
      if (_loadFailed || _runFailed)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '欢迎语暂时无法生成，对话仍可正常使用。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(onPressed: _retry, child: const Text('重试')),
            ],
          ),
        ),
      Expanded(
        child: widget.builder(
          context,
          _prepared == null
              ? null
              : AgentHubAutoRunRequest(
                  requestMessage: _prepared!.message,
                  idempotencyKey: _prepared!.idempotencyKey,
                  metadata: _prepared!.metadata,
                ),
          _currentWelcomeKey,
          _accepted,
          _rejected,
          _retryToken,
        ),
      ),
    ],
  );
}
