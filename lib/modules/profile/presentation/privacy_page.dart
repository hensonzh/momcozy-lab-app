import 'package:flutter/material.dart';

import '../../../shared/design_system/mom_home_tokens.dart';
import 'chat_first_more_copy.dart';

/// Account privacy information.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({
    super.key,
    required this.onBack,
    this.chatFirstExperience = false,
  });

  final VoidCallback onBack;
  final bool chatFirstExperience;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(chatFirstExperience ? ChatFirstMoreCopy.privacy : 'Privacy'),
      leading: BackButton(onPressed: onBack),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            chatFirstExperience
                ? ChatFirstMoreCopy.privacyTitle
                : 'Your privacy',
            style: MomHomeTokens.text(22, weight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            chatFirstExperience
                ? ChatFirstMoreCopy.privacyBody
                : 'Your records and conversations remain available in the app. To request account deletion, open More and select Request account deletion.',
            style: MomHomeTokens.text(14, height: 1.5),
          ),
        ],
      ),
    ),
  );
}
