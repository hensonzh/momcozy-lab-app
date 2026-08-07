import 'package:flutter/material.dart';

class MoreProfileOverviewPage extends StatelessWidget {
  const MoreProfileOverviewPage({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: ValueKey('route-page-$path'),
      color: _ProfileColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        children: const [
          _ProfileHeader(),
          SizedBox(height: 24),
          _EmptyProfileCard(),
          SizedBox(height: 16),
          _PrivacyCard(),
        ],
      ),
    );
  }
}

class MoreBodyProfileEditorPage extends StatelessWidget {
  const MoreBodyProfileEditorPage({
    super.key,
    required this.path,
    required this.onBack,
  });

  final String path;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: ValueKey('route-page-$path'),
      color: _ProfileColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('more-body-profile-back'),
                tooltip: 'Back to Body Profile',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Body Profile', style: _ProfileText.pageTitle),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _UnavailableEditorCard(),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onBack,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _ProfileColors.wine,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to Body Profile'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Body Profile', style: _ProfileText.pageTitle),
              SizedBox(height: 6),
              Text('Private health data', style: _ProfileText.supporting),
            ],
          ),
        ),
        _RoundIcon(icon: Icons.health_and_safety_outlined),
      ],
    );
  }
}

class _EmptyProfileCard extends StatelessWidget {
  const _EmptyProfileCard();

  @override
  Widget build(BuildContext context) {
    return const _ProfileCard(
      semanticLabel:
          'No body profile data yet. Confirmed recovery data will appear only after a secure profile service is connected.',
      child: Column(
        children: [
          _RoundIcon(icon: Icons.assignment_outlined, size: 68, iconSize: 32),
          SizedBox(height: 18),
          Text(
            'No body profile data yet',
            textAlign: TextAlign.center,
            style: _ProfileText.cardTitle,
          ),
          SizedBox(height: 10),
          Text(
            'Confirmed recovery data will appear only after a secure profile service is connected.',
            textAlign: TextAlign.center,
            style: _ProfileText.supporting,
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return const _ProfileCard(
      semanticLabel:
          'Nothing is inferred. Momcozy will not estimate a recovery score or prefill symptoms from missing data.',
      tint: _ProfileColors.roseTint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: _ProfileColors.wine,
            size: 28,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nothing is inferred', style: _ProfileText.cardTitleSmall),
                SizedBox(height: 7),
                Text(
                  'Momcozy will not estimate a recovery score or prefill symptoms from missing data.',
                  style: _ProfileText.supportingDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableEditorCard extends StatelessWidget {
  const _UnavailableEditorCard();

  @override
  Widget build(BuildContext context) {
    return const _ProfileCard(
      semanticLabel:
          'Body profile editing unavailable. Editing will be enabled only when health records can be saved and read back securely.',
      child: Column(
        children: [
          _RoundIcon(icon: Icons.lock_outline_rounded, size: 68, iconSize: 32),
          SizedBox(height: 18),
          Text(
            'Body profile editing unavailable',
            textAlign: TextAlign.center,
            style: _ProfileText.cardTitle,
          ),
          SizedBox(height: 10),
          Text(
            'Editing will be enabled only when health records can be saved and read back securely.',
            textAlign: TextAlign.center,
            style: _ProfileText.supporting,
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.semanticLabel,
    required this.child,
    this.tint = Colors.white,
  });

  final String semanticLabel;
  final Widget child;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.size = 48, this.iconSize = 24});

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _ProfileColors.roseTint,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: _ProfileColors.wine, size: iconSize),
    );
  }
}

abstract final class _ProfileColors {
  static const background = Color(0xfffbf5f3);
  static const wine = Color(0xff7a2840);
  static const ink = Color(0xff1a1a1a);
  static const muted = Color(0xff6f625e);
  static const roseTint = Color(0xfff5e6eb);
}

abstract final class _ProfileText {
  static const pageTitle = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
  );
  static const cardTitle = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );
  static const cardTitleSmall = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );
  static const supporting = TextStyle(
    color: _ProfileColors.muted,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );
  static const supportingDark = TextStyle(
    color: _ProfileColors.ink,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );
}
