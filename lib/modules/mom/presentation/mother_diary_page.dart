import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/mother/mother_diary.dart';
import '../../../domain/shared/local_date.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../application/mother_diary_controller.dart';
import 'mother_diary_editor.dart';

class MotherDiaryPage extends StatefulWidget {
  const MotherDiaryPage({
    super.key,
    required this.repository,
    required this.date,
    required this.onClose,
    this.section = DiarySection.rest,
  });
  final MotherDiaryRepository repository;
  final LocalDate date;
  final VoidCallback onClose;
  final DiarySection section;
  @override
  State<MotherDiaryPage> createState() => _MotherDiaryPageState();
}

class _MotherDiaryPageState extends State<MotherDiaryPage> {
  late final MotherDiaryController _controller = MotherDiaryController(
    repository: widget.repository,
    date: widget.date,
  );
  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MomCozyColors.background,
    body: MomCozyPageBody(
      child: MotherDiaryEditor(
        controller: _controller,
        initialSection: widget.section,
        onClose: widget.onClose,
      ),
    ),
  );
}
