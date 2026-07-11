import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/features/agent_hub/citations/agent_citation.dart';

void main() {
  group('AgentCitationMapper', () {
    test('maps the latest matching web-search citation event safely', () {
      final citations = AgentCitationMapper.citationsFromEvents([
        AgentStreamEvent({
          'type': 'CUSTOM',
          'name': 'momcozy.web_search.citations',
          'message_id': 'other-message',
          'value': {
            'citations': [
              {'url': 'https://example.com/stale', 'title': 'Stale'},
            ],
          },
        }),
        AgentStreamEvent({
          'type': 'CUSTOM',
          'name': 'momcozy.web_search.citations',
          'message_id': 'assistant-1',
          'value': {
            'citations': [
              {
                'url': 'https://www.bfmed.org/protocols',
                'title': 'Academy of Breastfeeding Medicine Protocols',
                'display_text': '临床指南：bfmed.org/protocols',
              },
              {
                'url': 'https://www.ncbi.nlm.nih.gov/books/NBK501922/',
                'title': 'www.ncbi.nlm.nih.gov',
              },
              {'url': 'javascript:alert(1)', 'title': '危险链接'},
              {
                'url': 'https://www.bfmed.org/protocols#duplicate',
                'title': '重复来源',
              },
              {
                'url': 'https://www.who.int/health-topics/breastfeeding',
                'title': 'Breastfeeding',
              },
              {
                'url':
                    'https://www.cdc.gov/breastfeeding-special-circumstances',
                'title': 'CDC',
              },
              {
                'url': 'https://www.nice.org.uk/guidance/example',
                'title': 'NICE',
              },
            ],
          },
        }),
      ], messageId: 'assistant-1');

      expect(citations, hasLength(4));
      expect(citations.map((citation) => citation.index), [1, 2, 3, 4]);
      expect(citations[0].displayText, '临床指南：bfmed.org/protocols');
      expect(citations[1].displayText, 'NCBI 医学资料：ncbi.nlm.nih.gov/books/...');
      expect(citations[2].displayText, contains('母乳喂养专业资料'));
      expect(citations[3].displayText, contains('CDC 健康指南'));
      expect(
        citations.map((citation) => citation.url.toString()),
        isNot(contains(startsWith('javascript:'))),
      );
    });

    test('accepts lowercase custom payload aliases', () {
      final citations = AgentCitationMapper.citationsFromEvents([
        AgentStreamEvent({
          'type': 'custom',
          'payload': {
            'name': 'momcozy.web_search.citations',
            'value': {
              'citations': [
                {
                  'url': 'https://www.acog.org/womens-health',
                  'title': 'Pregnancy guidance',
                  'displayText': 'ACOG 资料',
                },
              ],
            },
          },
        }),
      ]);

      expect(citations.single.displayText, 'ACOG 资料');
    });
  });

  group('replaceCitationLinksWithIndexes', () {
    test('replaces exact and same-host links and removes raw markers', () {
      final citations = [
        AgentCitationView(
          index: 1,
          title: 'CDC',
          displayText: 'CDC 健康指南',
          url: Uri.parse('https://www.cdc.gov/breastfeeding'),
        ),
      ];
      const markdown = '''
参考 [CDC](https://www.cdc.gov/breastfeeding) 和 [同站资料](https://www.cdc.gov/another-page)。
[Momcozy](https://example.com/product)
cite turn1search5 turn1search1
''';

      expect(replaceCitationLinksWithIndexes(markdown, citations), '''
参考 [1] 和 [1]。
[Momcozy](https://example.com/product)''');
    });
  });
}
