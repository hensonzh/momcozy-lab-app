import 'package:url_launcher/url_launcher.dart';

abstract interface class ExternalUrlLauncher {
  Future<bool> open(Uri uri);
}

class PlatformExternalUrlLauncher implements ExternalUrlLauncher {
  const PlatformExternalUrlLauncher();

  @override
  Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
