import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';

/// Uses the assigned provider's name; API providers currently have no photo URL.
class ServiceExpertIdentity extends StatelessWidget {
  const ServiceExpertIdentity({
    super.key,
    required this.name,
    required this.label,
    this.bio = '',
    this.avatarSize = 38,
  });
  final String name, label, bio;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s.characters.first)
        .join()
        .toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: MomCozyColors.expertAccent,
            child: Text(
              initials.isEmpty ? 'IB' : initials,
              style: const TextStyle(fontSize: 12, color: MomCozyColors.card),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: MomCozyColors.expertMuted,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MomCozyColors.expertAccent,
                ),
              ),
              const Text(
                'IBCLC · Lactation Consultant',
                style: TextStyle(
                  fontSize: 10,
                  color: MomCozyColors.expertAccent,
                ),
              ),
              if (bio.isNotEmpty)
                Text(
                  bio,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    color: MomCozyColors.expertMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
