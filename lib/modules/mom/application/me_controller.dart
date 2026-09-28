import 'package:flutter/foundation.dart';
import '../domain/me_experience.dart';

class MeController extends ChangeNotifier {
  MeController({required this.repository, required this.now, this.state});
  final MeRepository repository;
  final DateTime Function() now;
  MeState? state;
  bool loading = false, disposed = false;
  String? error;
  DateTime? day;
  int _generation = 0;
  Future<void>? _loading;
  DateTime? _requestedDay;
  int _loadingId = 0;
  void _notify() {
    if (!disposed) notifyListeners();
  }

  Future<void> load() {
    final current = now().toLocal();
    final requestDay = DateTime(current.year, current.month, current.day);
    if (_loading != null && _requestedDay == requestDay) return _loading!;
    _requestedDay = requestDay;
    final id = ++_loadingId;
    return _loading = _load().whenComplete(() {
      if (id == _loadingId) _loading = null;
    });
  }

  Future<void> _load() async {
    final date = now().toLocal();
    final today = DateTime(date.year, date.month, date.day);
    if (day != null && day != today) state = state?.copyWith(records: []);
    day = today;
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final value = await repository.load(date);
      if (!disposed && generation == _generation) {
        final received = value.records
            .map((e) => '${e.kind.name}:${e.id}')
            .toSet();
        state = value.copyWith(
          records: [
            ...value.records,
            ...?state?.records.where(
              (e) =>
                  value.failedMetrics.contains(e.kind) &&
                  !received.contains('${e.kind.name}:${e.id}'),
            ),
          ],
        );
      }
    } catch (_) {
      if (!disposed && generation == _generation) {
        error = 'Could not load. Please try again.';
      }
    } finally {
      if (generation == _generation) loading = false;
      _notify();
    }
  }

  Future<void> saveProfile(Map<String, Object?> values) async {
    ++_generation;
    loading = false;
    final result = await repository.saveProfile(Map.of(values));
    if (disposed) return;
    state = (state ?? const MeState()).copyWith(profile: result);
    _notify();
  }

  Future<void> saveConcern(MeConcern concern) async {
    ++_generation;
    loading = false;
    final value = await repository.saveConcern(concern);
    if (disposed) return;
    state = (state ?? const MeState()).copyWith(
      concerns: [...?state?.concerns.where((e) => e.id != value.id), value],
    );
    _notify();
  }

  Future<void> saveOrder(List<MeMetric> order) async {
    ++_generation;
    loading = false;
    final value = await repository.saveOrder(List.of(order));
    if (disposed) return;
    state = (state ?? const MeState()).copyWith(order: value);
    _notify();
  }

  Future<void> saveRecord(MeObservation record) async {
    ++_generation;
    loading = false;
    final value = await repository.saveRecord(record);
    if (disposed) return;
    state = (state ?? const MeState()).copyWith(
      records: [...?state?.records.where((e) => e.id != value.id), value],
    );
    _notify();
  }

  void applySharedRecords(List<MeObservation> records) {
    ++_generation;
    loading = false;
    final keys = records.map((e) => '${e.kind.name}:${e.id}').toSet();
    state = (state ?? const MeState()).copyWith(
      records: [
        ...?state?.records.where(
          (e) => !keys.contains('${e.kind.name}:${e.id}'),
        ),
        ...records,
      ],
    );
    _notify();
  }

  List<MeObservation> _today(MeMetric kind) {
    final date = now().toLocal();
    return state?.records.where((record) {
          final at = record.occurredAt.toLocal();
          return record.kind == kind &&
              at.year == date.year &&
              at.month == date.month &&
              at.day == date.day;
        }).toList() ??
        [];
  }

  /// The Me cards summarize today's records; individual records stay unchanged.
  String? todayCardValue(MeMetric kind) {
    if (kind != MeMetric.feed && kind != MeMetric.pump) return null;
    final records = {
      for (final record in _today(kind)) record.id: record,
    }.values;
    if (records.isEmpty) return null;
    if (kind == MeMetric.feed) {
      final count = records.length;
      return '$count ${count == 1 ? 'time' : 'times'}';
    }

    double total = 0;
    for (final record in records) {
      final raw = record.fields['volume_ml'];
      final parsed = raw == null
          ? double.tryParse(
              RegExp(
                    r'^(\d+(?:\.\d+)?) ml$',
                  ).firstMatch(record.value.trim())?.group(1) ??
                  '',
            )
          : raw is num && raw.isFinite && raw >= 0
          ? raw.toDouble()
          : null;
      if (parsed == null || !parsed.isFinite) return '— ml';
      total += parsed;
    }
    final amount = total.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return '$amount ml';
  }

  MeObservation? latest(MeMetric kind) {
    final values = _today(kind);
    values.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (kind == MeMetric.diaper && values.isNotEmpty) {
      final latest = values.first;
      final daily = values.where((e) => e.fields['daily_summary'] == true);
      final events = values.where((e) => e.fields['daily_summary'] != true);
      final wet = daily
          .map((e) => e.fields['wet'] as int?)
          .whereType<int>()
          .firstOrNull;
      final stool = daily
          .map((e) => e.fields['stool'] as int?)
          .whereType<int>()
          .firstOrNull;
      final count = daily.isEmpty
          ? events.fold<int>(
              0,
              (sum, e) => sum + (e.fields['count'] as int? ?? 1),
            )
          : (wet ??
                    events.fold<int>(
                      0,
                      (sum, e) => sum + (e.fields['wet'] as int? ?? 0),
                    )) +
                (stool ??
                    events.fold<int>(
                      0,
                      (sum, e) => sum + (e.fields['stool'] as int? ?? 0),
                    ));
      return MeObservation(
        id: latest.id,
        kind: kind,
        occurredAt: latest.occurredAt,
        value: '$count times',
      );
    }
    return values.firstOrNull;
  }

  @override
  void dispose() {
    disposed = true;
    ++_generation;
    super.dispose();
  }
}
