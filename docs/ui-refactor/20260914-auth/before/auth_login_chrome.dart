import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:url_launcher/url_launcher.dart';

const authInk = Color(0xFF25242B);
const authMuted = Color(0xFF706C78);
const authRose = Color(0xFF8F3E57);
const authBorder = Color(0xFFC9C6CD);
const authBackground = Color(0xFFFAF8F5);

ThemeData authLoginTheme(ThemeData base) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: authBorder),
  );
  return base.copyWith(
    scaffoldBackgroundColor: authBackground,
    textTheme: base.textTheme.apply(
      fontFamily: 'DMSans',
      bodyColor: authInk,
      displayColor: authInk,
    ),
    dividerTheme: const DividerThemeData(color: authBorder, thickness: 1),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: authRose, width: 1.5),
      ),
      hintStyle: const TextStyle(color: authMuted, fontSize: 16),
      suffixIconColor: authMuted,
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

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!compact)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('auth-language-button'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              sheetAnimationStyle: MomCozyMotion.animationStyle(context),
              showDragHandle: true,
              builder: (context) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Language',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('English'),
                        selected: true,
                        selectedColor: authRose,
                        trailing: const Icon(Icons.check),
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: authMuted,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontFamily: 'DMSans', fontSize: 14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 20),
                SizedBox(width: 8),
                Text('English'),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 20),
              ],
            ),
          ),
        ),
      Image.asset(
        'assets/images/auth_mother_baby.png',
        width: compact ? 72 : 100,
        height: compact ? 72 : 100,
        excludeFromSemantics: true,
      ),
      Text(
        'Momcozy',
        style: TextStyle(
          fontFamily: 'LibreCaslonDisplay',
          fontSize: compact ? 32 : 42,
          height: 1,
          color: authRose,
          letterSpacing: -1.5,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'LibreCaslonDisplay',
          fontSize: compact ? 32 : 36,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, height: 1.4, color: authMuted),
      ),
      const SizedBox(height: 28),
    ],
  );
}

class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({super.key});

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
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      children: [
        const Text(
          'By continuing, you agree to our',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.4, color: authMuted),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => _open(context, 'terms-conditions'),
              style: _linkStyle,
              child: const Text('Terms of Use'),
            ),
            const Text('and', style: TextStyle(fontSize: 12, color: authMuted)),
            TextButton(
              onPressed: () => _open(context, 'privacy-security'),
              style: _linkStyle,
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
    textStyle: const TextStyle(fontFamily: 'DMSans', fontSize: 12),
  );
}
