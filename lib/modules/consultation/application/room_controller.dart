import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../domain/care/consultation_room.dart';
import '../../../domain/care/intake.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../services/consultations/consultation_media.dart';
import '../../../services/shared/product_failure_mapper.dart';
import '../../../shared/mutation_key.dart';

class ConsultationRoomController extends ChangeNotifier {
  ConsultationRoomController({
    required this.repository,
    required this.consents,
    required this.appointmentId,
    required this.media,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    media.addListener(_mediaChanged);
  }
  final ConsultationRoomRepository repository;
  final IntakeRepository consents;
  final String appointmentId;
  final ConsultationMedia media;
  final DateTime Function() _now;
  ConsultationRoomContext? data;
  ProductFailure? failure;
  String? message;
  bool loading = false, busy = false, wantsToJoin = false;
  bool _disposed = false, _refreshing = false, _presenceBusy = false;
  int _generation = 0;
  Duration _clockOffset = Duration.zero;
  String? _joinKey, _connectionId;
  int? _pendingConsent, _pendingStart;
  ({int version, ConsultationEndReason reason})? _pendingEnd;
  DateTime? _lastPresenceAt;
  ConsultationMediaState? _lastMediaState;

  DateTime get now => _now().add(_clockOffset);
  bool get connected =>
      _connectionId != null && media.state == ConsultationMediaState.connected;
  bool get inRoom => _connectionId != null;
  bool get pendingEnd => _pendingEnd != null;
  bool get isExpert => data?.viewerRole == ConsultationRole.ibclc;
  bool get canEnter {
    final value = data;
    return value != null &&
        !busy &&
        !pendingEnd &&
        value.windowOpen(now) &&
        value.videoProvider != VideoProvider.disabled &&
        value.caseConsent &&
        value.videoConsent &&
        (isExpert ||
            (value.intakeReady && (value.location?.validAt(now) ?? false)));
  }

  bool get canStart =>
      isExpert &&
      !busy &&
      !pendingEnd &&
      !data!.active &&
      !data!.ended &&
      data!.consultation?.roomStatus == VideoRoomStatus.ready &&
      ConsultationRole.values.every(
        (role) =>
            data!.participant(role)?.presence == ParticipantPresence.joined,
      );
  bool get canMarkNoShow =>
      isExpert &&
      !busy &&
      !(data?.ended ?? true) &&
      !(data?.active ?? true) &&
      !now.isBefore(
        data!.appointment.startsAt.add(const Duration(minutes: 10)),
      ) &&
      data!.participant(ConsultationRole.mom)?.joinedAt == null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _apply(ConsultationRoomContext value) {
    if (_disposed) return;
    final previous = data;
    if (previous != null &&
        (value.serverTime.isBefore(previous.serverTime) ||
            (previous.consultation?.id == value.consultation?.id &&
                (value.consultation?.version ?? 0) <
                    (previous.consultation?.version ?? 0)))) {
      return;
    }
    data = value;
    _clockOffset = value.serverTime.difference(_now());
    if (value.videoConsent) _pendingConsent = null;
    if (value.active) _pendingStart = null;
    if (value.ended) _pendingEnd = null;
  }

  Future<void> load() async {
    if (_disposed || busy || _refreshing) return;
    _refreshing = true;
    loading = data == null;
    final generation = _generation;
    _notify();
    try {
      final value = await repository.load(appointmentId);
      if (_disposed || generation != _generation) return;
      _apply(value);
      if (failure != null && !pendingEnd) {
        failure = null;
        message = null;
      }
      if (inRoom &&
          (value.ended ||
              !value.caseConsent ||
              !value.videoConsent ||
              value.consultation?.roomStatus == VideoRoomStatus.closing ||
              value.consultation?.roomStatus == VideoRoomStatus.closed)) {
        wantsToJoin = false;
        await _disconnectAndReport();
      }
      if (wantsToJoin &&
          !inRoom &&
          canEnter &&
          value.consultation?.roomStatus == VideoRoomStatus.ready) {
        await enter();
      } else if (inRoom && !busy) {
        await _sendPresence();
      }
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _fail(error);
        if (failure?.kind == ProductFailureKind.unauthenticated ||
            failure?.kind == ProductFailureKind.forbidden) {
          wantsToJoin = false;
          await _disconnectAndReport();
        }
      }
    } finally {
      _refreshing = false;
      loading = false;
      _notify();
    }
  }

  Future<void> grantVideoConsent() => _perform(() async {
    final value = data!;
    if (_pendingConsent == null) {
      final records = await consents.consents(value.appointment.episodeId);
      _pendingConsent =
          records
              .where((item) => item.scope == CareConsentScope.video)
              .firstOrNull
              ?.version ??
          0;
    }
    try {
      await consents.setConsent(
        value.appointment.episodeId,
        scope: CareConsentScope.video,
        active: true,
        expectedVersion: _pendingConsent!,
        policyVersion: value.consentPolicyVersion,
      );
      _pendingConsent = null;
      _apply(await repository.load(appointmentId));
    } catch (error) {
      if (!_uncertain(productFailure(error))) _pendingConsent = null;
      rethrow;
    }
  });

  Future<void> checkLocation(String region) => _perform(() async {
    final normalized = region.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
      message = 'Select the state where you are located for this consultation.';
      return;
    }
    final location = await repository.checkLocation(appointmentId, normalized);
    _apply(await repository.load(appointmentId));
    if (!location.passed) message = 'Your consultant cannot provide this service in your state right now. Return to booking to reschedule.';
  });

  Future<void> enter() async {
    if (!canEnter) return;
    final generation = _generation;
    wantsToJoin = true;
    _joinKey ??= newMutationKey();
    await _perform(() async {
      if (data?.consultation?.roomStatus != VideoRoomStatus.ready) {
        _apply(await repository.prepare(appointmentId));
        if (data?.consultation?.roomStatus != VideoRoomStatus.ready) return;
      }
      final joined = await repository.join(
        appointmentId,
        idempotencyKey: _joinKey!,
      );
      if (_disposed || generation != _generation || !wantsToJoin) {
        await _reportLeft(joined.connectionId);
        return;
      }
      _connectionId = joined.connectionId;
      _apply(joined.context);
      try {
        await media.connect(
          joined.credentials,
          provider: joined.context.videoProvider,
        );
        if (_disposed || generation != _generation) return;
        await _sendPresence(force: true);
      } catch (error) {
        _lastMediaState = null;
        await _sendPresence(force: true);
        rethrow;
      }
    });
  }

  Future<void> start() => _perform(() async {
    if (!isExpert) return;
    _pendingStart ??= data!.consultation!.version;
    try {
      _apply(
        await repository.start(appointmentId, expectedVersion: _pendingStart!),
      );
      _pendingStart = null;
    } catch (error) {
      if (!_uncertain(productFailure(error))) _pendingStart = null;
      rethrow;
    }
  });

  Future<void> end(ConsultationEndReason reason) => _perform(() async {
    if (!isExpert) return;
    _pendingEnd ??= (version: data!.consultation?.version ?? 0, reason: reason);
    final action = _pendingEnd!;
    try {
      _apply(
        await repository.end(
          appointmentId,
          expectedVersion: action.version,
          reason: action.reason,
        ),
      );
      _pendingEnd = null;
      wantsToJoin = false;
      await _disconnectAndReport();
    } catch (error) {
      if (!_uncertain(productFailure(error))) _pendingEnd = null;
      rethrow;
    }
  });
  Future<void> retryEnd() async {
    if (_pendingEnd case final action?) await end(action.reason);
  }

  Future<void> leave() async {
    ++_generation;
    wantsToJoin = false;
    busy = true;
    _joinKey = null;
    _notify();
    try {
      await _disconnectAndReport();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _disconnectAndReport() async {
    final connection = _connectionId;
    final generation = _generation;
    final lastPresenceAt = _lastPresenceAt;
    _connectionId = null;
    _lastPresenceAt = null;
    try {
      await media.disconnect();
    } catch (_) {
      // Suppress presence while disconnecting, but retain the same connection
      // for retry if local cleanup fails. Never restore a replaced/disposed one.
      if (!_disposed && generation == _generation && _connectionId == null) {
        _connectionId = connection;
        _lastPresenceAt = lastPresenceAt;
      }
      rethrow;
    }
    if (connection != null) await _reportLeft(connection);
  }

  Future<void> _reportLeft(String connection) async {
    try {
      await repository.presence(
        appointmentId,
        connectionId: connection,
        presence: ParticipantPresence.left,
      );
    } catch (_) {
      // Media is already disconnected; presence expires if the server cannot acknowledge leave.
    }
  }

  void _mediaChanged() {
    _notify();
    if (!busy && inRoom && !_presenceBusy) unawaited(_sendPresence());
  }

  Future<void> _sendPresence({bool force = false}) async {
    if (_disposed || _connectionId == null || _presenceBusy) return;
    final state = media.state;
    if (!force &&
        state == _lastMediaState &&
        _lastPresenceAt != null &&
        now.difference(_lastPresenceAt!) < const Duration(seconds: 30)) {
      return;
    }
    final connection = _connectionId!;
    final generation = _generation;
    _presenceBusy = true;
    try {
      final value = await repository.presence(
        appointmentId,
        connectionId: connection,
        presence: state == ConsultationMediaState.connected
            ? ParticipantPresence.joined
            : ParticipantPresence.reconnecting,
      );
      if (_disposed ||
          generation != _generation ||
          _connectionId != connection) {
        return;
      }
      _apply(value);
      _lastPresenceAt = now;
      _lastMediaState = state;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _fail(error);
      if (failure?.kind == ProductFailureKind.forbidden ||
          failure?.kind == ProductFailureKind.unauthenticated ||
          [
            'connection_replaced',
            'connection_closed',
            'consultation_ended',
            'appointment_state',
            'room_not_ready',
          ].contains(failure?.code)) {
        wantsToJoin = false;
        await _disconnectAndReport();
      }
    } finally {
      _presenceBusy = false;
      _notify();
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_disposed || busy || data == null) return;
    busy = true;
    failure = null;
    message = null;
    final generation = _generation;
    _notify();
    try {
      await action();
    } catch (error) {
      if (!_disposed && generation == _generation) _fail(error);
    } finally {
      if (generation == _generation) busy = false;
      _notify();
    }
  }

  static bool _uncertain(ProductFailure failure) =>
      failure.kind == ProductFailureKind.offline ||
      failure.kind == ProductFailureKind.unavailable;
  void _fail(Object error) {
    failure = productFailure(error);
    message = switch (failure?.code) {
      'consent_required' || 'consent_conflict' => 'Consent has changed. Review it again before continuing.',
      'location_required' => 'Confirm your state for this consultation again.',
      'room_not_open' => 'The consultation room opens 10 minutes before your appointment.',
      'room_window_closed' => 'The time to join this appointment has passed. Please reschedule.',
      'room_not_ready' => 'The consultation room is getting ready. Please try again shortly.',
      'video_unavailable' => 'Video service is unavailable right now. Try again later.',
      'participants_required' => 'The consultant can start once both participants have joined.',
      'media_not_connected' => 'Checking the video connection. Please wait.',
      'connection_replaced' => 'This connection changed on another page. Rejoin the room.',
      'connection_closed' => 'The previous connection closed. Rejoin the room.',
      'version_conflict' => 'The consultation status changed. Refresh to continue.',
      _ =>
        _uncertain(failure!) ? 'Connection interrupted. Try again. We will keep checking any actions already submitted.' : 'Could not complete this action. Refresh the consultation status and try again.',
    };
    if (failure?.code == 'connection_closed' ||
        failure?.code == 'connection_replaced') {
      _joinKey = null;
      wantsToJoin = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    wantsToJoin = false;
    media.removeListener(_mediaChanged);
    final connection = _connectionId;
    _connectionId = null;
    if (connection != null) unawaited(_reportLeft(connection));
    media.dispose();
    super.dispose();
  }
}
