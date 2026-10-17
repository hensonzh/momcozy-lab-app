import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';

import '../domain/chat_first_welcome.dart';

abstract interface class ChatFirstWelcomeStore {
  Future<String?> read(String ownerUserId);
  Future<void> save(String ownerUserId, String idempotencyKey);
}

class SecureChatFirstWelcomeStore implements ChatFirstWelcomeStore {
  const SecureChatFirstWelcomeStore({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;
  String _key(String userId) => 'chat-first-welcome:$userId';

  @override
  Future<String?> read(String ownerUserId) =>
      storage.read(key: _key(ownerUserId));

  @override
  Future<void> save(String ownerUserId, String idempotencyKey) =>
      storage.write(key: _key(ownerUserId), value: idempotencyKey);
}

class MemoryChatFirstWelcomeStore implements ChatFirstWelcomeStore {
  final Map<String, String> _keys = {};

  @override
  Future<String?> read(String ownerUserId) async => _keys[ownerUserId];

  @override
  Future<void> save(String ownerUserId, String idempotencyKey) async {
    _keys[ownerUserId] = idempotencyKey;
  }
}

class ChatFirstWelcomeCoordinator {
  const ChatFirstWelcomeCoordinator({
    required this.product,
    required this.agent,
    required this.store,
    required this.ownerUserId,
    required this.role,
    required this.now,
  });

  final ApiJsonTransport product;
  final ApiJsonTransport agent;
  final ChatFirstWelcomeStore store;
  final String ownerUserId;
  final FamilyRole? role;
  final DateTime Function() now;

  Future<ChatFirstWelcomeRequest?> prepare() async =>
      (await prepareState()).request;

  /// Return the current profile key even when its welcome was already sent.
  /// The transcript uses that key to hide superseded welcome replies.
  Future<({String currentKey, ChatFirstWelcomeRequest? request})>
  prepareState() async {
    if (role != FamilyRole.mother) return (currentKey: '', request: null);
    final today = now().toLocal();
    final day = DateTime(today.year, today.month, today.day);
    final end = DateTime(today.year, today.month, today.day + 1);
    final response = await product.getJson(
      '/v1/profile/me-experience',
      query: {
        'start': day.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      },
    );
    final profile = response['profile'];
    final concerns = response['concerns'];
    if (profile is! Map || concerns is! List) {
      throw const FormatException('Account profile is incomplete.');
    }
    final request = ChatFirstWelcomeRequest.forAuthoritativeProfile(
      userId: ownerUserId,
      asOfDate: today,
      profile: Map<String, Object?>.from(profile),
      concerns: concerns.cast<Object?>(),
    );
    final receipt = await store.read(ownerUserId);
    // An accepted local receipt is not proof that the Agent run was durably
    // created. Check owner-scoped history even when it matches, so a failed
    // handoff can retry with the same idempotency key instead of going blank.
    final inHistory = await _alreadyInHistory(request);
    if (inHistory) {
      if (receipt != request.idempotencyKey) {
        await store.save(ownerUserId, request.idempotencyKey);
      }
      return (currentKey: request.idempotencyKey, request: null);
    }
    return (currentKey: request.idempotencyKey, request: request);
  }

  Future<void> markAccepted(String idempotencyKey) =>
      store.save(ownerUserId, idempotencyKey);

  Future<bool> _alreadyInHistory(ChatFirstWelcomeRequest request) async {
    final threads = await agent.getJson(
      '/v1/agent/threads',
      query: {'limit': 100},
    );
    final items = threads['items'];
    if (items is! List) throw const FormatException('Invalid thread list.');
    for (final rawThread in items) {
      if (rawThread is! Map || rawThread['id'] is! String) {
        throw const FormatException('Invalid conversation thread.');
      }
      final id = rawThread['id'] as String;
      int? cursor;
      var pages = 0;
      while (true) {
        if (++pages > 200) {
          // The API has no unbounded history search. Fail closed rather than
          // inventing a second welcome when the marker is out of reach.
          throw StateError('Conversation history cannot be fully checked.');
        }
        final page = await agent.getJson(
          '/v1/agent/threads/${Uri.encodeComponent(id)}/history',
          query: {'limit': 50, 'before_sequence': ?cursor},
        );
        final messages = page['items'];
        if (messages is! List) {
          throw const FormatException('Invalid conversation history.');
        }
        for (final item in messages) {
          if (item is! Map || item['role'] != 'user') continue;
          final content = item['content'];
          if (content is! Map) continue;
          final source = content['client_context'];
          if (source is Map &&
              source['source'] == 'chat_first_welcome' &&
              content['text'] is String &&
              chatFirstWelcomeKeyForPrompt(content['text'] as String) ==
                  request.idempotencyKey) {
            return true;
          }
        }
        final next = page['next_before_sequence'];
        if (next == null) break;
        if (next is! int || next <= 0 || next == cursor) {
          throw const FormatException('Invalid history cursor.');
        }
        cursor = next;
      }
    }
    if (items.length == 100) {
      throw StateError(
        'Thread list may be truncated; welcome was not duplicated.',
      );
    }
    return false;
  }
}
