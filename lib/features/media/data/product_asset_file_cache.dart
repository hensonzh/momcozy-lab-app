import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';
import 'package:path_provider/path_provider.dart';

typedef ProductAssetCacheDirectoryProvider = Future<Directory> Function();

class ProductAssetFileCache implements ProductAssetPersistentCache {
  ProductAssetFileCache({
    ProductAssetCacheDirectoryProvider? directoryProvider,
    this.maxAge = const Duration(days: 1),
    this.maxDiskBytes = 96 * 1024 * 1024,
    DateTime Function()? now,
  }) : _directoryProvider = directoryProvider ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  static const _namespace = 'momcozy_product_assets/v1';

  final ProductAssetCacheDirectoryProvider _directoryProvider;
  final Duration maxAge;
  final int maxDiskBytes;
  final DateTime Function() _now;
  Future<Directory>? _directory;

  Future<void> clear() async {
    final parent = await _directoryProvider();
    final directory = Directory(
      '${parent.path}${Platform.pathSeparator}${_namespace.replaceAll('/', Platform.pathSeparator)}',
    );
    _directory = null;
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // Temporary cache cleanup is best-effort; secure account data is
      // cleared independently before the runtime is created.
    }
  }

  @override
  Future<ProductAssetContent?> read(
    ProductAssetReference reference, {
    required ProductAssetVariant variant,
  }) async {
    final files = await _files(reference, variant);
    if (!await files.metadata.exists() || !await files.body.exists()) {
      return null;
    }
    try {
      final payload = jsonDecode(await files.metadata.readAsString());
      if (payload is! Map<String, dynamic> ||
          payload['asset_id'] != reference.assetId ||
          payload['kind'] != reference.kind.name ||
          payload['variant'] != variant.name) {
        await _delete(files);
        return null;
      }
      final cachedAt = DateTime.tryParse(payload['cached_at'] as String? ?? '');
      final contentType = payload['content_type'] as String? ?? '';
      final sizeBytes = payload['size_bytes'];
      if (cachedAt == null ||
          contentType.isEmpty ||
          sizeBytes is! int ||
          _now().difference(cachedAt) > maxAge) {
        await _delete(files);
        return null;
      }
      final body = await files.body.readAsBytes();
      if (body.length != sizeBytes) {
        await _delete(files);
        return null;
      }
      await files.metadata.setLastModified(_now());
      return ProductAssetContent(
        reference: reference,
        contentType: contentType,
        bytes: body,
      );
    } catch (_) {
      await _delete(files);
      return null;
    }
  }

  @override
  Future<void> write(
    ProductAssetContent content, {
    required ProductAssetVariant variant,
  }) async {
    if (maxDiskBytes <= 0 || content.bytes.length > maxDiskBytes) return;
    final files = await _files(content.reference, variant);
    final nonce = '${pid}_${_now().microsecondsSinceEpoch}';
    final bodyTemp = File('${files.body.path}.$nonce.tmp');
    final metadataTemp = File('${files.metadata.path}.$nonce.tmp');
    try {
      await bodyTemp.writeAsBytes(content.bytes, flush: true);
      await metadataTemp.writeAsString(
        jsonEncode({
          'asset_id': content.reference.assetId,
          'kind': content.reference.kind.name,
          'variant': variant.name,
          'content_type': content.contentType,
          'size_bytes': content.bytes.length,
          'cached_at': _now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      await _replace(bodyTemp, files.body);
      await _replace(metadataTemp, files.metadata);
      await _evictOverflow(await _cacheDirectory());
    } finally {
      if (await bodyTemp.exists()) await bodyTemp.delete();
      if (await metadataTemp.exists()) await metadataTemp.delete();
    }
  }

  Future<_ProductAssetCacheFiles> _files(
    ProductAssetReference reference,
    ProductAssetVariant variant,
  ) async {
    final directory = await _cacheDirectory();
    final key = '${reference.assetId}:${reference.kind.name}:${variant.name}';
    final filename = sha256.convert(utf8.encode(key)).toString();
    return _ProductAssetCacheFiles(
      body: File('${directory.path}${Platform.pathSeparator}$filename.bin'),
      metadata: File(
        '${directory.path}${Platform.pathSeparator}$filename.json',
      ),
    );
  }

  Future<Directory> _cacheDirectory() {
    return _directory ??= () async {
      final parent = await _directoryProvider();
      final directory = Directory(
        '${parent.path}${Platform.pathSeparator}${_namespace.replaceAll('/', Platform.pathSeparator)}',
      );
      await directory.create(recursive: true);
      return directory;
    }();
  }

  Future<void> _replace(File source, File destination) async {
    if (await destination.exists()) await destination.delete();
    await source.rename(destination.path);
  }

  Future<void> _delete(_ProductAssetCacheFiles files) async {
    try {
      if (await files.body.exists()) await files.body.delete();
      if (await files.metadata.exists()) await files.metadata.delete();
    } catch (_) {
      // A corrupt cache entry can be ignored even if cleanup is unavailable.
    }
  }

  Future<void> _evictOverflow(Directory directory) async {
    final entries = <_DiskCacheEntry>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final body = File(entity.path.replaceFirst(RegExp(r'\.json$'), '.bin'));
      if (!await body.exists()) continue;
      entries.add(
        _DiskCacheEntry(
          files: _ProductAssetCacheFiles(body: body, metadata: entity),
          sizeBytes: await body.length(),
          lastAccessed: (await entity.stat()).modified,
        ),
      );
    }
    var totalBytes = entries.fold<int>(
      0,
      (total, entry) => total + entry.sizeBytes,
    );
    entries.sort(
      (left, right) => left.lastAccessed.compareTo(right.lastAccessed),
    );
    for (final entry in entries) {
      if (totalBytes <= maxDiskBytes) break;
      await _delete(entry.files);
      totalBytes -= entry.sizeBytes;
    }
  }
}

class _ProductAssetCacheFiles {
  const _ProductAssetCacheFiles({required this.body, required this.metadata});

  final File body;
  final File metadata;
}

class _DiskCacheEntry {
  const _DiskCacheEntry({
    required this.files,
    required this.sizeBytes,
    required this.lastAccessed,
  });

  final _ProductAssetCacheFiles files;
  final int sizeBytes;
  final DateTime lastAccessed;
}
