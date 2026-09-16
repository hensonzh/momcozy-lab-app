import 'package:flutter/foundation.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/care/service_package.dart';
import '../../../domain/shared/product_failure.dart';

class CareOverviewController extends ChangeNotifier {
  CareOverviewController(
    this.repository, {
    this.appointmentRepository,
    this.now = DateTime.now,
  });
  final AppointmentRepository? appointmentRepository;
  final DateTime Function() now;
  Map<String, BookingContext> bookingContexts = {};
  Set<String> bookingFailures = {};
  bool bookingLoading = false;
  final CareRepository repository;
  ServiceCatalog? catalog;
  CareOverview? overview;
  bool loading = true;
  ProductFailure? failure;
  bool _disposed = false;
  int _generation = 0;
  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = await Future.wait<Object>([
        repository.catalog(),
        repository.overview(),
      ]);
      if (_disposed || generation != _generation) return;
      catalog = result[0] as ServiceCatalog;
      overview = result[1] as CareOverview;
      final appointments = appointmentRepository;
      bookingContexts = {};
      bookingFailures = {};
      if (appointments != null) {
        bookingLoading = true;
        notifyListeners();
        final contexts = await Future.wait(
          overview!.episodes.where((episode) => episode.ongoing).map((
            episode,
          ) async {
            try {
              return (
                id: episode.id,
                context: await appointments.context(episode.id),
              );
            } catch (_) {
              return (id: episode.id, context: null);
            }
          }),
        );
        if (_disposed || generation != _generation) return;
        bookingContexts = {
          for (final entry in contexts)
            if (entry.context != null) entry.id: entry.context!,
        };
        bookingFailures = {
          for (final entry in contexts)
            if (entry.context == null) entry.id,
        };
      }
      bookingLoading = false;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
    }
    bookingLoading = false;
    loading = false;
    notifyListeners();
  }

  CareAppointment? nextAppointment(String episodeId) {
    final instant = now();
    final appointments =
        bookingContexts[episodeId]?.appointments
            .where(
              (appointment) =>
                  appointment.activeAt(instant) &&
                  (appointment.endsAt.isAfter(instant) ||
                      appointment.status == AppointmentStatus.inProgress),
            )
            .toList() ??
        [];
    appointments.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return appointments.firstOrNull;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
