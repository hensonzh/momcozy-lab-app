import 'package:flutter/foundation.dart';
import '../../../domain/care/appointment.dart';
import '../../../domain/shared/product_failure.dart';

class AppointmentCancellationController extends ChangeNotifier {
  AppointmentCancellationController({
    required this.repository,
    required CareAppointment appointment,
  }) : current = appointment;

  final AppointmentRepository repository;
  CareAppointment current;
  ProductFailure? failure;
  bool busy = false, uncertain = false, _disposed = false;
  bool get canCancel => !busy && current.status == AppointmentStatus.confirmed;

  Future<CareAppointment?> cancel() async {
    if (!canCancel) return null;
    return _run(
      () => repository.cancel(current.id, expectedVersion: current.version),
      mutation: true,
    );
  }

  Future<CareAppointment?> refresh() async {
    if (busy) return null;
    return _run(() => repository.read(current.id), mutation: false);
  }

  Future<CareAppointment?> _run(
    Future<CareAppointment> Function() operation, {
    required bool mutation,
  }) async {
    busy = true;
    failure = null;
    notifyListeners();
    CareAppointment? result;
    try {
      final value = await operation();
      if (_disposed) return null;
      current = value;
      uncertain = false;
      if (value.status == AppointmentStatus.cancelled) {
        result = value;
      } else if (mutation) {
        failure = const ProductFailure(ProductFailureKind.conflict);
      }
    } catch (error) {
      if (_disposed) return null;
      failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
      if (mutation) uncertain = true;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
