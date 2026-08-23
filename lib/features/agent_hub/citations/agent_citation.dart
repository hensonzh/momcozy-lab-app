import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/routing/safe_link_target.dart';

const agentWebSearchCitationsEventName = 'momcozy.web_search.citations';

class AgentCitationView {
  const AgentCitationView({
    required this.index,
    required this.title,
    required this.displayText,
    required this.url,
    this.source,
    this.updatedAt,
  });

  final int index;
  final String title;
  final String displayText;
  final Uri url;
  final String? source;
  final String? updatedAt;
}

class AgentCitationMapper {
  const AgentCitationMapper._();

  static bool isCitationEvent(AgentStreamEvent event) {
    return _isCitationEvent(event);
  }

  static List<AgentCitationView> citationsFromEvents(
    Iterable<AgentStreamEvent> events, {
    String? messageId,
  }) {
    List<Object?>? latest;
    for (final event in events) {
      if (!_isCitationEvent(event)) continue;
      final eventMessageId = event.messageId?.trim();
      if (messageId?.trim().isNotEmpty == true &&
          eventMessageId?.isNotEmpty == true &&
          eventMessageId != messageId!.trim()) {
        continue;
      }
      final rawCitations = _citationItems(event);
      if (rawCitations != null) latest = rawCitations;
    }
    if (latest == null) return const <AgentCitationView>[];

    final citations = <AgentCitationView>[];
    final seenUrls = <String>{};
    for (final rawCitation in latest) {
      if (rawCitation is! Map) continue;
      final citation = Map<String, Object?>.from(rawCitation);
      final rawUrl = _stringField(citation, 'url', 'href');
      final target = SafeLinkTarget.tryParse(rawUrl);
      final url = target?.externalUri;
      if (url == null) continue;
      if (!seenUrls.add(_normalizedCitationUrl(url))) continue;

      final title =
          _firstNonEmpty([
            _stringField(citation, 'title'),
            _stringField(citation, 'label'),
            _citationHost(url),
          ]) ??
          '参考来源';
      final displayText =
          _firstNonEmpty([
            _stringField(citation, 'display_text', 'displayText'),
          ]) ??
          '${_citationDisplayTopic(title, url)}：${_citationShortUrl(url)}';
      citations.add(
        AgentCitationView(
          index: citations.length + 1,
          title: title,
          displayText: displayText,
          url: url,
          source: _firstNonEmpty([
            _stringField(citation, 'source'),
            _stringField(citation, 'publisher'),
          ]),
          updatedAt: _firstNonEmpty([
            _stringField(citation, 'updated_at', 'updatedAt'),
            _stringField(citation, 'published_at', 'publishedAt'),
          ]),
        ),
      );
      if (citations.length == 4) break;
    }
    return List<AgentCitationView>.unmodifiable(citations);
  }
}

String replaceCitationLinksWithIndexes(
  String markdown,
  List<AgentCitationView> citations,
) {
  if (markdown.isEmpty || citations.isEmpty) return markdown;
  final citationLinkPattern = RegExp(
    r'\[([^\]]+)\]\((https?:\/\/[^)\s]+)(?:\s+"[^"]*")?\)',
    caseSensitive: false,
  );
  final replaced = markdown.replaceAllMapped(citationLinkPattern, (match) {
    final url = Uri.tryParse(match.group(2) ?? '');
    if (url == null) return match.group(0)!;
    final index = _citationIndexForUrl(url, citations);
    return index == null ? match.group(0)! : '[$index]';
  });
  return _stripRawCitationMarkers(replaced)
      .replaceAllMapped(
        RegExp(r'[\uff08(]\[(\d+)\][\uff09)]'),
        (match) => '[${match.group(1)}]',
      )
      .trim();
}

bool _isCitationEvent(AgentStreamEvent event) {
  final type = event.type.toLowerCase();
  if (type != 'custom') return false;
  final name = _firstNonEmpty([
    _stringField(event.raw, 'name'),
    _stringField(event.payload, 'name'),
  ]);
  return name == agentWebSearchCitationsEventName;
}

List<Object?>? _citationItems(AgentStreamEvent event) {
  final candidates = <Object?>[
    event.raw['value'],
    event.payload['value'],
    event.raw['payload'],
    event.payload,
  ];
  for (final candidate in candidates) {
    if (candidate is List) return List<Object?>.from(candidate);
    if (candidate is! Map) continue;
    final value = candidate['citations'];
    if (value is List) return List<Object?>.from(value);
  }
  return null;
}

int? _citationIndexForUrl(Uri url, List<AgentCitationView> citations) {
  final normalized = _normalizedCitationUrl(url);
  for (final citation in citations) {
    if (_normalizedCitationUrl(citation.url) == normalized) {
      return citation.index;
    }
  }
  final host = _citationHost(url).toLowerCase();
  if (host.isEmpty) return null;
  for (final citation in citations) {
    if (_citationHost(citation.url).toLowerCase() == host) {
      return citation.index;
    }
  }
  return null;
}

String _normalizedCitationUrl(Uri url) {
  final normalized = url.replace(fragment: '').toString();
  return normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
}

String _citationDisplayTopic(String title, Uri url) {
  final host = _citationHost(url).toLowerCase();
  final normalizedTitle = title.trim().replaceAll(RegExp(r'\s+'), ' ');
  final lowerTitle = normalizedTitle.toLowerCase();
  final titleKey = lowerTitle.replaceFirst(RegExp(r'^www\.'), '');

  if (normalizedTitle.isNotEmpty &&
      normalizedTitle != '参考来源' &&
      titleKey != host &&
      titleKey != 'protocols' &&
      RegExp(r'[\u4e00-\u9fff]').hasMatch(normalizedTitle)) {
    return normalizedTitle.length <= 48
        ? normalizedTitle
        : normalizedTitle.substring(0, 48);
  }
  if (lowerTitle.contains('mastitis')) return '哺乳期乳腺炎资料';
  if (lowerTitle.contains('hand expression')) return '手挤奶指导';
  if (lowerTitle.contains('breastfeeding medicine') ||
      lowerTitle.contains('protocol')) {
    return 'ABM 哺乳医学临床指南';
  }
  if (lowerTitle.contains('breastfeeding')) return '母乳喂养专业资料';
  if (lowerTitle.contains('infant and child feeding')) return '婴幼儿喂养指导';
  if (lowerTitle.contains('postpartum')) return '产后健康专业资料';
  if (host.contains('bfmed.org') || host.contains('abm.memberclicks.net')) {
    return 'ABM 哺乳医学资料';
  }
  if (host.contains('ncbi.nlm.nih.gov')) return 'NCBI 医学资料';
  if (host.contains('cdc.gov')) return 'CDC 健康指南';
  if (host.contains('who.int')) return 'WHO 健康指南';
  if (host.contains('nice.org.uk')) return 'NICE 临床指南';
  if (host.contains('acog.org')) return 'ACOG 妇产科指南';
  if (host.contains('aap.org')) return 'AAP 儿科资料';
  if (host.contains('nhc.gov.cn')) return '国家卫健委资料';
  if (host.contains('unicef.org')) return 'UNICEF 母婴健康资料';
  if (host.contains('yiigle.com') ||
      host.contains('cmcha.org') ||
      host.contains('jundaodsj.com')) {
    return '中文医学资料';
  }
  return '专业资料';
}

String _citationShortUrl(Uri url) {
  final host = _citationHost(url);
  final segments = url.pathSegments.where((segment) => segment.isNotEmpty);
  if (segments.isEmpty) return host;
  final values = segments.toList(growable: false);
  if (values.length == 1) return '$host/${values.first}';
  return '$host/${values.first}/...';
}

String _citationHost(Uri url) {
  return url.host.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
}

String _stripRawCitationMarkers(String markdown) {
  var value = markdown.replaceAll(
    RegExp(
      r'(?:^|\n)[ \t]*(?:cite[ \t]+)?turn\d+search\d+(?:[ \t,]+turn\d+search\d+)*[ \t]*(?=\n|$)',
      caseSensitive: false,
      multiLine: true,
    ),
    '',
  );
  value = value.replaceAll(
    RegExp(
      r'[ \t]*(?:cite[ \t]+)?turn\d+search\d+(?:[ \t,]+turn\d+search\d+)*',
      caseSensitive: false,
    ),
    '',
  );
  return value.replaceAll(RegExp(r'(?:\n[ \t]*){3,}'), '\n\n');
}

String? _stringField(Map<String, Object?> map, String key, [String? alias]) {
  final value = map[key] ?? (alias == null ? null : map[alias]);
  return value is String ? value : null;
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return null;
}
