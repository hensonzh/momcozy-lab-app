import 'package:flutter/foundation.dart';
import '../../../../domain/care/care_report.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../domain/shared/product_failure.dart';

class WorkbenchReportController extends ChangeNotifier {
  WorkbenchReportController({
    required this.clients,
    required this.reports,
    required this.patientRef,
    String? episodeId,
    LocalDate? date,
  }) : selectedEpisodeId = episodeId,
       selectedDate = date;
  final WorkbenchRepository clients;
  final CareReportsRepository reports;
  final String patientRef;
  String? selectedEpisodeId;
  LocalDate? selectedDate;
  WorkbenchClient? client;
  ClientCareService? service;
  CareReportSnapshot? data;
  List<CareReportDay> history = const [];
  ProductFailure? failure;
  bool loading = false, saving = false, _disposed = false;
  int _generation = 0;
  bool get busy => loading || saving;
  CareReportPurpose get purpose => service?.episode.startsAt == null
      ? CareReportPurpose.preparation
      : CareReportPurpose.daily;

  Future<void> load() async {
    if (saving) return;
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final detail = await clients.client(patientRef);
      if (_disposed || generation != _generation) return;
      final id =
          selectedEpisodeId ??
          detail.client.services
              .where((value) => value.episode.ongoing)
              .firstOrNull
              ?.episode
              .id ??
          detail.client.services.firstOrNull?.episode.id;
      final selected = detail.client.services
          .where((value) => value.episode.id == id)
          .firstOrNull;
      if (selected == null) {
        throw const ProductFailure(
          ProductFailureKind.forbidden,
          code: 'not_found',
        );
      }
      final selectedPurpose = selected.episode.startsAt == null
          ? CareReportPurpose.preparation
          : CareReportPurpose.daily;
      final values = selected.caseConsent
          ? await Future.wait<Object>([
              reports.read(
                selected.episode.id,
                purpose: selectedPurpose,
                date: selectedDate,
              ),
              reports.history(selected.episode.id, purpose: selectedPurpose),
            ])
          : null;
      if (_disposed || generation != _generation) return;
      client = detail.client;
      service = selected;
      selectedEpisodeId = selected.episode.id;
      data = values == null ? null : values[0] as CareReportSnapshot;
      history = values == null ? const [] : values[1] as List<CareReportDay>;
      if (data != null &&
          (data!.purpose != selectedPurpose ||
              (selectedDate != null && data!.date != selectedDate) ||
              (data!.report != null &&
                  data!.report!.episodeId != selected.episode.id))) {
        throw const FormatException('Report scope mismatch.');
      }
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _clear();
      failure = _failure(error);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> selectService(String id) {
    if (saving) return Future.value();
    selectedEpisodeId = id;
    selectedDate = null;
    _clear();
    return load();
  }

  Future<void> selectDate(LocalDate? date) {
    if (saving) return Future.value();
    selectedDate = date;
    data = null;
    history = const [];
    return load();
  }

  Future<bool> generate() async {
    final selected = service;
    if (busy || selected == null || !selected.caseConsent) return false;
    return _mutate(() async {
      await reports.generate(
        selected.episode.id,
        purpose: purpose,
        date: selectedDate,
      );
    });
  }

  Future<bool> review(
    CareReport target,
    CareReportReviewDecision decision, {
    String feedback = '',
  }) async {
    if (busy) return false;
    if (data?.report?.id != target.id ||
        !target.reviewable ||
        data?.report?.review?.version != target.review?.version) {
      failure = const ProductFailure(
        ProductFailureKind.conflict,
        code: 'care_report_changed',
      );
      notifyListeners();
      return false;
    }
    if (decision == CareReportReviewDecision.feedback &&
        feedback.trim().runes.length < 5) {
      failure = const ProductFailure(
        ProductFailureKind.invalid,
        code: 'specific_feedback_required',
      );
      notifyListeners();
      return false;
    }
    return _mutate(() async {
      await reports.review(
        target.id,
        expectedVersion: target.review?.version ?? 0,
        decision: decision,
        feedback: feedback.trim(),
      );
    });
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    final generation = ++_generation;
    saving = true;
    failure = null;
    notifyListeners();
    try {
      await operation();
      if (_disposed || generation != _generation) return false;
      saving = false;
      await load();
      return failure == null;
    } catch (error) {
      if (_disposed || generation != _generation) return false;
      saving = false;
      failure = _failure(error);
      _clear();
      notifyListeners();
      return false;
    }
  }

  void _clear() {
    client = null;
    service = null;
    data = null;
    history = const [];
  }

  ProductFailure _failure(Object error) => error is ProductFailure
      ? error
      : const ProductFailure(ProductFailureKind.unavailable);
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
