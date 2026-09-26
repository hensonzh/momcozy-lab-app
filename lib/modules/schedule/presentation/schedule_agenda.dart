import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../application/schedule_controller.dart';
import '../domain/schedule.dart';
import 'schedule_design.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';

class ScheduleAgenda extends StatelessWidget {
  const ScheduleAgenda({
    super.key,
    required this.state,
    required this.onEdit,
    required this.onDelete,
  });
  final ScheduleState state;
  final ValueChanged<PersonalScheduleEntry> onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final entries = state.page!.agendaOn(state.selected);
    if (entries.isEmpty) {
      return MomSettingsCard(
        borderInside: true,
        backgroundDecoration: MomCardDecoration.utility,
        children: [
          Text(
            'Nothing scheduled for this day',
            style: ScheduleDesign.text(16, bold: true),
          ),
          Text(
            'Your personal schedule items will appear here.',
            style: ScheduleDesign.text(13, color: MomHomeTokens.secondary),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _entry(entries[i]),
        ],
      ],
    );
  }

  Widget _entry(ScheduleAgendaEntry entry) {
    final personal = entry.personal;
    const kind = ScheduleCardKind.personal;
    final actions = <String, String>{'edit': 'Edit', 'delete': 'Delete'};
    return Container(
      key: ValueKey('schedule-entry-${entry.key}'),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xfffffefd), kind.tint]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: ScheduleDesign.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 28,
            child: Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: kind.accent,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 68, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    entry.title,
                    style: ScheduleDesign.text(16, bold: true, lineHeight: 24),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kind.chip,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    entry.timeLabel,
                    style: ScheduleDesign.text(
                      12,
                      color: kind.ink,
                      lineHeight: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            top: 20,
            child: SizedBox.square(
              dimension: 44,
              child: PopupMenuButton<String>(
                tooltip: 'More options for ${entry.title}',
                enabled: actions.isNotEmpty,
                padding: EdgeInsets.zero,
                icon: Transform.translate(
                  offset: const Offset(0, 2),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/schedule_more.svg',
                      width: 3,
                      height: 15,
                    ),
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
                color: MomHomeTokens.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 4,
                shadowColor: const Color(0x1f59384d),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xfff0e5ed)),
                ),
                position: PopupMenuPosition.under,
                offset: const Offset(12, -16),
                menuPadding: const EdgeInsets.symmetric(vertical: 8),
                onSelected: (value) =>
                    value == 'edit' ? onEdit(personal) : onDelete(personal),
                itemBuilder: (_) => [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0)
                      const PopupMenuDivider(
                        height: 14,
                        color: Colors.transparent,
                      ),
                    PopupMenuItem(
                      value: actions.keys.elementAt(i),
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        actions.values.elementAt(i),
                        style: ScheduleDesign.text(13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
