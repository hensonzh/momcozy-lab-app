import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Small symbols from the chat-first Demo's SVG icon set.
class ChatFirstDemoIcon extends StatelessWidget {
  const ChatFirstDemoIcon(this.name, {super.key, this.size = 17, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/chat_first/icon-$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ?? IconTheme.of(context).color ?? const Color(0xFF965873),
      BlendMode.srcIn,
    ),
    excludeFromSemantics: true,
  );
}
