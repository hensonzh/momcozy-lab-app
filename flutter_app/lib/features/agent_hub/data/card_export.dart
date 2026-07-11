import 'dart:io';
import 'dart:typed_data';

import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_card_export.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PlatformAgentCardExportService implements AgentCardExportService {
  const PlatformAgentCardExportService();

  static const _directoryName = 'momcozy-card-exports';
  static const _retention = Duration(days: 1);

  @override
  Future<void> sharePng({
    required Uint8List bytes,
    required String filename,
  }) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final exportDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}$_directoryName',
    );
    await exportDirectory.create(recursive: true);
    await _deleteStaleFiles(exportDirectory);

    final file = File(
      '${exportDirectory.path}${Platform.pathSeparator}$filename',
    );
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        fileNameOverrides: [filename],
        title: 'Momcozy Lab 卡片',
      ),
    );
  }

  Future<void> _deleteStaleFiles(Directory directory) async {
    final cutoff = DateTime.now().subtract(_retention);
    try {
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final modified = await entity.lastModified();
        if (modified.isBefore(cutoff)) await entity.delete();
      }
    } on FileSystemException {
      // Cache cleanup is best-effort and must not block a fresh export.
    }
  }
}
