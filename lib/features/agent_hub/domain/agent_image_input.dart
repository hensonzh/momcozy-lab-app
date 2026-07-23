import 'dart:typed_data';

import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';

enum AgentImageInputSource { camera, gallery }

typedef AgentHubImagePicker =
    Future<AgentStreamImageInput?> Function(AgentImageInputSource source);

typedef AgentHubImageDiscarder = Future<void> Function(String assetId);

typedef AgentHubImageBytesLoader = Future<Uint8List> Function(String assetId);
