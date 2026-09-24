import 'package:flutter/material.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:url_launcher/url_launcher.dart';

const authInk = MomHomeTokens.ink;
const authMuted = MomHomeTokens.secondary;
const authRose = MomHomeTokens.rose;
const authBorder = MomHomeTokens.border;
const authBackground = MomHomeTokens.background;
const authReferenceInk = Color(0xff111111);
const authReferenceMuted = Color(0xff747487);
const authReferenceBorder = Color(0xffd8dae1);

TextStyle authReferenceText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = authReferenceInk,
  double height = 1.4,
  TextDecoration? decoration,
}) => TextStyle(
  fontFamily: 'NotoSansSCHome',
  fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  decoration: decoration,
  decorationColor: color,
);

InputDecoration authReferenceInputDecoration(
  BuildContext context, {
  required String hintText,
  Widget? suffixIcon,
}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: authReferenceBorder),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: authReferenceText(
      16,
      color: authReferenceMuted,
      height: 24 / 16,
    ),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    constraints: const BoxConstraints(minHeight: 56),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: authReferenceInk, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.error,
        width: 1.5,
      ),
    ),
    suffixIcon: suffixIcon,
    suffixIconColor: authReferenceMuted,
    helperMaxLines: 8,
    errorMaxLines: 8,
  );
}

ThemeData authLoginTheme(ThemeData base) {
  final theme = momSettingsTheme(base);
  return theme.copyWith(
    textTheme: theme.textTheme.copyWith(
      bodyLarge: MomHomeTokens.text(14),
      bodyMedium: MomHomeTokens.text(13),
      bodySmall: MomHomeTokens.text(12, color: authMuted),
    ),
    dividerTheme: const DividerThemeData(color: authBorder, thickness: 1),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      hintStyle: MomHomeTokens.text(13, color: authMuted),
      helperStyle: MomHomeTokens.text(12, color: authMuted),
      errorStyle: MomHomeTokens.text(12, color: theme.colorScheme.error),
      helperMaxLines: 8,
      errorMaxLines: 8,
      suffixIconColor: authMuted,
    ),
  );
}

class AuthNotice extends StatelessWidget {
  const AuthNotice(this.message, {super.key, this.error = false, this.textKey});
  final String message;
  final bool error;
  final Key? textKey;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: MomSettingsCard(
      color: error ? MomCozyColors.amberSoft : MomHomeTokens.mint,
      border: false,
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          message,
          key: textKey,
          style: MomHomeTokens.text(13, height: 1.55),
        ),
      ],
    ),
  );
}

class AuthLoginHeader extends StatelessWidget {
  const AuthLoginHeader({
    super.key,
    this.title = 'Welcome back',
    this.subtitle = 'Care and support, every step of the way.',
    this.compact = false,
  });
  final String title, subtitle;
  final bool compact;

  static void showLanguage(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: MomCozyMotion.animationStyle(context),
    backgroundColor: MomHomeTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Language',
              style: MomHomeTokens.text(20, weight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            MomSettingsCard(
              color: MomHomeTokens.mint,
              border: false,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('English', style: MomHomeTokens.text(14)),
                  selected: true,
                  selectedColor: MomHomeTokens.teal,
                  trailing: const Icon(Icons.check),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 52),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: authReferenceText(
            28,
            weight: FontWeight.w700,
            height: 36 / 28,
          ),
        ),
      );
    }
    final large = MediaQuery.textScalerOf(context).scale(14) > 14 * 1.4;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: MomHomeTokens.text(24, weight: FontWeight.w700)),
        SizedBox(height: compact ? 6 : 8),
        Text(
          subtitle,
          style: MomHomeTokens.text(
            13,
            color: authMuted,
            height: compact ? 1.55 : 18 / 13,
          ),
        ),
      ],
    );
    final illustration = Image.asset(
      'assets/images/auth_mother_baby.png',
      width: 48,
      height: 48,
      excludeFromSemantics: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Momcozy',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'LibreCaslonDisplay',
                fontSize: 32,
                height: compact ? 1 : 44 / 32,
                color: authRose,
                letterSpacing: compact ? -1.5 : 0,
              ),
            ),
            if (!compact)
              TextButton(
                key: const ValueKey('auth-language-button'),
                onPressed: () => showLanguage(context),
                style: TextButton.styleFrom(
                  foregroundColor: authMuted,
                  minimumSize: const Size(130, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  textStyle: MomHomeTokens.text(
                    13,
                    weight: FontWeight.w700,
                    height: 18 / 13,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('◎ English'),
                    SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down, size: 12),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        MomSettingsCard(
          borderInside: !compact,
          gradient: compact
              ? MomHomeTokens.plan
              : const LinearGradient(
                  colors: [Color(0xfffffdfb), Color(0xfff3f8f5)],
                ),
          children: [
            if (compact)
              copy
            else if (large) ...[
              copy,
              Align(alignment: Alignment.centerRight, child: illustration),
            ] else
              Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 12),
                  illustration,
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class AuthLanguageButton extends StatelessWidget {
  const AuthLanguageButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton(
    key: const ValueKey('auth-language-button'),
    onPressed: () => AuthLoginHeader.showLanguage(context),
    style: TextButton.styleFrom(
      foregroundColor: authReferenceMuted,
      minimumSize: const Size(130, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: authReferenceText(13, height: 18 / 13),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.language, size: 18),
        SizedBox(width: 6),
        Text('English'),
      ],
    ),
  );
}

class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({super.key, this.compact = false});
  final bool compact;

  Future<void> _open(BuildContext context, String path) async {
    try {
      if (await launchUrl(
        Uri.https('momcozy.com', '/pages/$path'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Keep the form available when the device cannot open a browser.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open this page. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: compact ? 14 : 20),
    child: Column(
      children: [
        const Text(
          'By continuing, you agree to our',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.4, color: authMuted),
        ),
        if (compact) const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => _open(context, 'terms-conditions'),
              style: compact ? _compactLinkStyle : _linkStyle,
              child: const Text('Terms of Use'),
            ),
            Text(
              compact ? ' and ' : 'and',
              style: TextStyle(
                fontSize: 12,
                height: 17 / 12,
                color: compact ? authRose : authMuted,
              ),
            ),
            TextButton(
              onPressed: () => _open(context, 'privacy-security'),
              style: compact ? _compactLinkStyle : _linkStyle,
              child: const Text('Privacy Policy.'),
            ),
          ],
        ),
      ],
    ),
  );

  static final _linkStyle = TextButton.styleFrom(
    foregroundColor: authMuted,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    textStyle: const TextStyle(fontFamily: 'NotoSansSCHome', fontSize: 12),
  );

  static final _compactLinkStyle = TextButton.styleFrom(
    foregroundColor: authRose,
    minimumSize: Size.zero,
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: MomHomeTokens.text(12, height: 17 / 12),
  );
}
