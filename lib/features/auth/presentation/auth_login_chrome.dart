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
const authLoginTitle = Color(0xffb54f78);
const authLoginSubtitle = Color(0xff8a7180);
const authLoginLink = Color(0xff8a607f);
const authLoginButton = Color(0xffa44569);
const authLoginBackground = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0, 0.5, 1],
  colors: [Color(0xfff5edf4), Color(0xfffaf5f8), Color(0xfffffdfc)],
);

TextStyle authReferenceText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = authReferenceInk,
  double height = 1.4,
  TextDecoration? decoration,
}) => TextStyle(
  fontFamily: 'Inter',
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
    this.title = 'Momcozy',
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
        padding: const EdgeInsets.only(top: 4, bottom: 64),
        child: Column(
          children: [
            Text(
              title,
              key: const ValueKey('auth-login-title'),
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'LibreCaslonDisplay',
                fontSize: 48,
                fontWeight: FontWeight.w400,
                height: 58 / 48,
                color: authLoginTitle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              key: const ValueKey('auth-login-subtitle'),
              textAlign: TextAlign.center,
              style: authReferenceText(
                14,
                height: 20 / 14,
                color: authLoginSubtitle,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 36),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'LibreCaslonDisplay',
              fontSize: 36,
              height: 44 / 36,
              color: authLoginTitle,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: authReferenceText(
              14,
              height: 20 / 14,
              color: authLoginSubtitle,
            ),
          ),
        ],
      ),
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
  const AuthLegalFooter({
    super.key,
    this.compact = false,
    this.registration = false,
  });
  final bool compact;
  final bool registration;

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
              registration
                  ? ' · Read our '
                  : compact
                  ? ' and '
                  : 'and',
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
