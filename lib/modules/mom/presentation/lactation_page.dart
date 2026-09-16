import 'package:flutter/material.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/lactation/lactation_record.dart';
import '../../../domain/shared/local_date.dart';
import '../application/lactation_controller.dart';
import 'lactation_panel.dart';

class LactationPage extends StatefulWidget {
  const LactationPage({
    super.key,
    required this.repository,
    required this.ownerUserId,
    required this.date,
    required this.now,
    required this.onClose,
    this.create = false,
  });
  final LactationRepository repository;
  final String ownerUserId;
  final LocalDate date;
  final DateTime Function() now;
  final VoidCallback onClose;
  final bool create;
  @override
  State<LactationPage> createState() => _LactationPageState();
}

class _LactationPageState extends State<LactationPage> {
  late final controller = LactationController(
    repository: widget.repository,
    ownerUserId: widget.ownerUserId,
    date: widget.date,
    now: widget.now,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MomHomeTokens.background,
    body: MomCozyPageBody(
      child: LactationPanel(
        controller: controller,
        onClose: widget.onClose,
        initialCreate: widget.create,
      ),
    ),
  );
}
