import 'package:flutter/foundation.dart';
import '../../../../domain/care/care_plan.dart';
import '../../../../domain/care/clinical_note.dart';
import '../../../../domain/care/documentation.dart';
import '../../../../domain/shared/product_failure.dart';
import '../../../../shared/mutation_key.dart';

final class _PendingMutation {
  const _PendingMutation(
    this.perform,
    this.message, {
    this.replaceNote = false,
    this.replacePlan = false,
  });
  final Future<Object?> Function() perform;
  final String message;
  final bool replaceNote, replacePlan;
}

class DocumentationController extends ChangeNotifier {
  DocumentationController({
    required this.repository,
    required this.appointmentId,
  });
  final CareDocumentationRepository repository;
  final String appointmentId;
  CareDocumentation? data;
  ClinicalNoteContent note = const ClinicalNoteContent();
  CarePlanContent plan = CarePlanContent();
  bool loading = false,
      busy = false,
      noteDirty = false,
      planDirty = false,
      needsReload = false;
  ProductFailure? failure;
  String? message, validation;
  int noteEditorRevision = 0, planEditorRevision = 0;
  int _noteRevision = 0, _noteVersion = 0, _planVersion = 0, _generation = 0;
  bool _disposed = false;
  _PendingMutation? _pending;
  bool get uncertain => _pending != null;
  bool get dirty => noteDirty || planDirty;
  bool get editable =>
      !loading &&
      !busy &&
      !uncertain &&
      !needsReload &&
      (data?.editable ?? false);
  bool get noteEditable =>
      editable && data?.note?.status != ClinicalNoteStatus.signed;
  bool get canSign =>
      noteEditable && !noteDirty && data?.note != null && note.complete;
  bool get canPublish =>
      editable &&
      !planDirty &&
      !noteDirty &&
      data?.plan != null &&
      data?.note?.status == ClinicalNoteStatus.signed &&
      plan.complete &&
      plan.englishClientCopy;

  Future<void> load({bool discardChanges = false}) async {
    if (busy || uncertain) return;
    final generation = ++_generation;
    loading = true;
    failure = null;
    validation = null;
    notifyListeners();
    try {
      final result = await repository.load(appointmentId);
      if (_disposed || generation != _generation) return;
      _accept(
        result,
        replaceNote: discardChanges || !noteDirty,
        replacePlan: discardChanges || !planDirty,
      );
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _failed(error);
    }
    loading = false;
    notifyListeners();
  }

  void _accept(
    CareDocumentation value, {
    required bool replaceNote,
    required bool replacePlan,
  }) {
    data = value;
    needsReload = false;
    if (replaceNote) {
      note = value.note?.content ?? const ClinicalNoteContent();
      _noteRevision = value.note?.revision ?? 0;
      _noteVersion = value.note?.version ?? 0;
      noteDirty = false;
      noteEditorRevision++;
    }
    if (replacePlan) {
      plan = value.plan?.content ?? CarePlanContent();
      _planVersion = value.plan?.version ?? 0;
      planDirty = false;
      planEditorRevision++;
    }
  }

  void changeNote(ClinicalNoteContent value) {
    if (!noteEditable) return;
    note = value;
    noteDirty = true;
    message = validation = null;
    notifyListeners();
  }

  void changePlan(CarePlanContent value) {
    if (!editable) return;
    plan = value;
    planDirty = true;
    message = validation = null;
    notifyListeners();
  }

  Future<void> saveNote() async {
    if (!noteEditable) return;
    if (!note.withinLimits) {
      return _invalid('Each SOAP section can have up to 8,000 characters.');
    }
    final content = note,
        revision = _noteRevision,
        version = _noteVersion,
        key = newMutationKey();
    await _run(
      _PendingMutation(
        () => repository.saveNote(
          appointmentId,
          content: content,
          expectedRevision: revision,
          expectedVersion: version,
          idempotencyKey: key,
        ),
        'Clinical note draft saved',
        replaceNote: true,
      ),
    );
  }

  Future<void> sign() async {
    if (!canSign) return;
    final revision = _noteRevision,
        version = _noteVersion,
        key = newMutationKey();
    await _run(
      _PendingMutation(
        () => repository.signNote(
          appointmentId,
          expectedRevision: revision,
          expectedVersion: version,
          idempotencyKey: key,
        ),
        'Clinical note signed',
        replaceNote: true,
      ),
    );
  }

  Future<void> amend(String reason) async {
    if (!editable || data?.note?.status != ClinicalNoteStatus.signed) return;
    if (reason.trim().isEmpty || reason.trim().length > 1000) {
      return _invalid(
        'Enter a reason for the revision, up to 1,000 characters.',
      );
    }
    final revision = _noteRevision,
        version = _noteVersion,
        key = newMutationKey(),
        explanation = reason.trim();
    await _run(
      _PendingMutation(
        () => repository.amendNote(
          appointmentId,
          reason: explanation,
          expectedRevision: revision,
          expectedVersion: version,
          idempotencyKey: key,
        ),
        'Revision draft created. The original signed note remains.',
        replaceNote: true,
      ),
    );
  }

  Future<void> savePlan() async {
    if (!editable) return;
    if (!plan.withinLimits) {
      return _invalid(
        'Check the character limits. You can add up to 6 goals and 12 tasks.',
      );
    }
    final content = plan, version = _planVersion, key = newMutationKey();
    await _run(
      _PendingMutation(
        () => repository.savePlan(
          appointmentId,
          content: content,
          expectedVersion: version,
          idempotencyKey: key,
        ),
        'Care plan draft saved',
        replacePlan: true,
      ),
    );
  }

  Future<void> publish() async {
    if (!canPublish) return;
    final version = _planVersion, key = newMutationKey();
    await _run(
      _PendingMutation(
        () => repository.publish(
          appointmentId,
          expectedVersion: version,
          idempotencyKey: key,
        ),
        'Care plan published. The client can now view it.',
        replacePlan: true,
      ),
    );
  }

  Future<void> retry() async {
    if (busy) return;
    if (_pending case final pending?) {
      await _run(pending);
    } else {
      await load();
    }
  }

  Future<void> _run(_PendingMutation mutation) async {
    if (busy || loading) return;
    _pending = mutation;
    busy = true;
    failure = null;
    validation = message = null;
    notifyListeners();
    try {
      await mutation.perform();
      if (_disposed) return;
      _pending = null;
      if (mutation.replaceNote) noteDirty = false;
      if (mutation.replacePlan) planDirty = false;
      message = mutation.message;
      needsReload = true;
      final refreshed = await repository.load(appointmentId);
      if (_disposed) return;
      _accept(refreshed, replaceNote: !noteDirty, replacePlan: !planDirty);
    } catch (error) {
      if (_disposed) return;
      _failed(error);
    }
    busy = false;
    notifyListeners();
  }

  void _failed(Object error) {
    failure = error is ProductFailure
        ? error
        : const ProductFailure(ProductFailureKind.unavailable);
    if (![
      ProductFailureKind.offline,
      ProductFailureKind.unavailable,
    ].contains(failure!.kind)) {
      _pending = null;
    }
    if (failure!.kind == ProductFailureKind.conflict) needsReload = true;
    if ([
      ProductFailureKind.forbidden,
      ProductFailureKind.unauthenticated,
    ].contains(failure!.kind)) {
      data = null;
      note = const ClinicalNoteContent();
      plan = CarePlanContent();
      noteDirty = planDirty = false;
      needsReload = true;
    }
    validation = switch (failure!.code) {
      'case_consent_required' =>
        'The client withdrew data consent for this service.',
      'note_signed' => 'This note is signed. Reload it to create a revision.',
      'signed_note_required' =>
        'Sign the current clinical note before publishing the care plan.',
      'plan_incomplete' => 'Complete the summary, goals, and each task.',
      'plan_language_review_required' =>
        'Review the client-facing plan in English before publishing. The draft is still saved.',
      'documentation_not_ready' =>
        'You can write the clinical note and care plan after the consultation ends.',
      _ => null,
    };
  }

  void _invalid(String value) {
    validation = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
