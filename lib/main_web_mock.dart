import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

import 'web_demo/web_demo_app.dart';

void main() {
  if (!kIsWeb) throw UnsupportedError('The fictional demo is Web-only.');
  WidgetsFlutterBinding.ensureInitialized();
  // CanvasKit renders text into a canvas; enable the browser accessibility
  // tree for keyboard users and reliable semantic browser tests.
  SemanticsBinding.instance.ensureSemantics();
  runApp(const WebDemoApp());
}
