import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, Object?> productOpenApi;
  late Map<String, Object?> agentRuntimeOpenApi;
  late Map<String, Object?> smokeFlows;

  setUpAll(() {
    productOpenApi = _readJsonObject(
      'docs/backend-contract/product.openapi.generated.json',
    );
    agentRuntimeOpenApi = _readJsonObject(
      'docs/backend-contract/agent-runtime.openapi.generated.json',
    );
    smokeFlows = _readJsonObject(
      'docs/backend-contract/flutter-smoke-flows.json',
    );
  });

  test('keeps Product and Agent Runtime OpenAPI snapshots separate', () {
    final productPaths = _paths(productOpenApi);
    final agentRuntimePaths = _paths(agentRuntimeOpenApi);

    expect(
      productPaths.where((path) => path.startsWith('/v1/agent/')),
      isEmpty,
    );
    expect(
      agentRuntimePaths.where(
        (path) =>
            !path.startsWith('/v1/agent/') &&
            path != '/v1/health/live' &&
            path != '/v1/health/ready',
      ),
      isEmpty,
    );
    expect(productPaths, contains('/v1/auth/login'));
    expect(productPaths, contains('/v1/profile/lactation'));
    expect(productPaths, isNot(contains('/v1/agent/runs')));
    expect(agentRuntimePaths, contains('/v1/agent/runs'));
    expect(agentRuntimePaths, isNot(contains('/v1/auth/login')));
  });

  test('does not retain the former combined OpenAPI snapshot', () {
    expect(
      File('docs/backend-contract/openapi.generated.json').existsSync(),
      isFalse,
    );
  });

  test('accepts only the production Agent Runtime pattern', () {
    final components =
        agentRuntimeOpenApi['components']! as Map<String, Object?>;
    final schemas = components['schemas']! as Map<String, Object?>;
    final runCreate = schemas['AgentRunCreate']! as Map<String, Object?>;
    final properties = runCreate['properties']! as Map<String, Object?>;
    final runtimePattern =
        properties['runtime_pattern']! as Map<String, Object?>;
    final variants = runtimePattern['anyOf']! as List<Object?>;
    expect(variants, [
      {'const': 'proprietary_runtime', 'type': 'string'},
      {'type': 'null'},
    ]);
  });

  test('keeps optional plan lifecycle dates in the Product contract', () {
    final components = productOpenApi['components']! as Map<String, Object?>;
    final schemas = components['schemas']! as Map<String, Object?>;
    final planRead = schemas['PlanRead']! as Map<String, Object?>;
    final properties = planRead['properties']! as Map<String, Object?>;
    final required = (planRead['required'] as List<Object?>?) ?? const [];

    expect(properties, containsPair('starts_on', isA<Map>()));
    expect(properties, containsPair('ends_on', isA<Map>()));
    expect(required, isNot(contains('starts_on')));
    expect(required, isNot(contains('ends_on')));
  });

  test('tracks the generic diary and unified schedule agent contracts', () {
    final productPaths = _paths(productOpenApi);

    expect(productPaths, contains('/v1/internal/agent/diary'));
    expect(
      productPaths,
      contains('/v1/internal/agent/actions/diary.entry/apply'),
    );
    expect(productPaths, contains('/v1/internal/agent/schedule-timeline'));
    expect(productPaths, isNot(contains('/v1/internal/agent/pregnancy-diary')));
    expect(
      productPaths,
      isNot(contains('/v1/internal/agent/lactation/timeline')),
    );
  });

  test('assigns every smoke flow to the OpenAPI of its owning service', () {
    final pathsByService = <String, Set<String>>{
      'product': _paths(productOpenApi),
      'agent_runtime': _paths(agentRuntimeOpenApi),
    };
    final flows = smokeFlows['flows']! as List<Object?>;

    for (final rawFlow in flows) {
      final flow = rawFlow! as Map<String, Object?>;
      final service = flow['service'];
      expect(
        pathsByService,
        contains(service),
        reason: '${flow['name']} must declare an owning service',
      );
      for (final rawStep in flow['steps']! as List<Object?>) {
        final step = rawStep! as Map<String, Object?>;
        final path = _openApiPath(step['path']! as String);
        expect(
          pathsByService[service],
          contains(path),
          reason: '${flow['name']} assigns $path to the wrong service',
        );
      }
    }
  });
}

Map<String, Object?> _readJsonObject(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
}

Set<String> _paths(Map<String, Object?> openApi) {
  return (openApi['paths']! as Map<String, Object?>).keys.toSet();
}

String _openApiPath(String rawPath) {
  return rawPath
      .split('?')
      .first
      .replaceAllMapped(
        RegExp(r'\$\{([^}/]+)\}'),
        (match) => '{${match.group(1)}}',
      );
}
