import 'package:flutter/foundation.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/service_package.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/mutation_key.dart';
import '../../../shared/zoned_time.dart';

sealed class _Mutation {
  const _Mutation();
}

final class _Hold extends _Mutation {
  const _Hold(this.eligibilityId, this.providerId, this.startsAt, this.key);
  final String eligibilityId, providerId, key;
  final DateTime startsAt;
}

final class _Confirm extends _Mutation {
  const _Confirm(this.appointment);
  final CareAppointment appointment;
}

final class _Cancel extends _Mutation {
  const _Cancel(this.appointment);
  final CareAppointment appointment;
}

class BookingController extends ChangeNotifier {
  BookingController({
    required this.repository,
    required this.episodeId,
    DateTime Function()? now,
    String Function()? mutationKey,
  }) : deviceNow = now ?? DateTime.now,
       mutationKey = mutationKey ?? newMutationKey;
  final AppointmentRepository repository;
  final String episodeId;
  final DateTime Function() deviceNow;
  final String Function() mutationKey;
  BookingContext? data;
  BookingEligibility? eligibility;
  List<CareAppointment> appointments = const [];
  AppointmentAvailability? availability;
  String? region, providerId;
  bool serviceSuitable = false;
  EmergencyStatus? emergencyStatus;
  LocalDate? date;
  ProductFailure? loadFailure, availabilityFailure, failure;
  String? message;
  bool loading = true, loadingSlots = false, busy = false;
  bool _disposed = false;
  int _loadGeneration = 0, _slotsGeneration = 0;
  _Mutation? _pending;
  Duration _serverOffset = Duration.zero;
  DateTime get now => deviceNow().add(_serverOffset);
  bool get unresolvedMutation => _pending != null;
  bool get canEdit => !busy && !unresolvedMutation;
  bool get precheckReady => eligibility?.validAt(now) ?? false;
  bool get canPrecheck =>
      canEdit &&
      region != null &&
      regionSupported &&
      serviceSuitable &&
      emergencyStatus == EmergencyStatus.clear;
  bool get regionSupported =>
      data?.providers.any((item) => item.regions.contains(region)) ?? false;
  List<CareProvider> get providers =>
      data?.providers
          .where(
            (item) =>
                eligibility == null ||
                item.regions.contains(eligibility!.region),
          )
          .toList() ??
      const [];
  CareProvider? get provider =>
      providers.where((item) => item.id == providerId).firstOrNull;
  CareAppointment? get activeAppointment =>
      appointments.where((item) => item.activeAt(now)).firstOrNull;
  bool get canChoose =>
      canEdit &&
      precheckReady &&
      (data?.episode.canBook ?? false) &&
      activeAppointment == null;
  LocalDate get today => dateInTimezone(now, provider?.timezone ?? 'UTC');

  Future<void> load() async {
    if (busy) return;
    final generation = ++_loadGeneration;
    loading = true;
    loadFailure = null;
    notifyListeners();
    try {
      final result = await repository.context(episodeId);
      if (_disposed || generation != _loadGeneration) return;
      data = result;
      _serverOffset = result.serverTime.difference(deviceNow());
      eligibility = result.eligibility;
      appointments = result.appointments;
      region ??= eligibility?.region;
      serviceSuitable = eligibility?.serviceSuitable ?? serviceSuitable;
      emergencyStatus ??= eligibility?.emergencyStatus;
      if (!providers.any((item) => item.id == providerId)) {
        providerId = providers.firstOrNull?.id;
      }
      date ??= today;
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      loadFailure = _failure(error);
    }
    loading = false;
    notifyListeners();
    if (precheckReady && activeAppointment == null) await loadSlots();
  }

  void setRegion(String? value) {
    if (!canEdit) return;
    region = value;
    eligibility = null;
    availability = null;
    message = null;
    notifyListeners();
  }

  void setSuitable(bool value) {
    if (canEdit) {
      serviceSuitable = value;
      notifyListeners();
    }
  }

  void setEmergency(EmergencyStatus? value) {
    if (canEdit) {
      emergencyStatus = value;
      notifyListeners();
    }
  }

  Future<void> precheck() async {
    if (!canPrecheck) return;
    busy = true;
    failure = null;
    message = null;
    notifyListeners();
    try {
      final result = await repository.precheck(
        episodeId,
        region: region!,
        serviceSuitable: serviceSuitable,
        emergencyStatus: emergencyStatus!,
      );
      if (_disposed) return;
      eligibility = result;
      if (result.eligible) {
        if (!providers.any((value) => value.id == providerId)) {
          providerId = providers.firstOrNull?.id;
        }
        date = today;
      } else {
        message = switch (result.reason) {
          'emergency_help' => 'Contact local emergency services first.',
          'service_unsuitable' => 'Confirm that you need lactation or feeding support.',
          _ => 'This service is not available in your state yet. Check again later.',
        };
      }
    } catch (error) {
      if (_disposed) return;
      failure = _failure(error);
    }
    busy = false;
    notifyListeners();
    if (precheckReady) await loadSlots();
  }

  Future<void> selectProvider(String? value) async {
    if (!canChoose || value == null || value == providerId) return;
    providerId = value;
    if (date == null || date!.compareTo(today) < 0) date = today;
    await loadSlots();
  }

  Future<void> selectDate(LocalDate value) async {
    if (!canChoose || value == date) return;
    date = value;
    await loadSlots();
  }

  Future<void> loadSlots() async {
    if (_disposed || !precheckReady || providerId == null || date == null) {
      return;
    }
    final generation = ++_slotsGeneration;
    loadingSlots = true;
    availabilityFailure = null;
    availability = null;
    notifyListeners();
    try {
      final result = await repository.availability(
        episodeId,
        eligibilityId: eligibility!.id,
        providerId: providerId!,
        date: date!,
      );
      if (_disposed || generation != _slotsGeneration) return;
      availability = result;
      _serverOffset = result.serverTime.difference(deviceNow());
    } catch (error) {
      if (_disposed || generation != _slotsGeneration) return;
      availabilityFailure = _failure(error);
      if (availabilityFailure!.code == 'eligibility_required') {
        eligibility = null;
      }
    }
    loadingSlots = false;
    notifyListeners();
  }

  Future<void> hold(AppointmentSlot slot) async {
    if (!canChoose || !slot.available || providerId == null) return;
    _pending = _Hold(
      eligibility!.id,
      providerId!,
      slot.startsAt,
      mutationKey(),
    );
    await retry();
  }

  Future<void> confirm() async {
    final current = activeAppointment;
    if (!canEdit || current?.status != AppointmentStatus.held) return;
    _pending = _Confirm(current!);
    await retry();
  }

  Future<void> cancel() async {
    final current = activeAppointment;
    if (!canEdit ||
        current == null ||
        current.status == AppointmentStatus.inProgress) {
      return;
    }
    _pending = _Cancel(current);
    await retry();
    if (!_disposed && failure == null && activeAppointment == null) {
      await loadSlots();
    }
  }

  Future<void> retry() async {
    final operation = _pending;
    if (busy || operation == null) return;
    busy = true;
    failure = null;
    message = null;
    notifyListeners();
    try {
      final result = await switch (operation) {
        _Hold(
          :final eligibilityId,
          :final providerId,
          :final startsAt,
          :final key,
        ) =>
          repository.hold(
            episodeId,
            eligibilityId: eligibilityId,
            providerId: providerId,
            startsAt: startsAt,
            idempotencyKey: key,
          ),
        _Confirm(:final appointment) => repository.confirm(
          appointment.id,
          expectedVersion: appointment.version,
        ),
        _Cancel(:final appointment) => repository.cancel(
          appointment.id,
          expectedVersion: appointment.version,
        ),
      };
      if (_disposed) return;
      appointments = [
        result,
        ...appointments.where((item) => item.id != result.id),
      ];
      _pending = null;
      if (result.status == AppointmentStatus.expired) {
        message = 'Your selected time is no longer on hold. Choose another time.';
      }
    } catch (error) {
      if (_disposed) return;
      failure = _failure(error);
      if (![
        ProductFailureKind.offline,
        ProductFailureKind.unavailable,
      ].contains(failure!.kind)) {
        _pending = null;
      }
      message = switch (failure!.code) {
        'slot_unavailable' => 'That time was just booked. Refresh and choose another.',
        'hold_expired' => 'Your selected time is no longer on hold. Choose another time.',
        'eligibility_required' => 'Your booking eligibility check has expired. Confirm again.',
        'region_unavailable' => 'This consultant is not available in your state right now.',
        'service_not_bookable' => 'No consultations are available for this service. Refresh your service details.',
        'appointment_exists' => 'An appointment already exists. Refresh to view it.',
        _ => null,
      };
      if (failure!.code == 'eligibility_required') eligibility = null;
    }
    busy = false;
    notifyListeners();
  }

  void tick() {
    if (!_disposed &&
        appointments.any((item) => item.status == AppointmentStatus.held)) {
      notifyListeners();
    }
  }

  ProductFailure _failure(Object value) => value is ProductFailure
      ? value
      : const ProductFailure(ProductFailureKind.unavailable);
  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _slotsGeneration++;
    super.dispose();
  }
}
