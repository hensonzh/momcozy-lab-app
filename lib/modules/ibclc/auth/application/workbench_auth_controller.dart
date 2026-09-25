import 'package:flutter/foundation.dart';
import '../../../../core/auth/auth_token_store.dart';
import '../../../../core/auth/momcozy_auth_api.dart';
import '../../../../core/auth/momcozy_auth_device_id.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/product_failure.dart';
import 'auth_gateway.dart';

class WorkbenchAuthController extends ChangeNotifier {
  WorkbenchAuthController({
    required this.gateway,
    required this.store,
    required this.devices,
  });
  final WorkbenchAuthGateway gateway;
  final AuthTokenStore store;
  final MomCozyAuthDeviceIdStore devices;
  MomCozyAuthTokenResponse? _tokens;
  WorkbenchIdentity? identity;
  WorkbenchLoginChallenge? challenge;
  ProductFailure? failure;
  String? validation;
  bool restoring = true, busy = false, _disposed = false;
  int generation = 0, _refreshGeneration = -1;
  Future<void>? _refresh;
  Future<void> _storageTail = Future.value();
  String? get accessToken => _tokens?.accessToken;
  bool get authenticated => identity != null && _tokens != null;
  bool get identityPending => _tokens != null && identity == null;
  bool _current(int epoch) => !_disposed && generation == epoch;

  Future<void> restore() async {
    if (busy) return;
    final epoch = generation;
    restoring = busy = true;
    failure = null;
    _notify();
    try {
      final saved = _tokens ?? await _storage(() => store.read());
      if (!_current(epoch)) return;
      _tokens = saved;
      if (_tokens != null) await _loadIdentity(epoch);
    } catch (error) {
      await _failed(error, epoch);
    }
    _finish(epoch);
  }

  Future<void> begin(String email, String password) async {
    if (busy || restoring) return;
    if (!email.trim().contains('@') || password.isEmpty) {
      validation = 'Enter your work email and password.';
      _notify();
      return;
    }
    final epoch = generation;
    busy = true;
    failure = null;
    validation = null;
    _notify();
    try {
      final deviceId = await devices.readOrCreateDeviceId();
      if (!_current(epoch)) return;
      final next = await gateway.begin(
        email: email,
        password: password,
        deviceId: deviceId,
      );
      if (!_current(epoch)) return;
      challenge = next;
    } catch (error) {
      await _failed(error, epoch);
    }
    _finish(epoch);
  }

  Future<void> verify(String code) async {
    if (busy || challenge == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      validation = 'Enter the 6-digit code from your authenticator app.';
      _notify();
      return;
    }
    final current = challenge!;
    var epoch = generation;
    busy = true;
    failure = null;
    validation = null;
    _notify();
    try {
      final tokens = await gateway.verify(
        challenge: current.value,
        code: code.trim(),
      );
      if (!await _persist(tokens, epoch)) return;
      if (!_current(epoch)) {
        await _discard(tokens);
        return;
      }
      _tokens = tokens;
      epoch = ++generation;
      challenge = null;
      await _loadIdentity(epoch);
    } catch (error) {
      await _failed(error, epoch);
      if (_current(epoch) && failure?.code == 'mfa_challenge_expired') {
        challenge = null;
      }
    }
    _finish(epoch);
  }

  void restart() {
    if (busy) return;
    challenge = null;
    failure = null;
    validation = null;
    _notify();
  }

  Future<void> _loadIdentity(int epoch) async {
    final userId = _tokens?.user.id;
    final result = await gateway.identity();
    if (!_current(epoch)) return;
    if (result.provider.id != userId) {
      throw const ProductFailure(ProductFailureKind.unauthenticated);
    }
    identity = result;
  }

  Future<void> refresh(String? previousToken) {
    if (_tokens == null) {
      return Future.error(
        const ProductFailure(ProductFailureKind.unauthenticated),
      );
    }
    if (_tokens!.accessToken != previousToken) return Future.value();
    if (_refresh != null && _refreshGeneration == generation) return _refresh!;
    final epoch = generation, current = _tokens!;
    _refreshGeneration = epoch;
    return _refresh = _refreshTokens(current, epoch).whenComplete(() {
      if (_refreshGeneration == epoch) _refresh = null;
    });
  }

  Future<void> _refreshTokens(
    MomCozyAuthTokenResponse current,
    int epoch,
  ) async {
    try {
      final tokens = await gateway.refresh(current.refreshToken);
      if (tokens.user.id != current.user.id) {
        await _discard(tokens);
        throw const ProductFailure(ProductFailureKind.unauthenticated);
      }
      if (await _persist(tokens, epoch)) {
        if (_current(epoch)) {
          _tokens = tokens;
        } else {
          await _discard(tokens);
        }
      }
    } catch (error) {
      if (_current(epoch)) {
        final mapped = _asFailure(error);
        if (_endsSession(mapped) || mapped.code == 'auth_storage_failed') {
          failure = mapped;
          await _clear();
        }
      }
      rethrow;
    }
  }

  /// Serializes every credential read/write/delete, including a logout that
  /// arrives while a secure-storage write is still in flight.
  Future<T> _storage<T>(Future<T> Function() action) {
    final result = _storageTail.then((_) => action());
    _storageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<bool> _persist(MomCozyAuthTokenResponse tokens, int epoch) async {
    try {
      final accepted = await _storage(() async {
        if (!_current(epoch)) return false;
        try {
          await store.write(tokens);
          if (_current(epoch)) return true;
          await store.clear();
          return false;
        } catch (_) {
          try {
            await store.clear();
          } catch (_) {
            // Preserve the persistence failure; never accept these credentials.
          }
          throw const ProductFailure(
            ProductFailureKind.unavailable,
            code: 'auth_storage_failed',
          );
        }
      });
      if (!accepted) await _discard(tokens);
      return accepted;
    } catch (_) {
      await _discard(tokens);
      rethrow;
    }
  }

  Future<void> _discard(MomCozyAuthTokenResponse tokens) async {
    try {
      await gateway.logout(tokens.accessToken);
    } catch (_) {
      // A late or unpersisted session must never become a local login.
    }
  }

  Future<void> logout() async {
    final token = accessToken;
    final clearing = _clear(keepBusy: true);
    final epoch = generation;
    await clearing;
    if (token != null) {
      try {
        await gateway.logout(token);
      } catch (_) {
        // Local credentials have already been removed.
      }
    }
    _finish(epoch);
  }

  Future<void> _clear({bool keepBusy = false}) async {
    final epoch = ++generation;
    _tokens = null;
    identity = null;
    challenge = null;
    restoring = false;
    busy = keepBusy;
    _notify();
    try {
      await _storage(() => store.clear());
    } catch (_) {
      if (_current(epoch)) {
        failure = const ProductFailure(
          ProductFailureKind.unavailable,
          code: 'auth_storage_failed',
        );
      }
    }
    _notify();
  }

  Future<void> _failed(Object error, int epoch) async {
    if (!_current(epoch)) return;
    failure = _asFailure(error);
    if (identityPending && _endsSession(failure!)) await _clear();
  }

  bool _endsSession(ProductFailure failure) => [
    ProductFailureKind.unauthenticated,
    ProductFailureKind.forbidden,
  ].contains(failure.kind);
  ProductFailure _asFailure(Object error) => error is ProductFailure
      ? error
      : const ProductFailure(ProductFailureKind.unavailable);
  void _finish(int epoch) {
    if (!_current(epoch)) return;
    restoring = busy = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    generation++;
    super.dispose();
  }
}
